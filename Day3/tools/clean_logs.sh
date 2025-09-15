#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 로그 그룹 정의
PRODUCT_LOG="/ecs/logs/product"
USER_LOG="/ecs/logs/user"
STRESS_LOG="/ecs/logs/stress"

# 로그 디렉토리 생성
mkdir -p log
APP_LOG="log/app.log"

# 터미널 크기 가져오기
COLS=$(tput cols)
COL_WIDTH=$((COLS / 3))

# 헤더 출력
print_header() {
    printf "${GREEN}%-${COL_WIDTH}s${BLUE}%-${COL_WIDTH}s${RED}%-${COL_WIDTH}s${NC}\n" "USER" "PRODUCT" "STRESS"
    printf "%-${COL_WIDTH}s%-${COL_WIDTH}s%-${COL_WIDTH}s\n" "$(printf '=%.0s' $(seq 1 $((COL_WIDTH-1))))" "$(printf '=%.0s' $(seq 1 $((COL_WIDTH-1))))" "$(printf '=%.0s' $(seq 1 $((COL_WIDTH-1))))"
}

# 로그 파일 생성
USER_TEMP="/tmp/user_clean.tmp"
PRODUCT_TEMP="/tmp/product_clean.tmp"
STRESS_TEMP="/tmp/stress_clean.tmp"

# 임시 파일 초기화
> "$USER_TEMP"
> "$PRODUCT_TEMP"
> "$STRESS_TEMP"

# 로그 파싱 함수
parse_log() {
    local line="$1"
    
    # GIN 로그 패턴 매칭: GET /path?query 200 12.5ms
    if echo "$line" | grep -q "GET\|POST\|PUT\|DELETE"; then
        # 메서드와 경로 추출
        method=$(echo "$line" | grep -oE "(GET|POST|PUT|DELETE)" | head -1)
        path=$(echo "$line" | grep -oE '"[^"]*"' | tr -d '"' | head -1)
        
        # 응답 코드 추출
        status=$(echo "$line" | grep -oE "\s[1-5][0-9][0-9]\s" | tr -d ' ' | head -1)
        
        # 응답시간 추출
        response_time=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+(ms|µs)' | head -1)
        
        if [ ! -z "$method" ] && [ ! -z "$path" ] && [ ! -z "$status" ]; then
            # 상태 코드별 이모지
            if [[ "$status" =~ ^2 ]]; then
                status_icon="✅"
            elif [[ "$status" =~ ^4 ]]; then
                status_icon="⚠️"
            elif [[ "$status" =~ ^5 ]]; then
                status_icon="❌"
            else
                status_icon="ℹ️"
            fi
            
            # 세로 형태로 출력
            timestamp=$(date '+%H:%M:%S')
            echo "[$timestamp]"
            echo "$status_icon"
            echo "Method: $method"
            echo "URL: $path"
            echo "RC: $status"
            if [ ! -z "$response_time" ]; then
                # µs를 ms로 변환
                if echo "$response_time" | grep -q "µs"; then
                    us_value=$(echo "$response_time" | grep -oE '[0-9]+\.[0-9]+')
                    ms_value=$(echo "scale=3; $us_value / 1000" | bc -l 2>/dev/null || echo "0.001")
                    echo "RT: ${ms_value}ms"
                else
                    echo "RT: $response_time"
                fi
            fi
            echo "---"
        fi
    fi
}

# 각 서비스 로그를 임시 파일에 저장
stream_to_file() {
    local log_group=$1
    local temp_file=$2
    
    aws logs tail "$log_group" --follow --format short --since 1m | while read line; do
        parsed=$(parse_log "$line")
        if [ ! -z "$parsed" ]; then
            echo "$parsed" >> "$temp_file"
            
            # app.log에도 저장 (색상 코드 제거)
            echo "$parsed" | sed 's/\x1b\[[0-9;]*m//g' >> "$APP_LOG"
            
            # 파일 크기 제한 (최근 50줄만 유지 - 세로 형태라 더 많이)
            tail -50 "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"
            
            # app.log 크기 제한 (최근 1000줄만 유지)
            tail -1000 "$APP_LOG" > "${APP_LOG}.new" 2>/dev/null && mv "${APP_LOG}.new" "$APP_LOG"
        fi
    done
}

# 화면 출력 함수
display_columns() {
    while true; do
        clear
        print_header
        
        # 각 파일에서 최근 로그를 배열로 읽기
        mapfile -t user_lines < <(tail -30 "$USER_TEMP" 2>/dev/null)
        mapfile -t product_lines < <(tail -30 "$PRODUCT_TEMP" 2>/dev/null)
        mapfile -t stress_lines < <(tail -30 "$STRESS_TEMP" 2>/dev/null)
        
        # 최대 줄 수 계산
        max_lines=$(( ${#user_lines[@]} > ${#product_lines[@]} ? ${#user_lines[@]} : ${#product_lines[@]} ))
        max_lines=$(( $max_lines > ${#stress_lines[@]} ? $max_lines : ${#stress_lines[@]} ))
        
        # 최대 30줄로 제한
        if [ $max_lines -gt 30 ]; then
            max_lines=30
        fi
        
        # 줄별로 3열 출력
        for i in $(seq 0 $((max_lines-1))); do
            user_line=""
            product_line=""
            stress_line=""
            
            if [ $i -lt ${#user_lines[@]} ]; then
                user_line="${user_lines[$i]}"
            fi
            if [ $i -lt ${#product_lines[@]} ]; then
                product_line="${product_lines[$i]}"
            fi
            if [ $i -lt ${#stress_lines[@]} ]; then
                stress_line="${stress_lines[$i]}"
            fi
            
            # 각 열의 폭에 맞게 자르기
            user_display=$(echo "$user_line" | cut -c1-$((COL_WIDTH-2)))
            product_display=$(echo "$product_line" | cut -c1-$((COL_WIDTH-2)))
            stress_display=$(echo "$stress_line" | cut -c1-$((COL_WIDTH-2)))
            
            printf "${GREEN}%-${COL_WIDTH}s${BLUE}%-${COL_WIDTH}s${RED}%-${COL_WIDTH}s${NC}\n" \
                "$user_display" "$product_display" "$stress_display"
        done
        
        sleep 0.5
    done
}

# 정리 함수
cleanup() {
    echo -e "\n🛑 깔끔한 로그 스트리밍 종료"
    kill $USER_PID $PRODUCT_PID $STRESS_PID $DISPLAY_PID 2>/dev/null
    rm -f "$USER_TEMP" "$PRODUCT_TEMP" "$STRESS_TEMP"
    exit
}

# 시그널 처리
trap cleanup INT

echo "🚀 세로형 3열 로그 스트리밍 시작"
echo "📋 형태: [시간] 이모지 Method/URL/RC/RT"
echo "⏹️  종료: Ctrl+C"
sleep 2

# 백그라운드에서 각 서비스 로그 수집
stream_to_file "$USER_LOG" "$USER_TEMP" &
USER_PID=$!

stream_to_file "$PRODUCT_LOG" "$PRODUCT_TEMP" &
PRODUCT_PID=$!

stream_to_file "$STRESS_LOG" "$STRESS_TEMP" &
STRESS_PID=$!

# 화면 출력 시작
display_columns &
DISPLAY_PID=$!

# 메인 프로세스 대기
wait