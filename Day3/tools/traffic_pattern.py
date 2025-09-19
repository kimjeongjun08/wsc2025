# #!/usr/bin/env python3
# """
# AWS ALB 트래픽 패턴 분석 툴
# apdev-alb의 product-tg, stress-tg, user-tg 타겟 그룹에서 request count를 모니터링
# """

# import boto3
# import time
# from datetime import datetime, timedelta
# import pytz
# from collections import defaultdict, deque
# import statistics
# import json
# from typing import Dict, List, Tuple
# import argparse
# import sys

# class TrafficPatternAnalyzer:
#     def __init__(self, load_balancer_name: str, region: str = 'ap-northeast-2'):
#         """
#         트래픽 패턴 분석기 초기화
        
#         Args:
#             load_balancer_name: ALB 이름 (예: apdev-alb)
#             region: AWS 리전
#         """
#         self.load_balancer_name = load_balancer_name
#         self.region = region
#         self.target_groups = ['product-tg', 'stress-tg', 'user-tg']
#         self.period_minutes = 1  # 기본 집계 기간 (분) - 실시간 모니터링에 최적화
        
#         # AWS 클라이언트 초기화
#         try:
#             self.cloudwatch = boto3.client('cloudwatch', region_name=region)
#             self.elbv2 = boto3.client('elbv2', region_name=region)
#         except Exception as e:
#             print(f"❌ AWS 클라이언트 초기화 실패: {e}")
#             sys.exit(1)
        
#         # 한국 시간대 설정
#         self.kst = pytz.timezone('Asia/Seoul')
        
#         # 데이터 저장용
#         self.traffic_data = defaultdict(deque)  # 각 타겟 그룹별 트래픽 데이터
#         self.history_length = 60  # 최근 60개 데이터 포인트 유지 (1시간 분량)
#         self.previous_values = {}  # 이전 값 저장
#         self.pattern_thresholds = {
#             'spike': 30,      # 급증 임계값 (% 증가) - 1분 단위에 맞게 조정
#             'drop': -25,      # 급감 임계값 (% 감소)
#             'high_traffic': 50,   # 높은 트래픽 임계값 (1분당)
#         }
        
#     def get_alb_arn(self) -> str:
#         """ALB ARN 가져오기"""
#         try:
#             response = self.elbv2.describe_load_balancers(
#                 Names=[self.load_balancer_name]
#             )
#             return response['LoadBalancers'][0]['LoadBalancerArn']
#         except Exception as e:
#             print(f"❌ ALB '{self.load_balancer_name}' 정보 가져오기 실패: {e}")
#             return None
    
#     def get_target_group_metrics(self, target_group: str, period_minutes: int = 5) -> float:
#         """
#         특정 타겟 그룹의 RequestCount 메트릭 가져오기
        
#         Args:
#             target_group: 타겟 그룹 이름
#             period_minutes: 집계 기간 (분 단위, 기본값: 5분)
            
#         Returns:
#             지정된 기간 동안의 RequestCount 합계
#         """
#         try:
#             # KST 시간을 UTC로 변환하여 CloudWatch에 전달
#             kst_now = datetime.now(self.kst)
#             end_time = kst_now.astimezone(pytz.UTC).replace(tzinfo=None)
#             start_time = end_time - timedelta(minutes=period_minutes)
            
#             response = self.cloudwatch.get_metric_statistics(
#                 Namespace='AWS/ApplicationELB',
#                 MetricName='RequestCount',
#                 Dimensions=[
#                     {
#                         'Name': 'LoadBalancer',
#                         'Value': self.load_balancer_name.replace('app/', '').split('/')[0]
#                     },
#                     {
#                         'Name': 'TargetGroup',
#                         'Value': target_group
#                     }
#                 ],
#                 StartTime=start_time,
#                 EndTime=end_time,
#                 Period=period_minutes * 60,  # 분을 초로 변환
#                 Statistics=['Sum']  # RequestCount 합계
#             )
            
