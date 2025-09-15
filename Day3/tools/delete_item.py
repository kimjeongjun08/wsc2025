#!/usr/bin/env python3
import boto3
import pymysql
import os
from botocore.exceptions import ClientError

def delete_all_dynamodb_items():
    """DynamoDB product 테이블의 모든 아이템 삭제"""
    dynamodb = boto3.resource('dynamodb')
    
    try:
        table = dynamodb.Table('product')
        print("DynamoDB 테이블 'product' 삭제 중...")
        
        # 테이블의 모든 아이템 스캔
        response = table.scan()
        items = response['Items']
        
        # 페이지네이션 처리
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            items.extend(response['Items'])
        
        # 배치로 아이템 삭제
        with table.batch_writer() as batch:
            for item in items:
                batch.delete_item(Key={'id': item['id']})
        
        print(f"DynamoDB 테이블 'product'에서 {len(items)}개 아이템 삭제 완료")
        
    except ClientError as e:
        print(f"DynamoDB 오류: {e}")

def delete_all_mysql_data():
    """RDS MySQL user 테이블의 모든 데이터 삭제"""
    try:
        connection = pymysql.connect(
            host='apdev-rds-instance.cdnblsxzzpgz.ap-northeast-2.rds.amazonaws.com',
            user='admin',
            password='Skill53##',
            database='dev',
            charset='utf8mb4'
        )
        
        with connection.cursor() as cursor:
            print("MySQL 테이블 'user' 삭제 중...")
            cursor.execute("DELETE FROM user")
            affected_rows = cursor.rowcount
            print(f"MySQL 테이블 'user'에서 {affected_rows}개 행 삭제 완료")
            
        connection.commit()
        connection.close()
        
    except Exception as e:
        print(f"MySQL 오류: {e}")

def main():
    print("=== 모든 데이터 삭제 시작 ===")
    
    # 사용자 확인
    confirm = input("정말로 모든 데이터를 삭제하시겠습니까? (yes/no): ")
    if confirm.lower() != 'yes':
        print("삭제 작업이 취소되었습니다.")
        return
    
    print("\n1. DynamoDB 데이터 삭제 중...")
    delete_all_dynamodb_items()
    
    print("\n2. MySQL 데이터 삭제 중...")
    delete_all_mysql_data()
    
    print("\n=== 모든 데이터 삭제 완료 ===")

if __name__ == "__main__":
    main()