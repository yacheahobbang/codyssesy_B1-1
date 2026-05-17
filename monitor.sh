#!/bin/bash
# =========================================================================
# 시스템 관제 자동화 및 자원 덤프 스크립트 (monitor.sh)
# 명세 수립: 소유자(agent-dev), 소유그룹(agent-core), 접근권한(750)
# =========================================================================

# 인프라 고정 경로 정의
LOG_FILE="/var/log/agent-app/monitor.log"
MAX_SIZE=10485760  # 과제 제한 용량 스펙: 10MB (Byte 단위 환산)
MAX_FILES=10       # 최대 보존 로그 파일 개수

# -------------------------------------------------------------------------
# [기능 1] 로그 파일 용량 관리 구조 (자체 Script 내장형 Log Rotation)
# -------------------------------------------------------------------------
if [ -f "$LOG_FILE" ]; then # 로그 파일이 존재하면
    CURRENT_SIZE=$(stat -c%s "$LOG_FILE") # 현재 로그 파일 크기 바이트 단위로 측정
    if [ "$CURRENT_SIZE" -ge "$MAX_SIZE" ]; then
        # 오래된 로그 파일부터 순차적으로 밀어내기 처리 (10번 소멸, 1~9번 Shift)
        for i in $(seq $((MAX_FILES - 1)) -1 1); do
            if [ -f "$LOG_FILE.$i" ]; then
                mv "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))"
            fi
        done
        mv "$LOG_FILE" "$LOG_FILE.1"
        touch "$LOG_FILE"
        chmod 660 "$LOG_FILE"
    fi
fi

# -------------------------------------------------------------------------
# [기능 2] Health Check 단일 검증문 (이상이 감지되면 즉시 에러코드 exit 1 선언)
# -------------------------------------------------------------------------
# A. 애플리케이션 바이너리 프로세스 작동 현황 추적
PID=$(pgrep -x "agent-app") # agent-app 프로세스 이름으로 PID 추출
if [ -z "$PID" ]; then #프로세스가 죽어서 PID가 조회되지 않는다면 에러 로그를 남기고 exit 1로 스크립트를 강제 종료
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Health Check Failed: agent-app process dead." >> "$LOG_FILE"
    exit 1
fi

# B. 대외 서비스 TCP 15034번 포트 리슨 상태 물리 추적
if ! ss -tln | grep -q ":15034 "; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Health Check Failed: Port 15034 is down." >> "$LOG_FILE"
    exit 1
fi

# -------------------------------------------------------------------------
# [기능 3] 핵심 시스템 내부 자원 정보 수집 (CPU, MEM, DISK)
# -------------------------------------------------------------------------
# 상위 토탈 연산값을 구한 뒤 유휴(idle) 수치를 빼서 정밀한 실시간 CPU 연산율 산출
CPU_USAGE=$(top -bn1 | grep '%Cpu(s)' | awk '{print 100 - $8}')
# 가용 메모리 대비 실제 활성화된 메모리 비율 추출
MEM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
# 최상위 루트 파티션(/)의 순수 디스크 사용 점유 퍼센트 파싱
DISK_USED=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

# -------------------------------------------------------------------------
# [기능 4] 방화벽 활성화 상태 및 리소스 임계치 예외 제어 (Warning 오버레이)
# -------------------------------------------------------------------------
WARNING_MSG=""

# A. 방화벽 상태 체크 (비활성 시 경고하되 스크립트 중단은 유예)
if ! systemctl is-active --quiet ufw; then
    WARNING_MSG="${WARNING_MSG} [WARNING] Firewall(UFW) is inactive."
fi

# B. 리소스 오버 스펙 경고 검사 (정수형 스케일 다운 가공)
CPU_INT=$(printf "%.0f" "$CPU_USAGE")
MEM_INT=$(printf "%.0f" "$MEM_USAGE")

if [ "$CPU_INT" -gt 20 ]; then
    WARNING_MSG="${WARNING_MSG} [WARNING] CPU > 20% (Current: ${CPU_USAGE}%)"
fi

if [ "$MEM_INT" -gt 10 ]; then
    WARNING_MSG="${WARNING_MSG} [WARNING] MEM > 10% (Current: ${MEM_USAGE}%)"
fi

if [ "$DISK_USED" -gt 80 ]; then
    WARNING_MSG="${WARNING_MSG} [WARNING] DISK_USED > 80% (Current: ${DISK_USED}%)"
fi

# -------------------------------------------------------------------------
# [기능 5] 정형화된 정석 규격 포맷 데이터 최종 로그 출력 바인딩
# -------------------------------------------------------------------------
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] PID:$PID CPU:${CPU_USAGE}% MEM:${MEM_USAGE}% DISK_USED:${DISK_USED}%${WARNING_MSG}" >> "$LOG_FILE"