#             if response['Datapoints']:
#                 # 가장 최근 데이터포인트 반환
#                 latest = max(response['Datapoints'], key=lambda x: x['Timestamp'])
#                 return latest['Sum']
#             else:
#                 return 0.0
                
#         except Exception as e:
#             print(f"⚠️  {target_group} 메트릭 가져오기 실패: {e}")
#             return 0.0
    
#     def analyze_pattern(self, target_group: str, current_value: float) -> Dict:
#         """
#         트래픽 패턴 분석
        
#         Args:
#             target_group: 타겟 그룹 이름
#             current_value: 현재 RequestCount 값
            
#         Returns:
#             분석 결과 딕셔너리
#         """
#         analysis = {
#             'target_group': target_group,
#             'current_value': current_value,
#             'timestamp': datetime.now(self.kst),  # KST 시간 사용
#             'patterns': [],
#             'trend': 'stable',
#             'change_percent': 0
#         }
        
#         # 이전 값과 비교
#         if target_group in self.previous_values:
#             prev_value = self.previous_values[target_group]
#             if prev_value > 0:
#                 change_percent = ((current_value - prev_value) / prev_value) * 100
#                 analysis['change_percent'] = change_percent
                
#                 # 패턴 감지
#                 if change_percent >= self.pattern_thresholds['spike']:
#                     analysis['patterns'].append('SPIKE')
#                     analysis['trend'] = 'increasing'
#                 elif change_percent <= self.pattern_thresholds['drop']:
#                     analysis['patterns'].append('DROP')
#                     analysis['trend'] = 'decreasing'
#                 elif change_percent > 10:
#                     analysis['trend'] = 'increasing'
#                 elif change_percent < -10:
#                     analysis['trend'] = 'decreasing'
        
#         # 높은 트래픽 감지
#         if current_value >= self.pattern_thresholds['high_traffic']:
#             analysis['patterns'].append('HIGH_TRAFFIC')
        
#         # 데이터 저장
#         self.traffic_data[target_group].append({
#             'timestamp': analysis['timestamp'],
#             'value': current_value,
#             'change_percent': analysis['change_percent']
#         })
        
#         # 최대 길이 유지
#         if len(self.traffic_data[target_group]) > self.history_length:
#             self.traffic_data[target_group].popleft()
        
#         # 트렌드 분석 (최근 10개 데이터 포인트 기준)
#         if len(self.traffic_data[target_group]) >= 10:
#             recent_values = [item['value'] for item in list(self.traffic_data[target_group])[-10:]]
#             avg_change = statistics.mean([item['change_percent'] for item in list(self.traffic_data[target_group])[-5:]])
            
#             if avg_change > 10:
#                 analysis['patterns'].append('SUSTAINED_INCREASE')
#             elif avg_change < -10:
#                 analysis['patterns'].append('SUSTAINED_DECREASE')
        
#         # 이전 값 업데이트
#         self.previous_values[target_group] = current_value
        
#         return analysis
    
#     def format_analysis_output(self, analysis: Dict) -> str:
#         """분석 결과를 포맷된 문자열로 변환"""
#         timestamp = analysis['timestamp'].strftime('%H:%M:%S')
#         target_group = analysis['target_group']
#         current_value = analysis['current_value']
#         change_percent = analysis['change_percent']
#         patterns = analysis['patterns']
        
#         # 기본 정보
#         output = f"🎯 [{timestamp} KST] {target_group}: {current_value:.1f} requests"
        
#         # 변화율 표시
#         if change_percent != 0:
#             if change_percent > 0:
#                 output += f" (🔺 +{change_percent:.1f}%)"
#             else:
#                 output += f" (🔻 {change_percent:.1f}%)"
        
#         # 패턴 표시
#         if patterns:
#             pattern_emojis = {
#                 'SPIKE': '🚀',
#                 'DROP': '📉',
#                 'HIGH_TRAFFIC': '⚡',
#                 'SUSTAINED_INCREASE': '📈',
#                 'SUSTAINED_DECREASE': '📉'
#             }
#             pattern_str = ' '.join([f"{pattern_emojis.get(p, '⚪')} {p}" for p in patterns])
#             output += f" {pattern_str}"
        
