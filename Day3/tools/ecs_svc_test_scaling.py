import boto3
import json
import re
import time
from datetime import datetime, timedelta
from statistics import mean
import concurrent.futures

class DualMetricAutoscaler:
    def __init__(self, cluster_name, asg_name=None):
        self.ecs = boto3.client('ecs', region_name='ap-northeast-2')
        self.logs = boto3.client('logs', region_name='ap-northeast-2')
        self.cloudwatch = boto3.client('cloudwatch', region_name='ap-northeast-2')
        self.autoscaling = boto3.client('autoscaling', region_name='ap-northeast-2')
        self.cluster_name = cluster_name
        self.asg_name = asg_name or f"{cluster_name}-asg"
        
        # 실시간 모니터링 설정 (캐시 없음)
        self.log_query_timeout = 5   # 5초 빠른 타임아웃
        self.log_sample_size = 100   # 적은 샘플로 빠른 처리
        
        # 서비스별 설정 (메모리 제거, 실시간 모니터링)
        self.services = {
            'product-svc': {
                'log_group': '/ecs/logs/product',
                'response_time_threshold': 0.3,
                'cpu_threshold': 95,  # 더 낮은 임계값
                'min_tasks': 1,
                'max_tasks': 6,
                'last_scale_time': 0,
                'violation_count': 0,
                'violation_threshold': 2  # 더 빠른 반응
            },
            'stress-svc': {
                'log_group': '/ecs/logs/stress',
                'response_time_threshold': 0.5,
                'cpu_threshold': 80,
                'min_tasks': 1,
                'max_tasks': 6,
                'last_scale_time': 0,
                'violation_count': 0,
                'violation_threshold': 2
            },
            'user-svc': {
                'log_group': '/ecs/logs/user',
                'response_time_threshold': 0.3,
                'cpu_threshold': 95,
                'min_tasks': 1,
                'max_tasks': 6,
                'last_scale_time': 0,
                'violation_count': 0,
                'violation_threshold': 2
            }
        }
        
        self.scale_up_cooldown = 30   # 더 짧은 쿨다운
        self.scale_down_cooldown = 180
        
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
            print(f"⚠️ ASG 설정 실패: {e}", flush=True)
    
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
    
    def get_cpu_utilization(self, service_name):
        end_time = datetime.now()
        start_time = end_time - timedelta(minutes=5)
        
        # EC2 인스턴스 CPU 직접 조회
        instance_ids = self.get_asg_instance_ids()
        if instance_ids:
            all_cpu_values = []
            for instance_id in instance_ids:
                try:
                    response = self.cloudwatch.get_metric_statistics(
                        Namespace='AWS/EC2',
                        MetricName='CPUUtilization',
                        Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
                        StartTime=start_time,
                        EndTime=end_time,
                        Period=300,
                        Statistics=['Average', 'Maximum']
                    )
                    
                    if response['Datapoints']:
                        latest = max(response['Datapoints'], key=lambda x: x['Timestamp'])
                        cpu_value = latest.get('Maximum', latest.get('Average', 0))
                        all_cpu_values.append(cpu_value)
                except Exception:
                    pass
            
            if all_cpu_values:
                return sum(all_cpu_values) / len(all_cpu_values)
        
        # ECS 서비스 메트릭 시도
        try:
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ECS',
                MetricName='CPUUtilization',
                Dimensions=[
                    {'Name': 'ServiceName', 'Value': service_name},
                    {'Name': 'ClusterName', 'Value': self.cluster_name}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Average', 'Maximum']
            )
            
            if response['Datapoints']:
                latest = max(response['Datapoints'], key=lambda x: x['Timestamp'])
                return latest.get('Maximum', latest.get('Average', 0))
        except Exception:
            pass
        
        return 75.0  # 트래픽 있음 추정값
    
    def get_asg_instance_ids(self):
        try:
            response = self.autoscaling.describe_auto_scaling_groups(
                AutoScalingGroupNames=[self.asg_name]
            )
            if response['AutoScalingGroups']:
                asg = response['AutoScalingGroups'][0]
                return [i['InstanceId'] for i in asg['Instances'] if i['LifecycleState'] == 'InService']
        except Exception:
            pass
        return []
    
    def get_average_response_time(self, log_group_name):
        end_time = datetime.now()
        start_time = end_time - timedelta(minutes=2)
        
        query = """
        fields @timestamp, @message
        | sort @timestamp desc
        | limit 100
        """
        
        try:
            response = self.logs.start_query(
                logGroupName=log_group_name,
                startTime=int(start_time.timestamp()),
                endTime=int(end_time.timestamp()),
                queryString=query
            )
            
            # 빠른 쿼리 대기
            max_wait = 25
            wait_count = 0
            while wait_count < max_wait:
                result = self.logs.get_query_results(queryId=response['queryId'])
                if result['status'] == 'Complete':
                    break
                elif result['status'] == 'Failed':
                    return 0.5
                time.sleep(0.2)
                wait_count += 1
            
            if result['status'] != 'Complete':
                return 0.5
            
            if len(result['results']) == 0:
                return 0.4
            
            response_times = []
            patterns = [
                (r'\|\s*(\d+(?:\.\d+)?)ms\s*\|', 1000),
                (r'\|\s*(\d+(?:\.\d+)?)µs\s*\|', 1000000),
                (r'(\d+(?:\.\d+)?)ms', 1000),
                (r'(\d+(?:\.\d+)?)µs', 1000000),
            ]
            
            for log_entry in result['results']:
                try:
                    message = ""
                    for field in log_entry:
                        if field['field'] == '@message':
                            message = field['value']
                            break
                    
                    if not message:
                        continue
                    
                    for pattern, divisor in patterns:
                        matches = re.findall(pattern, message)
                        for match in matches:
                            try:
                                time_value = float(match)
                                time_seconds = time_value / divisor
                                if 0.0001 <= time_seconds <= 60:
                                    response_times.append(time_seconds)
                                    break
                            except ValueError:
                                continue
                        if response_times and len(response_times) >= 10:
                            break
                except Exception:
                    continue
            
            if response_times:
                return mean(response_times)
            else:
                return 0.6
                
        except Exception:
            return 0.5
            

    
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
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            cpu_future = executor.submit(self.get_cpu_utilization, service_name)
            response_future = executor.submit(self.get_average_response_time, service_config['log_group'])
            
            cpu_utilization = cpu_future.result(timeout=10)
            avg_response_time = response_future.result(timeout=10)
            
        return cpu_utilization, avg_response_time
    
    def auto_scale_service(self, service_name):
        service_config = self.services[service_name]
        
        current_tasks = self.get_current_task_count(service_name)
        
        # 병렬로 메트릭 수집
        try:
            cpu_utilization, avg_response_time = self.get_metrics_parallel(service_name, service_config)
        except concurrent.futures.TimeoutError:
            print(f"  ⏰ {service_name} 메트릭 수집 타임아웃", flush=True)
            return
        
        # 기본 상태 로깅 (한 줄로)
        print(f"{service_name}: {current_tasks}개 태스크, 응답시간: {avg_response_time:.6f}초, CPU: {cpu_utilization:.1f}%", flush=True)
        
        # 스케일링 결정 로직
        should_scale_up = False
        scale_reason = ""
        
        response_exceeded = avg_response_time > service_config['response_time_threshold']
        cpu_exceeded = cpu_utilization > service_config['cpu_threshold']
        
        if response_exceeded and cpu_exceeded:
            should_scale_up = True
            scale_reason = f"응답시간 {avg_response_time:.3f}s > {service_config['response_time_threshold']}s & CPU {cpu_utilization:.1f}% > {service_config['cpu_threshold']}%"
        
        # 스케일 업 (연속 조건 만족 체크)
        if should_scale_up:
            service_config['violation_count'] += 1
            print(f"  🎯 {service_name} 스케일링 조건 만족 ({service_config['violation_count']}/{service_config['violation_threshold']}): {scale_reason}", flush=True)
            
            # 연속 위반 체크
            if service_config['violation_count'] >= service_config['violation_threshold']:
                # 쿨다운 체크
                current_time = time.time()
                cooldown_remaining = self.scale_up_cooldown - (current_time - service_config['last_scale_time'])
                if cooldown_remaining > 0:
                    print(f"  ⏳ {service_name} 스케일링 쿨다운 중 ({int(cooldown_remaining)}초 남음)", flush=True)
                    return
                
                new_count = min(current_tasks + 1, service_config['max_tasks'])
                
                if new_count > current_tasks:
                    print(f"  🔥 1개 증가: {scale_reason}", flush=True)
                    self.scale_service(service_name, new_count, scale_reason)
                    service_config['violation_count'] = 0  # 스케일링 후 리셋
                else:
                    print(f"  ⚠️ 이미 최대 태스크 수 도달: {current_tasks}개", flush=True)
        else:
            # 조건 만족하지 않으면 위반 카운트 리셋
            service_config['violation_count'] = 0
            
            # 스케일 다운 (완화된 조건)
            if (avg_response_time < 0.2 and 
                cpu_utilization < 30 and 
                current_tasks > service_config['min_tasks']):
                
                current_time = time.time()
                if current_time - service_config['last_scale_time'] > 180:  # 3분 쿨다운
                    new_count = max(service_config['min_tasks'], current_tasks - 1)
                    reason = f"리소스 여유 (응답시간: {avg_response_time:.3f}s, CPU: {cpu_utilization:.1f}%)"
                    print(f"  ⬇️ {reason}", flush=True)
                    self.scale_service(service_name, new_count, reason)
    
    def run(self):
        print("이중 메트릭 오토스케일러 시작 (AND 조건: 응답시간 & CPU 모두 초과시 스케일링 - 연속 2번 위반시 스케일링)", flush=True)
        print(f"모니터링 서비스: {list(self.services.keys())}", flush=True)
        
        while True:
            try:
                print(f"\n=== {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===", flush=True)
                
                # 인스턴스 상태 표시
                instance_info = self.get_current_instance_count()
                print(f"💻 인스턴스: {instance_info['running']}/{instance_info['desired']}개", flush=True)
                
                for service_name in self.services.keys():
                    self.auto_scale_service(service_name)
                
                time.sleep(1)   # 1초마다 체크
                
            except KeyboardInterrupt:
                print("\n오토스케일러 종료", flush=True)
                break
            except Exception as e:
                print(f"오류 발생: {e}", flush=True)
                time.sleep(60)

def main():
    autoscaler = DualMetricAutoscaler(
        cluster_name="apdev-ecs-cluster",
        asg_name="apdev-ecs-asg"
    )
    autoscaler.run()

if __name__ == "__main__":
    main()