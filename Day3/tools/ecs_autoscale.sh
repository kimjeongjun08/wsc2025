#!/bin/bash

# 기존 프로세스 종료
pkill -f ecs_svc_scaling.py 2>/dev/null
sleep 1

# 로그 디렉토리 생성
mkdir -p /home/ec2-user/apdev/logs

echo "🚀 오토스케일러 시작 (로그 로테이션 적용)"
echo "📊 설정: 캐시 30초, 로그 쿼리 10초, AND 조건"
echo "⚡ 임계값: 응답시간 0.5초 & CPU 85% & 메모리 80%"
echo "💾 로그: /home/ec2-user/apdev/logs/autoscaler.log (10MB 로테이션)"
echo ""

# 백그라운드 실행
nohup python -u ecs_svc_scaling.py >> autoscaler.log 2>&1 &

SCALER_PID=$!
echo "✅ 오토스케일러 시작됨 (PID: $SCALER_PID)"
echo ""
echo "📋 명령어:"
echo "  로그 보기: tail -f /home/ec2-user/apdev/autoscaler.log"
echo "  종료: pkill -f ecs_svc_scaling.py"
echo "  상태 확인: ps aux | grep ecs_svc_scaling"
echo ""
echo "🔥 인스턴스: 최소 3개, 원하는 3개, 최대 10개"
echo "📊 로그 확인: tail -f /home/ec2-user/apdev/autoscaler.log"