#         return output
    
#     def run_continuous_analysis(self, interval: int = 60):
#         """
#         연속적인 트래픽 패턴 분석 실행
        
#         Args:
#             interval: 모니터링 간격 (초)
#         """
#         print(f"🚀 ALB '{self.load_balancer_name}' 트래픽 패턴 분석 시작")
#         print(f"📊 타겟 그룹: {', '.join(self.target_groups)}")
#         print(f"📈 메트릭 집계 기간: {self.period_minutes}분 (RequestCount 합계)")
#         print(f"⏱️  모니터링 간격: {interval}초")
#         print("=" * 80)
        
#         try:
#             while True:
#                 kst_now = datetime.now(self.kst)
#                 print(f"\n📅 {kst_now.strftime('%Y-%m-%d %H:%M:%S KST')} - 트래픽 분석 중...")
                
#                 for target_group in self.target_groups:
#                     # 메트릭 가져오기
#                     request_count = self.get_target_group_metrics(target_group, self.period_minutes)
                    
#                     # 패턴 분석
#                     analysis = self.analyze_pattern(target_group, request_count)
                    
#                     # 결과 출력
#                     print(self.format_analysis_output(analysis))
                
#                 # 요약 정보
#                 total_requests = sum(self.previous_values.values())
#                 print(f"📊 총 요청 수: {total_requests:.1f} requests")
#                 print("-" * 80)
                
#                 # 대기
#                 time.sleep(interval)
                
#         except KeyboardInterrupt:
#             print("\n\n⏹️  모니터링을 중단합니다.")
#             self.print_summary()
#         except Exception as e:
#             print(f"\n❌ 오류 발생: {e}")
    
#     def print_summary(self):
#         """트래픽 분석 요약 출력"""
#         print("\n" + "="*80)
#         print("📊 트래픽 분석 요약")
#         print("="*80)
        
#         for target_group in self.target_groups:
#             if target_group in self.traffic_data:
#                 data = list(self.traffic_data[target_group])
#                 if data:
#                     values = [item['value'] for item in data]
#                     avg_value = statistics.mean(values)
#                     max_value = max(values)
#                     min_value = min(values)
                    
#                     print(f"\n🎯 {target_group}:")
#                     print(f"   평균: {avg_value:.1f} requests")
#                     print(f"   최대: {max_value:.1f} requests")
#                     print(f"   최소: {min_value:.1f} requests")

# def main():
#     parser = argparse.ArgumentParser(description='AWS ALB 트래픽 패턴 분석 툴')
#     parser.add_argument('--alb-name', default='apdev-alb', 
#                        help='ALB 이름 (기본값: apdev-alb)')
#     parser.add_argument('--region', default='ap-northeast-2',
#                        help='AWS 리전 (기본값: ap-northeast-2)')
#     parser.add_argument('--interval', type=int, default=60,
#                        help='모니터링 간격 (초, 기본값: 60)')
#     parser.add_argument('--period', type=int, default=1,
#                        help='메트릭 집계 기간 (분 단위, 기본값: 1분 - 실시간 모니터링에 최적화)')
    
#     args = parser.parse_args()
    
#     # 트래픽 분석기 생성 및 실행
#     analyzer = TrafficPatternAnalyzer(args.alb_name, args.region)
#     analyzer.period_minutes = args.period  # 집계 기간 설정
#     analyzer.run_continuous_analysis(args.interval)

# if __name__ == "__main__":
#     main()
#!/usr/bin/env python3
"""
AWS ALB 트래픽 패턴 분석 툴 - 디버그 버전
apdev-alb의 product-tg, stress-tg, user-tg 타겟 그룹에서 request count를 모니터링
"""

import boto3
import time
from datetime import datetime, timedelta
import pytz
from collections import defaultdict, deque
import statistics
import json
from typing import Dict, List, Tuple
import argparse
import sys

