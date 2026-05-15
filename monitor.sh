#!/bin/bash

# ==========================================
# 1. 환경 변수 및 설정
# ==========================================
LOG_FILE="/var/log/agent-app/monitor.log"
APP_NAME="agent-app"
PORT="15034"
NOW=$(date +"%Y-%m-%d %H:%M:%S")
WARNINGS=""

# ==========================================
# 2. Health Check (실패 시 즉시 종료)
# ==========================================
# 프로세스 확인: agent-app이 실행 중인지 체크
PID=$(pgrep -x "$APP_NAME" | head -n 1)
if [ -z "$PID" ]; then
    exit 1
fi

# 포트 확인: TCP 15034 포트가 LISTEN 상태인지 체크
if ! ss -tln | grep -q ":$PORT "; then
    exit 1
fi

# ==========================================
# 3. 상태 점검 (경고만 출력)
# ==========================================
# 방화벽(UFW) 활성화 상태 점검
UFW_STATUS=$(grep "^ENABLED=" /etc/ufw/ufw.conf | cut -d= -f2)
if [ "$UFW_STATUS" != "yes" ]; then
    WARNINGS="${WARNINGS}[WARNING] Firewall Inactive "
fi

# ==========================================
# 4. 자원 수집 및 임계값 경고
# ==========================================
# CPU 사용률 (%) - 임계값 20%
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed -E 's/.*, ([0-9.]+) id.*/\1/')
CPU_USAGE=$(awk -v idle="$CPU_IDLE" 'BEGIN {printf "%.1f", 100 - idle}')
if [ $(awk -v cpu="$CPU_USAGE" 'BEGIN {if (cpu > 20) print 1; else print 0}') -eq 1 ]; then
    WARNINGS="${WARNINGS}[WARNING] CPU > 20% "
fi

# 메모리 사용률 (%) - 임계값 10%
MEM_USAGE=$(free | awk '/Mem/ {printf "%.1f", $3/$2 * 100}')
if [ $(awk -v mem="$MEM_USAGE" 'BEGIN {if (mem > 10) print 1; else print 0}') -eq 1 ]; then
    WARNINGS="${WARNINGS}[WARNING] MEM > 10% "
fi

# 디스크 사용률 (Root partition, Used %) - 임계값 80%
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    WARNINGS="${WARNINGS}[WARNING] DISK_USED > 80% "
fi

# ==========================================
# 5. 로그 기록
# ==========================================
# 요구된 포맷: [YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%
LOG_MSG="[$NOW] PID:$PID CPU:${CPU_USAGE}% MEM:${MEM_USAGE}% DISK_USED:${DISK_USAGE}% $WARNINGS"
echo "$LOG_MSG" | sed 's/[[:space:]]*$//' >> "$LOG_FILE"

# ==========================================
# 6. 로그 파일 용량 관리 (10MB 유지, 10개 파일 순환)
# ==========================================
MAX_SIZE=10485760 # 10MB
FILE_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)

if [ "$FILE_SIZE" -ge "$MAX_SIZE" ]; then
    for i in {9..1}; do
        [ -f "${LOG_FILE}.${i}" ] && mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i+1))"
    done
    mv "$LOG_FILE" "${LOG_FILE}.1"
    touch "$LOG_FILE"
    chmod 660 "$LOG_FILE"
fi