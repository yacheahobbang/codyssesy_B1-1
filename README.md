# 🛡️ Linux Server Security & Monitoring Automation

## 1. 미션 개요 및 개발 환경
*   **목적:** 다중 사용자 환경에서의 권한 관리/네트워크 보안 설정 및 시스템 리소스/로그 관제 자동화
*   **Host OS:** macOS
*   **Virtualization:** OrbStack
*   **Guest OS:** Ubuntu 22.04 LTS (`my-server`, IP: 192.168.139.188)
*   **Language & Shell:** Python 3, Bash Script

---

## 2. 요구사항 수행 내역 (설정 및 명령어 기록)

### Step 0: 서버 초기 구축 (OrbStack)
```bash
# Ubuntu 22.04 서버 생성 및 접속
orb create ubuntu:22.04 my-server
orb -m my-server

# 계정 비밀번호 설정 및 IP 확인
sudo passwd kangoss40272
ip a
```

### Step 1: 기본 보안 및 방화벽 설정
기본 SSH 포트를 변경하여 무차별 대입 공격을 방지하고, 보안 강화를 위해 최고 관리자(Root)의 원격 접속을 원천 차단했습니다.

**[설정 명령어]**
```bash
# SSH 포트 변경 및 Root 접속 차단
sudo nano /etc/ssh/sshd_config
# [수정 내역] 
# Port 22 -> Port 20022
# PermitRootLogin prohibit-password -> PermitRootLogin no
# PasswordAuthentication no -> PasswordAuthentication yes (원격 테스트용)

# SSH 서비스 재시작하여 설정 적용
sudo systemctl restart sshd

kangoss40272@my-server:~$ sudo grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config
Port 20022
PermitRootLogin no
kangoss40272@my-server:~$ sudo ss -tulnp | grep sshd
tcp   LISTEN 0      128                 0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=2988,fd=3))            
tcp   LISTEN 0      128                    [::]:20022         [::]:*    users:(("sshd",pid=2988,fd=4))