class TrafficPatternAnalyzer:
    def __init__(self, load_balancer_name: str, region: str = 'ap-northeast-2'):
        """
        트래픽 패턴 분석기 초기화
        
        Args:
            load_balancer_name: ALB 이름 (예: apdev-alb)
            region: AWS 리전
        """
        self.load_balancer_name = load_balancer_name
        self.region = region
        self.target_groups = ['product-tg', 'stress-tg', 'user-tg']
        self.period_minutes = 1
        
        # AWS 클라이언트 초기화
        try:
            self.cloudwatch = boto3.client('cloudwatch', region_name=region)
            self.elbv2 = boto3.client('elbv2', region_name=region)
        except Exception as e:
            print(f"❌ AWS 클라이언트 초기화 실패: {e}")
            sys.exit(1)
        
        # 한국 시간대 설정
        self.kst = pytz.timezone('Asia/Seoul')
        
        # 데이터 저장용
        self.traffic_data = defaultdict(deque)
        self.history_length = 60
        self.previous_values = {}
        self.pattern_thresholds = {
            'spike': 30,
            'drop': -25,
            'high_traffic': 50,
        }
        
        # ALB와 타겟 그룹 정보 초기화
        self.alb_arn = None
        self.target_group_arns = {}
        self.initialize_aws_resources()
        
    def initialize_aws_resources(self):
        """ALB와 타겟 그룹 정보 초기화 및 검증"""
        print("🔍 AWS 리소스 정보 확인 중...")
        
        # ALB 정보 가져오기
        try:
            response = self.elbv2.describe_load_balancers()
            alb_found = False
            
            print("\n📋 사용 가능한 ALB 목록:")
            for lb in response['LoadBalancers']:
                lb_name = lb['LoadBalancerName']
                print(f"  - {lb_name}")
                if lb_name == self.load_balancer_name:
                    self.alb_arn = lb['LoadBalancerArn']
                    alb_found = True
                    print(f"    ✅ 대상 ALB 발견: {lb_name}")
            
            if not alb_found:
                print(f"❌ ALB '{self.load_balancer_name}'를 찾을 수 없습니다.")
                return False
                
        except Exception as e:
            print(f"❌ ALB 정보 가져오기 실패: {e}")
            return False
        
        # 타겟 그룹 정보 가져오기
        try:
            response = self.elbv2.describe_target_groups()
            found_target_groups = []
            
            print("\n📋 사용 가능한 타겟 그룹 목록:")
            for tg in response['TargetGroups']:
                tg_name = tg['TargetGroupName']
                print(f"  - {tg_name}")
                if tg_name in self.target_groups:
                    self.target_group_arns[tg_name] = tg['TargetGroupArn']
                    found_target_groups.append(tg_name)
                    print(f"    ✅ 대상 타겟 그룹 발견: {tg_name}")
            
            missing_tgs = set(self.target_groups) - set(found_target_groups)
            if missing_tgs:
                print(f"⚠️  다음 타겟 그룹을 찾을 수 없습니다: {missing_tgs}")
                self.target_groups = found_target_groups
                print(f"📊 분석할 타겟 그룹: {self.target_groups}")
                
        except Exception as e:
            print(f"❌ 타겟 그룹 정보 가져오기 실패: {e}")
            return False
        
        return True
    
    def get_correct_dimension_values(self, target_group: str) -> Tuple[str, str]:
        """올바른 Dimension 값 반환"""
        # ALB ARN에서 LoadBalancer dimension 값 추출
        # arn:aws:elasticloadbalancing:region:account:loadbalancer/app/name/id
        # -> app/name/id 형태로 변환
        alb_dimension = self.alb_arn.split('/')[-3:]  # ['app', 'name', 'id']
        alb_dimension_value = '/'.join(alb_dimension)
        
        # 타겟 그룹 ARN에서 TargetGroup dimension 값 추출
        # arn:aws:elasticloadbalancing:region:account:targetgroup/name/id
        # -> targetgroup/name/id 형태로 변환
        tg_arn = self.target_group_arns[target_group]
        tg_dimension = tg_arn.split('/')[-3:]  # ['targetgroup', 'name', 'id']
        tg_dimension_value = '/'.join(tg_dimension)
        
        return alb_dimension_value, tg_dimension_value
    
    def debug_cloudwatch_query(self, target_group: str, period_minutes: int = 5):
        """CloudWatch 쿼리 디버그 정보 출력"""
        try:
            alb_dim, tg_dim = self.get_correct_dimension_values(target_group)
            
            kst_now = datetime.now(self.kst)
            end_time = kst_now.astimezone(pytz.UTC).replace(tzinfo=None)
            start_time = end_time - timedelta(minutes=period_minutes)
            
            print(f"\n🔍 CloudWatch 쿼리 디버그 - {target_group}:")
            print(f"  📅 시간 범위: {start_time} ~ {end_time} UTC")
            print(f"  📊 Namespace: AWS/ApplicationELB")
            print(f"  📏 MetricName: RequestCount")
            print(f"  🎯 LoadBalancer Dimension: {alb_dim}")
            print(f"  🎯 TargetGroup Dimension: {tg_dim}")
            print(f"  ⏱️  Period: {period_minutes * 60}초")
            
            # 실제 쿼리 실행
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ApplicationELB',
                MetricName='RequestCount',
                Dimensions=[
                    {
                        'Name': 'LoadBalancer',
                        'Value': alb_dim
                    },
                    {
                        'Name': 'TargetGroup',
                        'Value': tg_dim
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=period_minutes * 60,
                Statistics=['Sum']
            )
            
            print(f"  📈 반환된 데이터포인트 수: {len(response['Datapoints'])}")
            if response['Datapoints']:
                for dp in response['Datapoints']:
                    print(f"    - {dp['Timestamp']}: {dp['Sum']} requests")
            else:
                print("    ⚠️  데이터포인트 없음")
                
                # ALB 전체 레벨에서 메트릭 확인
                print(f"  🔄 ALB 전체 레벨 메트릭 확인...")
                alb_only_response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/ApplicationELB',
                    MetricName='RequestCount',
                    Dimensions=[
                        {
                            'Name': 'LoadBalancer',
                            'Value': alb_dim
                        }
                    ],
                    StartTime=end_time - timedelta(minutes=30),
                    EndTime=end_time,
                    Period=300,
                    Statistics=['Sum']
                )
                print(f"    📊 ALB 전체 30분간 데이터포인트 수: {len(alb_only_response['Datapoints'])}")
                if alb_only_response['Datapoints']:
                    for dp in alb_only_response['Datapoints']:
                        print(f"      - {dp['Timestamp']}: {dp['Sum']} requests (전체 ALB)")
                
                # 다른 가능한 dimension 조합 시도
                print(f"  🔄 타겟 그룹만으로 메트릭 확인...")
                tg_only_response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/ApplicationELB',
                    MetricName='RequestCount',
                    Dimensions=[
                        {
                            'Name': 'TargetGroup',
                            'Value': tg_dim
                        }
                    ],
                    StartTime=end_time - timedelta(minutes=30),
                    EndTime=end_time,
                    Period=300,
                    Statistics=['Sum']
                )
                print(f"    📊 타겟 그룹만 30분간 데이터포인트 수: {len(tg_only_response['Datapoints'])}")
                if tg_only_response['Datapoints']:
                    for dp in tg_only_response['Datapoints']:
                        print(f"      - {dp['Timestamp']}: {dp['Sum']} requests (타겟 그룹만)")
                
                # 잘못된 dimension 값으로 시도 (원래 코드 방식)
                print(f"  🔄 원래 dimension 형식으로 시도...")
                original_response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/ApplicationELB',
                    MetricName='RequestCount',
                    Dimensions=[
                        {
                            'Name': 'LoadBalancer',
                            'Value': self.load_balancer_name.replace('app/', '').split('/')[0]
                        },
                        {
                            'Name': 'TargetGroup',
                            'Value': target_group
                        }
                    ],
                    StartTime=end_time - timedelta(minutes=30),
                    EndTime=end_time,
                    Period=300,
                    Statistics=['Sum']
                )
                print(f"    📊 원래 방식 30분간 데이터포인트 수: {len(original_response['Datapoints'])}")
                if original_response['Datapoints']:
                    for dp in original_response['Datapoints']:
                        print(f"      - {dp['Timestamp']}: {dp['Sum']} requests (원래 방식)")
            
            return response
            
        except Exception as e:
            print(f"❌ CloudWatch 쿼리 디버그 실패: {e}")
            return None
    
    def get_target_group_metrics(self, target_group: str, period_minutes: int = 5) -> float:
        """특정 타겟 그룹의 RequestCount 메트릭 가져오기"""
        try:
            alb_dim, tg_dim = self.get_correct_dimension_values(target_group)
            
            kst_now = datetime.now(self.kst)
            end_time = kst_now.astimezone(pytz.UTC).replace(tzinfo=None)
            start_time = end_time - timedelta(minutes=period_minutes)
            
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/ApplicationELB',
                MetricName='RequestCount',
                Dimensions=[
                    {
                        'Name': 'LoadBalancer',
                        'Value': alb_dim
                    },
                    {
                        'Name': 'TargetGroup',
                        'Value': tg_dim
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=period_minutes * 60,
                Statistics=['Sum']
            )
            
            if response['Datapoints']:
                latest = max(response['Datapoints'], key=lambda x: x['Timestamp'])
                return latest['Sum']
            else:
                return 0.0
                
        except Exception as e:
            print(f"⚠️  {target_group} 메트릭 가져오기 실패: {e}")
            return 0.0
    
    def analyze_pattern(self, target_group: str, current_value: float) -> Dict:
        """트래픽 패턴 분석"""
        analysis = {
            'target_group': target_group,
            'current_value': current_value,
            'timestamp': datetime.now(self.kst),
            'patterns': [],
            'trend': 'stable',
            'change_percent': 0
        }
        
        if target_group in self.previous_values:
            prev_value = self.previous_values[target_group]
            if prev_value > 0:
                change_percent = ((current_value - prev_value) / prev_value) * 100
                analysis['change_percent'] = change_percent
                
                if change_percent >= self.pattern_thresholds['spike']:
                    analysis['patterns'].append('SPIKE')
                    analysis['trend'] = 'increasing'
                elif change_percent <= self.pattern_thresholds['drop']:
                    analysis['patterns'].append('DROP')
                    analysis['trend'] = 'decreasing'
                elif change_percent > 10:
                    analysis['trend'] = 'increasing'
                elif change_percent < -10:
                    analysis['trend'] = 'decreasing'
        
        if current_value >= self.pattern_thresholds['high_traffic']:
            analysis['patterns'].append('HIGH_TRAFFIC')
        
        self.traffic_data[target_group].append({
            'timestamp': analysis['timestamp'],
            'value': current_value,
            'change_percent': analysis['change_percent']
        })
        
        if len(self.traffic_data[target_group]) > self.history_length:
            self.traffic_data[target_group].popleft()
        
        if len(self.traffic_data[target_group]) >= 10:
            avg_change = statistics.mean([item['change_percent'] for item in list(self.traffic_data[target_group])[-5:]])
            
            if avg_change > 10:
                analysis['patterns'].append('SUSTAINED_INCREASE')
            elif avg_change < -10:
                analysis['patterns'].append('SUSTAINED_DECREASE')
        
        self.previous_values[target_group] = current_value
        return analysis
    
    def format_analysis_output(self, analysis: Dict) -> str:
        """분석 결과를 포맷된 문자열로 변환"""
        timestamp = analysis['timestamp'].strftime('%H:%M:%S')
        target_group = analysis['target_group']
        current_value = analysis['current_value']
        change_percent = analysis['change_percent']
        patterns = analysis['patterns']
        
        output = f"🎯 [{timestamp} KST] {target_group}: {current_value:.1f} requests"
        
        if change_percent != 0:
            if change_percent > 0:
                output += f" (🔺 +{change_percent:.1f}%)"
            else:
                output += f" (🔻 {change_percent:.1f}%)"
        
        if patterns:
            pattern_emojis = {
                'SPIKE': '🚀',
                'DROP': '📉',
                'HIGH_TRAFFIC': '⚡',
                'SUSTAINED_INCREASE': '📈',
                'SUSTAINED_DECREASE': '📉'
            }
            pattern_str = ' '.join([f"{pattern_emojis.get(p, '⚪')} {p}" for p in patterns])
            output += f" {pattern_str}"
        
        return output
    
    def run_debug_mode(self):
        """디버그 모드 실행 - 한 번만 실행하고 상세 정보 출력"""
        print("🐛 디버그 모드 실행")
        print("=" * 80)
        
        for target_group in self.target_groups:
            self.debug_cloudwatch_query(target_group, self.period_minutes)
            print("-" * 40)
    
    def run_continuous_analysis(self, interval: int = 60):
        """연속적인 트래픽 패턴 분석 실행"""
        print(f"🚀 ALB '{self.load_balancer_name}' 트래픽 패턴 분석 시작")
        print(f"📊 타겟 그룹: {', '.join(self.target_groups)}")
        print(f"📈 메트릭 집계 기간: {self.period_minutes}분")
        print(f"⏱️  모니터링 간격: {interval}초")
        print("=" * 80)
        
        try:
            while True:
                kst_now = datetime.now(self.kst)
                print(f"\n📅 {kst_now.strftime('%Y-%m-%d %H:%M:%S KST')} - 트래픽 분석 중...")
                
                for target_group in self.target_groups:
                    request_count = self.get_target_group_metrics(target_group, self.period_minutes)
                    analysis = self.analyze_pattern(target_group, request_count)
                    print(self.format_analysis_output(analysis))
                
                total_requests = sum(self.previous_values.values())
                print(f"📊 총 요청 수: {total_requests:.1f} requests")
                print("-" * 80)
                
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n\n⏹️  모니터링을 중단합니다.")
            self.print_summary()
        except Exception as e:
            print(f"\n❌ 오류 발생: {e}")
    
    def print_summary(self):
        """트래픽 분석 요약 출력"""
        print("\n" + "="*80)
        print("📊 트래픽 분석 요약")
        print("="*80)
        
        for target_group in self.target_groups:
            if target_group in self.traffic_data:
                data = list(self.traffic_data[target_group])
                if data:
                    values = [item['value'] for item in data]
                    avg_value = statistics.mean(values)
                    max_value = max(values)
                    min_value = min(values)
                    
                    print(f"\n🎯 {target_group}:")
                    print(f"   평균: {avg_value:.1f} requests")
                    print(f"   최대: {max_value:.1f} requests")
                    print(f"   최소: {min_value:.1f} requests")

def main():
    parser = argparse.ArgumentParser(description='AWS ALB 트래픽 패턴 분석 툴')
    parser.add_argument('--alb-name', default='apdev-alb', 
                       help='ALB 이름 (기본값: apdev-alb)')
    parser.add_argument('--region', default='ap-northeast-2',
                       help='AWS 리전 (기본값: ap-northeast-2)')
    parser.add_argument('--interval', type=int, default=60,
                       help='모니터링 간격 (초, 기본값: 60)')
    parser.add_argument('--period', type=int, default=5,
                       help='메트릭 집계 기간 (분 단위, 기본값: 5분)')
    parser.add_argument('--debug', action='store_true',
                       help='디버그 모드 실행 (한 번만 실행하고 상세 정보 출력)')
    
    args = parser.parse_args()
    
    analyzer = TrafficPatternAnalyzer(args.alb_name, args.region)
    analyzer.period_minutes = args.period
    
    if args.debug:
        analyzer.run_debug_mode()
    else:
        analyzer.run_continuous_analysis(args.interval)

if __name__ == "__main__":
    main()