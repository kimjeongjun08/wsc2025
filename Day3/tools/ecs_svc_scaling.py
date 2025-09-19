import boto3
import json
import re
import time
from datetime import datetime, timedelta, timezone
from statistics import mean, stdev
import concurrent.futures
from collections import deque

class SmartTrafficAutoscaler:
    def __init__(self, cluster_name, asg_name=None):
        self.ecs = boto3.client('ecs', region_name='ap-northeast-2')
        self.logs = boto3.client('logs', region_name='ap-northeast-2')
        self.cloudwatch = boto3.client('cloudwatch', region_name='ap-northeast-2')
        self.autoscaling = boto3.client('autoscaling', region_name='ap-northeast-2')
        self.cluster_name = cluster_name
        self.asg_name = asg_name or f"{cluster_name}-asg"
        
        # 트래픽 패턴 분석을 위한 히스토리 저장
        self.traffic_history = {
            'product-svc': {'cpu': deque(maxlen=20), 'response': deque(maxlen=20), 'timestamps': deque(maxlen=20)},
            'stress-svc': {'cpu': deque(maxlen=20), 'response': deque(maxlen=20), 'timestamps': deque(maxlen=20)},
            'user-svc': {'cpu': deque(maxlen=20), 'response': deque(maxlen=20), 'timestamps': deque(maxlen=20)}
        }
        
        # 서비스별 설정
        self.services = {
            'product-svc': {
                'log_group': '/ecs/logs/product',
                'response_time_threshold': 0.3,
                'cpu_threshold_gradual': 40,
                'cpu_threshold_spike': 90,
                'min_tasks': 1,
                'max_tasks': 6,
                'last_scale_time': 0,
                'violation_count': 0,
                'violation_threshold': 3,
                'current_pattern': 'unknown',
                'pattern_confidence': 0
            },
            'stress-svc': {
                'log_group': '/ecs/logs/stress',
                'response_time_threshold': 0.3,
                'cpu_threshold_gradual': 110,
                'cpu_threshold_spike': 110,
                'min_tasks': 1,
                'max_tasks': 6,
                'last_scale_time': 0,
                'violation_count': 0,
                'violation_threshold': 3,
                'current_pattern': 'unknown',
                'pattern_confidence': 0
            },
            'user-svc': {
                'log_group': '/ecs/logs/user',
                'response_time_threshold': 0.3,
                'cpu_threshold_gradual': 40,
                'cpu_threshold_spike': 90,
                'min_tasks': 1,
                'max_tasks': 6,
                'last_scale_time': 0,
                'violation_count': 0,
                'violation_threshold': 3,
                'current_pattern': 'unknown',
                'pattern_confidence': 0
            }
        }
        
        self.scale_up_cooldown = 90  # 1분 30초
        self.scale_down_cooldown = 300
        
        # Auto Scaling Group 설정
        self.asg_config = {
            'min_size': 1,
            'desired_capacity': 1,
            'max_size': 10
        }
        
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
            print(f"ASG 설정 완료: {self.asg_config['min_size']}-{self.asg_config['max_size']}개")
        except Exception as e:
            print(f"ASG 설정 실패: {e}")
    
    def analyze_traffic_pattern(self, service_name, cpu_utilization, response_time):
        """트래픽 패턴 분석"""
        history = self.traffic_history[service_name]
        current_time = time.time()
        
        history['cpu'].append(cpu_utilization)
        history['response'].append(response_time)
        history['timestamps'].append(current_time)
        
        if len(history['cpu']) < 10:
            return 'unknown', 0, 40
        
        recent_cpu = list(history['cpu'])[-10:]
        recent_times = list(history['timestamps'])[-10:]
        
        try:
            # 변화율 계산
            cpu_changes = []
            for i in range(1, len(recent_cpu)):
                if recent_times[i] - recent_times[i-1] > 0:
                    rate = (recent_cpu[i] - recent_cpu[i-1]) / (recent_times[i] - recent_times[i-1])
                    cpu_changes.append(abs(rate))
            
            if not cpu_changes:
                return 'unknown', 0, 40
            
            avg_change_rate = mean(cpu_changes)
            max_change_rate = max(cpu_changes)
            
            # 변동성 계산
            cpu_std = stdev(recent_cpu) if len(recent_cpu) > 1 else 0
            cpu_mean = mean(recent_cpu)
            coefficient_of_variation = (cpu_std / cpu_mean) if cpu_mean > 0 else 0
            
            # 패턴 결정
            service_config = self.services[service_name]
            
            if max_change_rate > 10 or coefficient_of_variation > 0.5:
                pattern = 'spike'
                cpu_threshold = service_config['cpu_threshold_spike']
                confidence = min(80, max_change_rate * 5)
            elif avg_change_rate > 1 or coefficient_of_variation > 0.3:
                pattern = 'gradual'
                cpu_threshold = service_config['cpu_threshold_gradual']
                confidence = 60
            else:
                pattern = 'gradual'  # 기본값
                cpu_threshold = service_config['cpu_threshold_gradual']
                confidence = 40
            
            return pattern, confidence, cpu_threshold
            
        except Exception:
            return 'unknown', 0, self.services[service_name]['cpu_threshold_gradual']
    
    def get_current_task_count(self, service_name):
        try:
            response = self.ecs.describe_services(
                cluster=self.cluster_name,
                services=[service_name]
            )
            if response['services']:
                return response['services'][0]['desiredCount']
            return 0
        except Exception:
            return 0
    
    def get_cpu_utilization(self, service_name, minutes=3):
        """CPU 사용률 조회"""
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(minutes=minutes)
        
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
                Period=60,
                Statistics=['Average'],
                Unit='Percent'
            )
            
            if response['Datapoints']:
                datapoints = sorted(response['Datapoints'], key=lambda x: x['Timestamp'], reverse=True)
                latest = datapoints[0]
                return latest.get('Average', 0)
            return 0
            
        except Exception:
            return 0
    
    def get_memory_utilization(self, service_name, minutes=3):
        """메모리 사용률 조회"""
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(minutes=minutes)
        
        try:
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ECS',
                MetricName='MemoryUtilization',
                Dimensions=[
                    {'Name': 'ServiceName', 'Value': service_name},
                    {'Name': 'ClusterName', 'Value': self.cluster_name}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=60,
                Statistics=['Average', 'Maximum'],
                Unit='Percent'
            )
            
            if response['Datapoints']:
                datapoints = sorted(response['Datapoints'], key=lambda x: x['Timestamp'], reverse=True)
                latest = datapoints[0]
                return latest.get('Maximum', latest.get('Average', 0))
            return 0
            
        except Exception:
            return 0
    
    def get_average_response_time(self, log_group_name, minutes=2):
        """응답시간 조회 - 간소화"""
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(minutes=minutes)
        
        # 로그 그룹이 존재하지 않거나 데이터가 없는 경우 0 반환
        try:
            # 로그 그룹 존재 확인
            self.logs.describe_log_groups(logGroupNamePrefix=log_group_name, limit=1)
        except Exception:
            return 0
        
        query = """
        fields @timestamp, @message
        | filter @message like /ms|response|duration/
        | sort @timestamp desc
        | limit 50
        """
        
        try:
            # 로그 보존 기간 확인을 위해 더 넓은 범위로 시작
            extended_start = end_time - timedelta(hours=1)  # 1시간 전부터
            
            response = self.logs.start_query(
                logGroupName=log_group_name,
                startTime=int(extended_start.timestamp()),
                endTime=int(end_time.timestamp()),
                queryString=query
            )
            
            # 짧은 타임아웃
            max_wait = 25  # 5초
            wait_count = 0
            
            while wait_count < max_wait:
                result = self.logs.get_query_results(queryId=response['queryId'])
                
                if result['status'] == 'Complete':
                    break
                elif result['status'] == 'Failed':
                    return 0
                    
                time.sleep(0.2)
                wait_count += 1
            
            if result['status'] != 'Complete':
                return 0
            
            response_times = []
            
            # 간단한 정규식 패턴만 사용
            patterns = [
                (r'(\d+(?:\.\d+)?)ms\b', 1000),
                (r'"response_time"\s*:\s*(\d+(?:\.\d+)?)', 1000),
                (r'"latency"\s*:\s*(\d+(?:\.\d+)?)', 1000),
            ]
            
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
                        if log_message.strip().startswith('{'):
                            log_data = json.loads(log_message)
                            for key in ['latency', 'response_time', 'duration']:
                                if key in log_data:
                                    time_value = float(log_data[key])
                                    if 0.001 <= time_value <= 10:
                                        response_times.append(time_value)
                                        break
                    except:
                        pass
                    
                    # 정규식 매칭
                    for pattern, divisor in patterns:
                        match = re.search(pattern, log_message, re.IGNORECASE)
                        if match:
                            try:
                                time_value = float(match.group(1))
                                time_seconds = time_value / divisor
                                
                                if 0.001 <= time_seconds <= 10:
                                    response_times.append(time_seconds)
                                    break
                            except ValueError:
                                continue
                            
                except Exception:
                    continue
            
            if response_times:
                sorted_times = sorted(response_times)
                p95_index = int(len(sorted_times) * 0.95)
                return sorted_times[p95_index] if p95_index < len(sorted_times) else sorted_times[-1]
            
            return 0
            
        except Exception:
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
            print(f"  → 스케일링: {service_name} = {desired_count}개 태스크 ({reason})")
            return True
            
        except Exception as e:
            print(f"  → 스케일링 실패: {service_name} - {e}")
            return False
    
    def auto_scale_service(self, service_name):
        service_config = self.services[service_name]
        
        current_tasks = self.get_current_task_count(service_name)
        if current_tasks == 0:
            print(f"  {service_name}: 서비스 없음")
            return
        
        # 메트릭 수집
        cpu_utilization = self.get_cpu_utilization(service_name)
        memory_utilization = self.get_memory_utilization(service_name)
        avg_response_time = self.get_average_response_time(service_config['log_group'])
        
        # 패턴 분석
        pattern, confidence, cpu_threshold = self.analyze_traffic_pattern(
            service_name, cpu_utilization, avg_response_time
        )
        
        service_config['current_pattern'] = pattern
        service_config['pattern_confidence'] = confidence
        
        # 간단한 상태 출력
        print(f"  {service_name}: 태스크={current_tasks}, 응답시간={avg_response_time:.3f}초, CPU={cpu_utilization:.1f}%, 메모리={memory_utilization:.1f}%")
        
        # 스케일링 결정 (OR 조건)
        response_exceeded = avg_response_time > service_config['response_time_threshold']
        cpu_exceeded = cpu_utilization > cpu_threshold
        
        if response_exceeded or cpu_exceeded:
            service_config['violation_count'] += 1
            
            if service_config['violation_count'] >= service_config['violation_threshold']:
                current_time = time.time()
                cooldown = self.scale_up_cooldown
                cooldown_remaining = cooldown - (current_time - service_config['last_scale_time'])
                
                if cooldown_remaining <= 0:
                    increment = 2 if pattern == 'spike' and cpu_utilization > 80 else 1
                    new_count = min(current_tasks + increment, service_config['max_tasks'])
                    
                    if new_count > current_tasks:
                        self.scale_service(service_name, new_count, f"high load ({pattern})")
                        service_config['violation_count'] = 0
        else:
            service_config['violation_count'] = 0
            
            # 스케일 다운
            if (avg_response_time < 0.15 and 
                cpu_utilization < 20 and 
                current_tasks > service_config['min_tasks']):
                
                current_time = time.time()
                if current_time - service_config['last_scale_time'] > self.scale_down_cooldown:
                    new_count = max(service_config['min_tasks'], current_tasks - 1)
                    self.scale_service(service_name, new_count, "low load")
    
    def run(self):
        print("🚀 ECS Auto Scaler 시작")
        print(f"📋 모니터링 서비스: {list(self.services.keys())}")
        
        iteration = 0
        while True:
            try:
                iteration += 1
                print(f"\n--- 반복 #{iteration} ({datetime.now().strftime('%H:%M:%S')}) ---")
                
                for service_name in self.services.keys():
                    try:
                        self.auto_scale_service(service_name)
                    except Exception as e:
                        print(f"  {service_name}: 오류 - {e}")
                
                print("15초 대기...")
                time.sleep(15)
                
            except KeyboardInterrupt:
                print("\n종료")
                break
            except Exception as e:
                print(f"오류: {e}")
                time.sleep(60)

def main():
    autoscaler = SmartTrafficAutoscaler(
        cluster_name="apdev-ecs-cluster",
        asg_name="apdev-ecs-asg"
    )
    autoscaler.run()

if __name__ == "__main__":
    main()