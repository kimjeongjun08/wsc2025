import boto3
import json
import time
from datetime import datetime, timedelta
from collections import defaultdict, Counter

class WAFTrafficAnalyzer:
    def __init__(self):
        self.logs = boto3.client('logs', region_name='us-east-1')
        self.log_group = 'aws-waf-logs-cloudwatch'
        self.log_stream = 'cloudfront_apdev-waf_0'
    
    def get_waf_logs(self, start_time, end_time, limit=10000):
        """WAF 로그 조회"""
        try:
            response = self.logs.get_log_events(
                logGroupName=self.log_group,
                logStreamName=self.log_stream,
                startTime=int(start_time.timestamp() * 1000),
                endTime=int(end_time.timestamp() * 1000),
                limit=limit,
                startFromHead=True
            )
            return response.get('events', [])
        except Exception as e:
            print(f"❌ WAF 로그 조회 실패: {e}")
            return []
    
    def parse_waf_log(self, log_message):
        """WAF 로그 파싱"""
        try:
            return json.loads(log_message)
        except:
            return None
    
    def analyze_traffic_volume(self, hours=1):
        """트래픽 볼륨 분석"""
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=hours)
        
        print(f"🔍 WAF 트래픽 분석 ({hours}시간)")
        print(f"📅 분석 기간: {start_time.strftime('%H:%M:%S')} ~ {end_time.strftime('%H:%M:%S')}")
        
        # 로그 조회
        events = self.get_waf_logs(start_time, end_time)
        print(f"📊 로그 이벤트: {len(events)}개")
        
        if not events:
            print("❌ 로그 데이터 없음")
            return
        
        # 통계 수집
        total_requests = 0
        method_counts = Counter()
        status_counts = Counter()
        country_counts = Counter()
        uri_counts = Counter()
        ip_counts = Counter()
        minute_counts = defaultdict(int)
        
        for event in events:
            waf_log = self.parse_waf_log(event['message'])
            if not waf_log:
                continue
            
            total_requests += 1
            
            # 시간별 분포
            timestamp = event['timestamp'] / 1000
            dt = datetime.fromtimestamp(timestamp)
            minute_key = dt.strftime('%H:%M')
            minute_counts[minute_key] += 1
            
            # HTTP 정보
            http_request = waf_log.get('httpRequest', {})
            method = http_request.get('httpMethod', 'UNKNOWN')
            uri = http_request.get('uri', '/')
            client_ip = http_request.get('clientIP', 'unknown')
            
            method_counts[method] += 1
            uri_counts[uri] += 1
            ip_counts[client_ip] += 1
            
            # 응답 상태
            if 'responseCodeSent' in waf_log:
                status_counts[waf_log['responseCodeSent']] += 1
            
            # 국가 정보
            if 'httpSourceName' in waf_log:
                country_counts[waf_log['httpSourceName']] += 1
        
        # 결과 출력
        print(f"\n📊 트래픽 요약")
        print(f"🔥 총 요청 수: {total_requests:,}개")
        print(f"⏱️  시간당 평균: {total_requests/hours:,.0f}개/시간")
        print(f"📈 분당 평균: {total_requests/(hours*60):,.0f}개/분")
        
        # HTTP 메소드 분포
        print(f"\n📊 HTTP 메소드 분포")
        for method, count in method_counts.most_common():
            percentage = (count / total_requests) * 100
            print(f"{method:8} | {count:6,}개 ({percentage:5.1f}%)")
        
        # 응답 상태 분포
        if status_counts:
            print(f"\n📊 응답 상태 분포")
            for status, count in status_counts.most_common():
                percentage = (count / total_requests) * 100
                print(f"{status:8} | {count:6,}개 ({percentage:5.1f}%)")
        
        # 상위 URI
        print(f"\n📊 상위 URI (Top 10)")
        for uri, count in uri_counts.most_common(10):
            percentage = (count / total_requests) * 100
            uri_display = uri[:50] + "..." if len(uri) > 50 else uri
            print(f"{count:6,}개 ({percentage:5.1f}%) | {uri_display}")
        
        # 상위 IP
        print(f"\n📊 상위 클라이언트 IP (Top 10)")
        for ip, count in ip_counts.most_common(10):
            percentage = (count / total_requests) * 100
            print(f"{ip:15} | {count:6,}개 ({percentage:5.1f}%)")
        
        # 시간별 분포 (최근 20분)
        print(f"\n📊 시간별 요청 분포 (최근 20분)")
        recent_minutes = sorted(minute_counts.items())[-20:]
        for minute, count in recent_minutes:
            bar = "█" * min(50, count // max(1, max(minute_counts.values()) // 50))
            print(f"{minute} | {count:4,}개 | {bar}")
        
        return {
            'total_requests': total_requests,
            'requests_per_hour': total_requests / hours,
            'requests_per_minute': total_requests / (hours * 60),
            'method_distribution': dict(method_counts),
            'status_distribution': dict(status_counts),
            'top_uris': dict(uri_counts.most_common(20)),
            'top_ips': dict(ip_counts.most_common(20))
        }
    
    def monitor_realtime(self, interval=60):
        """실시간 트래픽 모니터링"""
        print(f"🔄 실시간 WAF 트래픽 모니터링 시작 ({interval}초 간격)")
        
        while True:
            try:
                print(f"\n=== {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===")
                self.analyze_traffic_volume(hours=0.1)  # 6분간
                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("\n모니터링 종료")
                break
            except Exception as e:
                print(f"오류 발생: {e}")
                time.sleep(60)

def main():
    analyzer = WAFTrafficAnalyzer()
    
    print("WAF 트래픽 분석기")
    print("1. 트래픽 분석 (1시간)")
    print("2. 트래픽 분석 (6시간)")
    print("3. 트래픽 분석 (24시간)")
    print("4. 실시간 모니터링")
    
    choice = input("선택하세요 (1-4): ").strip()
    
    if choice == "1":
        analyzer.analyze_traffic_volume(hours=1)
    elif choice == "2":
        analyzer.analyze_traffic_volume(hours=6)
    elif choice == "3":
        analyzer.analyze_traffic_volume(hours=24)
    elif choice == "4":
        analyzer.monitor_realtime()
    else:
        print("잘못된 선택")

if __name__ == "__main__":
    main()