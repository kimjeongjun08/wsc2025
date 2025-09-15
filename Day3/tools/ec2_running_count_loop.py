#!/usr/bin/env python3
# ec2_running_count_loop.py
import boto3
import csv
import time
from datetime import datetime
import sys

def get_running_instances_count(region='ap-northeast-2'):
    """실행 중인 EC2 인스턴스 개수를 반환"""
    try:
        ec2 = boto3.client('ec2', region_name=region)
        
        response = ec2.describe_instances(
            Filters=[
                {
                    'Name': 'instance-state-name',
                    'Values': ['running']
                }
            ]
        )
        
        # 모든 실행 중인 인스턴스 개수 계산
        running_count = 0
        for reservation in response['Reservations']:
            running_count += len(reservation['Instances'])
        
        return running_count
    
    except Exception as e:
        print(f"에러 발생: {e}")
        return 0

def write_to_csv(filename, timestamp, region, count):
    """CSV 파일에 데이터 기록"""
    try:
        with open(filename, 'a', newline='', encoding='utf-8') as file:
            writer = csv.writer(file)
            writer.writerow([timestamp, region, count])
    except Exception as e:
        print(f"CSV 쓰기 에러: {e}")

def create_csv_header(filename):
    """CSV 헤더 생성"""
    try:
        with open(filename, 'w', newline='', encoding='utf-8') as file:
            writer = csv.writer(file)
            writer.writerow(['timestamp', 'region', 'running_count'])
    except Exception as e:
        print(f"CSV 헤더 생성 에러: {e}")

def main():
    output_file = "./output.csv"
    region = "ap-northeast-2"
    
    # CSV 파일이 없으면 헤더 생성
    try:
        with open(output_file, 'r'):
            pass
    except FileNotFoundError:
        create_csv_header(output_file)
        print(f"CSV 파일 생성: {output_file}")
    
    print("EC2 인스턴스 모니터링 시작... (Ctrl+C로 종료)")
    
    try:
        while True:
            # 현재 시간
            timestamp = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
            
            # 실행 중인 인스턴스 개수 조회
            running_count = get_running_instances_count(region)
            
            # CSV에 기록
            write_to_csv(output_file, timestamp, region, running_count)
            
            # 콘솔에 출력
            print(f"기록됨: {timestamp} - {running_count}개 인스턴스")
            
            # 60초 대기
            time.sleep(60)
            
    except KeyboardInterrupt:
        print("\n스크립트를 종료합니다...")
        sys.exit(0)
    except Exception as e:
        print(f"예상치 못한 에러: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()