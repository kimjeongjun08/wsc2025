import boto3
import json
import re
import time
import os
import sys
from datetime import datetime, timedelta
from statistics import mean
import concurrent.futures

# Windows UTF-8 인코딩 설정
if sys.platform == 'win32':
    os.environ['PYTHONIOENCODING'] = 'utf-8'
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

class DualMetricAutoscaler:
    def __init__(self, cluster_name, asg_name=None):
        self.ecs = boto3.client('ecs', region_name='ap-northeast-2')
        self.logs = boto3.client('logs', region_name='ap-northeast-2')
        self.cloudwatch = boto3.client('cloudwatch', region_name='ap-northeast-2')
        self.autoscaling = boto3.client('autoscaling', region_name='ap-northeast-2')
        self.cluster_name = cluster_name
        self.asg_name = asg_name or f"{cluster_name}-asg"
        
        # 캐시 제거 - 실시간 모니터링
        
        # 로그 쿼리 최적화 (실시간 모니터링)
        self.log_query_timeout = 15  # 15초 타임아웃
        self.log_sample_size = 200   # 샘플 크기 증가
        
        # 서비스별 설정 (연속 조건 만족 체크)
        self.services = {
            'product-svc': {
                'log_group': '/ecs/logs/product',
                'response_time_threshold': 0.3,
                'cpu_threshold': 95,
                'min_tasks': 1,
                'max_tasks': 6,
                'last_scale_time': 0,
                'violation_count': 0,  # 연속 위반 횟수
                'violation_threshold': 5  # 5번 연속 위반시 스케일링
            },
            'stress-svc': {
                'log_group': '/ecs/logs/stress',
                'response_time_threshold': 0.5,
                'cpu_threshold': 110,
                'min_tasks': 1,
                'max_tasks': 6,
                'last_scale_time': 0,
                'violation_count': 0,
                'violation_threshold': 5
            },
            'user-svc': {
                'log_group': '/ecs/logs/user',
                'response_time_threshold': 0.3,
                'cpu_threshold': 95,
                'min_tasks': 1,
                'max_tasks': 6,
                'last_scale_time': 0,
                'violation_count': 0,
                'violation_threshold': 5
            }
        }
        
        self.scale_up_cooldown = 60   # 1분 쿨다운
        self.scale_down_cooldown = 300  # 5분으로 증가
        
        # Auto Scaling Group 설정
        self.asg_config = {
            'min_size': 1,
            'desired_capacity': 1,
            'max_size': 10
        }
        
        # ASG 초기 설정
        self.setup_asg()
    
    def setup_asg(self):
        """초기 ASG 설정"""
        try:
            self.autoscaling.update_auto_scaling_group(
                AutoScalingGroupName=self.asg_name,
                MinSize=self.asg_config['min_size'],
                DesiredCapacity=self.asg_config['desired_capacity'],
                MaxSize=self.asg_config['max_size']
            )
            print(f"⚙️ ASG 설정 완료: 최소 {self.asg_config['min_size']}개, 원하는 {self.asg_config['desired_capacity']}개, 최대 {self.asg_config['max_size']}개", flush=True)
        except Exception as e:
            print(f"⚠️ ASG 설정 실패 (ASG 미생성 상태일 수 있음): {e}", flush=True)
    
    def get_current_instance_count(self):
        """현재 인스턴스 수 조회"""
        try:
            response = self.autoscaling.describe_auto_scaling_groups(
                AutoScalingGroupNames=[self.asg_name]
            )
            if response['AutoScalingGroups']:
                asg = response['AutoScalingGroups'][0]
                return {
                    'desired': asg['DesiredCapacity'],
                    'running': len([i for i in asg['Instances'] if i['LifecycleState'] == 'InService']),
                    'total': len(asg['Instances'])
                }
        except Exception as e:
            print(f"⚠️ 인스턴스 수 조회 실패: {e}", flush=True)
        return {'desired': 0, 'running': 0, 'total': 0}
    
    def get_current_task_count(self, service_name):
        try:
            response = self.ecs.describe_services(
                cluster=self.cluster_name,
                services=[service_name]
            )
            return response['services'][0]['desiredCount']
        except:
            return 0
    
    def get_cpu_utilization(self, service_name, minutes=60):  # 1시간으로 확장
        end_time = datetime.now()
        start_time = end_time - timedelta(minutes=minutes)
        
        print(f"  🔍 CPU 메트릭 조회 시작: {service_name} ({start_time.strftime('%H:%M')} ~ {end_time.strftime('%H:%M')})", flush=True)
        
        try:
            # 여러 방법으로 시도
            attempts = [
                # 시도 1: 서비스 + 클러스터
                {
                    'dimensions': [{'Name': 'ServiceName', 'Value': service_name}, {'Name': 'ClusterName', 'Value': self.cluster_name}],
                    'period': 300
                },
                # 시도 2: 서비스 + 클러스터 (1분 간격)
                {
                    'dimensions': [{'Name': 'ServiceName', 'Value': service_name}, {'Name': 'ClusterName', 'Value': self.cluster_name}],
                    'period': 60
                },
                # 시도 3: 클러스터만
                {
                    'dimensions': [{'Name': 'ClusterName', 'Value': self.cluster_name}],
                    'period': 300
                }
            ]
            
            for i, attempt in enumerate(attempts, 1):
                print(f"    시도 {i}: {attempt['dimensions']}, Period: {attempt['period']}초", flush=True)
                
                response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/ECS',
                    MetricName='CPUUtilization',
                    Dimensions=attempt['dimensions'],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=attempt['period'],
                    Statistics=['Average', 'Maximum']
                )
                
                print(f"    결과: {len(response['Datapoints'])}개 데이터포인트", flush=True)
                
                if response['Datapoints']:
                    # 데이터포인트 상세 정보
                    for dp in response['Datapoints']:
                        timestamp = dp['Timestamp'].strftime('%H:%M:%S')
                        avg = dp.get('Average', 0)
                        maximum = dp.get('Maximum', 0)
                        print(f"      {timestamp}: 평균 {avg:.1f}%, 최대 {maximum:.1f}%", flush=True)
                    
                    # 최신 데이터 사용
                    latest = max(response['Datapoints'], key=lambda x: x['Timestamp'])
                    current_cpu = latest.get('Maximum', latest.get('Average', 0))
                    
                    print(f"  ✅ CPU 발견: {current_cpu:.1f}% (최신 데이터: {latest['Timestamp'].strftime('%H:%M:%S')})", flush=True)
                    return current_cpu
            
            # 모든 시도 실패
            print(f"  ❌ 모든 CPU 메트릭 시도 실패 ({service_name})", flush=True)
            
            # ECS 서비스 상태 확인
            try:
                ecs_response = self.ecs.describe_services(
                    cluster=self.cluster_name,
                    services=[service_name]
                )
                if ecs_response['services']:
                    service = ecs_response['services'][0]
                    print(f"    ECS 서비스 상태: {service['status']}, 실행 중: {service['runningCount']}개", flush=True)
                else:
                    print(f"    ECS 서비스 찾을 수 없음: {service_name}", flush=True)
            except Exception as ecs_e:
                print(f"    ECS 서비스 상태 확인 실패: {ecs_e}", flush=True)
            
            return 0
            
        except Exception as e:
            print(f"  ❌ CPU 메트릭 조회 실패 ({service_name}): {e}", flush=True)
            return 0
    

    
    def get_average_response_time(self, log_group_name, seconds=30):  # 30초로 단축
        end_time = datetime.now()
        start_time = end_time - timedelta(seconds=seconds)
        
        # 더 많은 로그 샘플 수집 (실시간성 향상)
        query = f"""
        fields @timestamp, @message
        | sort @timestamp desc
        | limit 200
        """
        
        try:
            response = self.logs.start_query(
                logGroupName=log_group_name,
                startTime=int(start_time.timestamp()),
                endTime=int(end_time.timestamp()),
                queryString=query
            )
            
            # 로그 쿼리 대기 (15초 타임아웃으로 증가)
            max_wait = 75  # 15초 최대 대기 (0.2 * 75 = 15초)
            wait_count = 0
            while wait_count < max_wait:
                result = self.logs.get_query_results(queryId=response['queryId'])
                if result['status'] == 'Complete':
                    break
                time.sleep(0.2)  # 0.2초씩 대기
                wait_count += 1
            
            if result['status'] != 'Complete':
                print(f"  ⏰ 로그 쿼리 타임아웃 (15초)", flush=True)
                return 0
            
            response_times = []
            # 더 포괄적인 정규식 패턴
            patterns = [
                (r'\|\s*(\d+\.\d+)ms\s*\|', 1000),      # GIN ms
                (r'\|\s*(\d+\.\d+)µs\s*\|', 1000000),   # GIN µs  
                (r'\|\s*(\d+)ms\s*\|', 1000),           # GIN ms (정수)
                (r'\|\s*(\d+)µs\s*\|', 1000000),        # GIN µs (정수)
                (r'(\d+\.\d+)ms\b', 1000),              # 단순 ms
                (r'(\d+\.\d+)µs\b', 1000000),           # 단순 µs
                (r'(\d+)ms\b', 1000),                   # 단순 ms (정수)
                (r'(\d+)µs\b', 1000000),                # 단순 µs (정수)
                (r'latency["\s:=]*(\d+\.\d+)', 1),      # latency: 1.234
                (r'duration["\s:=]*(\d+\.\d+)', 1),     # duration: 1.234
                (r'time["\s:=]*(\d+\.\d+)', 1),         # time: 1.234
            ]
            
            print(f"  📊 로그 엔트리 수: {len(result['results'])}", flush=True)
            
            for log_entry in result['results']:
                try:
                    log_message = ""
                    for field in log_entry:
                        if field['field'] == '@message':
                            log_message = field['value']
                            break
                    
                    if not log_message:
                        continue
                    
                    # JSON 파싱 시도
                    try:
                        if log_message.startswith('{'):
                            log_data = json.loads(log_message)
                            gin_log = log_data.get('log', log_message)
                        else:
                            gin_log = log_message
                    except:
                        gin_log = log_message
                    
                    # 모든 패턴 시도
                    for pattern, divisor in patterns:
                        matches = re.findall(pattern, gin_log)
                        for match in matches:
                            try:
                                time_value = float(match)
                                time_seconds = time_value / divisor
                                
                                if 0.0001 <= time_seconds <= 30:  # 범위 확장
                                    response_times.append(time_seconds)
                            except:
                                continue
                            
                except Exception:
                    continue
            
            print(f"  📈 응답시간 샘플 수: {len(response_times)}", flush=True)
            if response_times:
                print(f"  📊 응답시간 범위: {min(response_times):.4f}s ~ {max(response_times):.4f}s", flush=True)
            
            # 평균값 사용 (더 안정적)
            result_value = mean(response_times) if response_times else 0
            return result_value
            
        except Exception as e:
            print(f"  ❌ 로그 조회 실패: {e}", flush=True)
            return 0
    
    def scale_service(self, service_name, desired_count, reason):
        current_time = time.time()
        service_config = self.services[service_name]
        
        desired_count = max(service_config['min_tasks'], 
                          min(service_config['max_tasks'], desired_count))
        
        try:
            self.ecs.update_service(
                cluster=self.cluster_name,
                service=service_name,
                desiredCount=desired_count
            )
            
            service_config['last_scale_time'] = current_time
            print(f"✅ {service_name}: {desired_count}개 태스크로 스케일링 ({reason})", flush=True)
            return True
            
        except Exception as e:
            print(f"❌ {service_name} 스케일링 실패: {e}", flush=True)
            return False
    
    def get_metrics_parallel(self, service_name, service_config):
        """병렬로 메트릭 수집 (메모리 제거)"""
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            cpu_future = executor.submit(self.get_cpu_utilization, service_name)
            response_future = executor.submit(self.get_average_response_time, service_config['log_group'])
            
            cpu_utilization = cpu_future.result(timeout=10)  # 10초 타임아웃
            avg_response_time = response_future.result(timeout=20)  # 20초 타임아웃
            
        return cpu_utilization, avg_response_time
    
    def auto_scale_service(self, service_name):
        service_config = self.services[service_name]
        
        current_tasks = self.get_current_task_count(service_name)
        
        # 병렬로 메트릭 수집 (메모리 제거)
        try:
            cpu_utilization, avg_response_time = self.get_metrics_parallel(service_name, service_config)
        except concurrent.futures.TimeoutError:
            print(f"  ⏰ {service_name} 메트릭 수집 타임아웃", flush=True)
            return
        
        # 기본 상태 로깅 (메모리 제거)
        print(f"{service_name}: {current_tasks}개 태스크, 응답시간: {avg_response_time:.6f}초, CPU: {cpu_utilization:.1f}%", flush=True)
        
        # 스케일링 결정 로직 (30초 이내 스케일링 목표)
        should_scale_up = False
        scale_reason = ""
        
        # 스케일링 조건: 응답시간 & CPU 모두 초과
        response_exceeded = avg_response_time > service_config['response_time_threshold']
        cpu_exceeded = cpu_utilization > service_config['cpu_threshold']
        
        # 응답시간&CPU 모두 초과시 스케일링
        if response_exceeded and cpu_exceeded:
            should_scale_up = True
            scale_reason = f"응답시간 {avg_response_time:.3f}s > {service_config['response_time_threshold']}s & CPU {cpu_utilization:.1f}% > {service_config['cpu_threshold']}%"
        
        # 스케일 업 (연속 조건 만족 체크)
        if should_scale_up:
            service_config['violation_count'] += 1
            print(f"  🎯 {service_name} 스케일링 조건 만족 ({service_config['violation_count']}/{service_config['violation_threshold']}): {scale_reason}", flush=True)
            
            # 연속 위반 체크
            if service_config['violation_count'] >= service_config['violation_threshold']:
                # 쿨다운 체크 (중복 스케일링 방지)
                current_time = time.time()
                cooldown_remaining = self.scale_up_cooldown - (current_time - service_config['last_scale_time'])
                if cooldown_remaining > 0:
                    print(f"  ⏳ {service_name} 스케일링 쿨다운 중 ({int(cooldown_remaining)}초 남음)", flush=True)
                    return
                
                # 최소한 증가 (항상 1개씩만)
                increment = 1  # 항상 1개씩만 증가
                
                new_count = min(current_tasks + increment, service_config['max_tasks'])
                
                print(f"  📊 스케일링 계산: {current_tasks} + {increment} = {new_count} (최대: {service_config['max_tasks']})", flush=True)
                
                if new_count > current_tasks:
                    print(f"  🔥 {increment}개 증가: {scale_reason}", flush=True)
                    self.scale_service(service_name, new_count, scale_reason)
                    service_config['violation_count'] = 0  # 스케일링 후 리셋
                else:
                    print(f"  ⚠️ 이미 최대 태스크 수 도달: {current_tasks}개 (최대: {service_config['max_tasks']})", flush=True)
        else:
            # 조건 만족하지 않으면 위반 카운트 리셋
            service_config['violation_count'] = 0
            
            # 스케일 다운 (완화된 조건 - 메모리 제거)
            if (avg_response_time < 0.2 and 
                cpu_utilization < 30 and 
                current_tasks > service_config['min_tasks']):
                
                current_time = time.time()
                if current_time - service_config['last_scale_time'] > 180:  # 3분 쿨다운
                    new_count = max(service_config['min_tasks'], current_tasks - 1)
                    reason = f"리소스 여유 (응답시간: {avg_response_time:.3f}s, CPU: {cpu_utilization:.1f}%)"
                    print(f"  ⬇️ {reason}", flush=True)
                    self.scale_service(service_name, new_count, reason)
            
            # 강제 스케일 다운 (최대값 초과 시)
            if current_tasks > service_config['max_tasks']:
                new_count = service_config['max_tasks']
                reason = f"최대 태스크 수 초과 ({current_tasks} > {service_config['max_tasks']})"
                print(f"  ⬇️ 강제 스케일 다운: {reason}", flush=True)
                self.scale_service(service_name, new_count, reason)
    
    def run(self):
        print("이중 메트릭 오토스케일러 시작 (AND 조건: 응답시간 0.3초 & CPU 95% - 연속 5번 위반시 스케일링)", flush=True)
        print(f"모니터링 서비스: {list(self.services.keys())}", flush=True)
        
        while True:
            try:
                print(f"\n=== {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===", flush=True)
                
                # 인스턴스 상태 표시
                instance_info = self.get_current_instance_count()
                print(f"💻 인스턴스: {instance_info['running']}/{instance_info['desired']}개 (최대: {self.asg_config['max_size']}개)", flush=True)
                
                for service_name in self.services.keys():
                    self.auto_scale_service(service_name)
                
                time.sleep(1)   # 1초마다 체크 (빠른 감지)
                
            except KeyboardInterrupt:
                print("\n오토스케일러 종료", flush=True)
                break
            except Exception as e:
                import traceback
                print(f"\n❌ 오류 발생: {e}", flush=True)
                print(f"상세 오류:\n{traceback.format_exc()}", flush=True)
                print("60초 후 재시도...", flush=True)
                time.sleep(60)

def main():
    autoscaler = DualMetricAutoscaler(
        cluster_name="apdev-ecs-cluster",  # 실제 클러스터 이름으로 변경
        asg_name="apdev-ecs-asg"   # 실제 ASG 이름으로 변경
    )
    autoscaler.run()

if __name__ == "__main__":
    main()