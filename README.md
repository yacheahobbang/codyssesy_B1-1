# 🛡️ Linux Server Security & Application Deployment

> Ubuntu 서버 환경에서 SSH 보안 강화, 방화벽 구성, 사용자 권한 관리 및 Python 애플리케이션의 안전한 배포와 실행을 자동화한 프로젝트입니다.

---

# 📌 Project Overview

| 항목 | 내용 |
|---|---|
| **목적** | 다중 사용자 환경에서의 권한 관리, 네트워크 보안 구성 및 앱 배포 자동화 |
| **Host OS** | macOS |
| **Virtualization** | OrbStack |
| **Guest OS** | Ubuntu 24.04 LTS (Noble Numbat) |
| **Server Name** | `my-new-server` |
| **Server IP** | `192.168.139.21` |
| **Target Application** | `agent-app` (Python 3.12 Binary) |

---

# 🚨 Trouble Shooting: OS Version Compatibility & Migration

초기 환경 구성 중 제공된 바이너리 애플리케이션(`agent-app`) 실행 시 라이브러리 의존성 문제가 발생했습니다.

## Error Log

```plaintext
/lib/x86_64-linux-gnu/libm.so.6: version `GLIBC_2.38' not found (required by libpython3.12.so.1.0)
```

---

## Root Cause & Resolution

### 원인

제공된 애플리케이션이 Ubuntu 24.04 환경(GLIBC 2.38 기반)에서 빌드되었으나, 초기 테스트 서버는 Ubuntu 22.04(GLIBC 2.35) 환경으로 구성되어 있어 하위 호환성 문제가 발생했습니다.

### 해결

시스템 안정성을 위해 기존 서버의 `libc`를 강제 업데이트하지 않고, OrbStack을 활용하여 Ubuntu 24.04 LTS 기반의 신규 서버(`my-new-server`)를 구축한 뒤 환경을 마이그레이션하여 문제를 해결했습니다.

---

# ⚙️ 1. Server Initialization & Security Hardening

OrbStack 초경량 Ubuntu 이미지 환경에 필수 패키지를 설치하고 SSH 및 UFW 보안을 강화했습니다.

---

## 필수 패키지 설치 및 SSH/UFW 설정

```bash
# 필수 패키지 설치
sudo apt update && sudo apt install openssh-server ufw -y

# SSH 설정 변경
sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# SSH 포트 변경
echo "Port 20022" | sudo tee -a /etc/ssh/sshd_config

# SSH 서비스 재시작
sudo systemctl restart ssh

# 방화벽 규칙 추가
sudo ufw allow 20022/tcp
sudo ufw allow 15034/tcp

# UFW 활성화
sudo ufw --force enable
```

---

# 👥 2. User & Permission Management

협업 환경 및 최소 권한 원칙(Least Privilege)을 고려하여 그룹 기반 접근 제어(RBAC)를 구성했습니다.

---

## 그룹 및 사용자 생성

```bash
# 그룹 생성
sudo groupadd agent-common
sudo groupadd agent-core

# 사용자 생성
sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-admin
sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-dev
sudo useradd -m -s /bin/bash -G agent-common agent-test
```

---

## 디렉토리 생성 및 권한 설정

```bash
# 디렉토리 생성
sudo mkdir -p /home/agent-app/{upload_files,api_keys}
sudo mkdir -p /var/log/agent-app

# 소유 그룹 설정
sudo chown root:agent-common /home/agent-app/upload_files
sudo chown root:agent-core /home/agent-app/api_keys
sudo chown root:agent-core /var/log/agent-app

# 접근 권한 설정
sudo chmod 770 /home/agent-app/upload_files
sudo chmod 770 /home/agent-app/api_keys
sudo chmod 770 /var/log/agent-app
```

---

## 사용자 그룹 검증

```bash
id agent-admin
id agent-dev
id agent-test
```

### 결과

```bash
uid=1000(agent-admin) groups=1000(agent-common),1002(agent-core)
uid=1001(agent-dev)   groups=1000(agent-common),1002(agent-core)
uid=1002(agent-test)  groups=1000(agent-common)
```

---

## 디렉토리 권한 검증

```bash
ls -ld /home/agent-app/upload_files
ls -ld /home/agent-app/api_keys
ls -ld /var/log/agent-app
```

### 결과

```bash
drwxrwx--- 1 root agent-common 0 May 15 09:50 /home/agent-app/upload_files
drwxrwx--- 1 root agent-core   0 May 15 09:50 /home/agent-app/api_keys
drwxrwx--- 1 root agent-core   0 May 15 09:50 /var/log/agent-app
```

---

## ACL 권한 확인 (getfacl)

### upload_files ACL 확인

```bash
getfacl /home/agent-app/upload_files
```

#### 결과

```bash
getfacl: Removing leading '/' from absolute path names

# file: home/agent-app/upload_files
# owner: root
# group: agent-common

user::rwx
group::rwx
other::---
```

---

### api_keys ACL 확인

```bash
getfacl /home/agent-app/api_keys
```

#### 결과

```bash
getfacl: Removing leading '/' from absolute path names

# file: home/agent-app/api_keys
# owner: root
# group: agent-core

user::rwx
group::rwx
other::---
```

---

### log directory ACL 확인

```bash
getfacl /var/log/agent-app
```

#### 결과

```bash
getfacl: Removing leading '/' from absolute path names

# file: var/log/agent-app
# owner: root
# group: agent-core

user::rwx
group::rwx
other::---
```

---

# 📦 3. Application Deployment & Configuration

로컬 macOS 환경에서 Ubuntu 서버로 애플리케이션을 안전하게 배포하고 실행 환경을 구성했습니다.

---

## 보안 파일 전송 (SCP)

새롭게 변경된 SSH 포트(`20022`)와 레거시 프로토콜(`-O`) 옵션을 사용하여 애플리케이션을 안전하게 전송했습니다.

```bash
# Host(macOS) -> Guest(Ubuntu)
scp -O -P 20022 /Users/kangoss40272/Downloads/agent-app.zip kangoss40272@192.168.139.21:~/
```

---

## 애플리케이션 셋팅 및 인증 키 생성

```bash
# unzip 설치 및 압축 해제
sudo apt install unzip -y
unzip ~/agent-app.zip -d ~/

# 애플리케이션 배포
sudo cp ~/agent-app /home/agent-app/
sudo chmod +x /home/agent-app/agent-app

# API Key 생성
sudo -u agent-admin bash -c "echo 'agent_api_key_test' > /home/agent-app/api_keys/t_secret.key"

# 최종 소유권 설정
sudo chown -R agent-admin:agent-common /home/agent-app
```

---

# ✅ 4. Execution & Validation

Root 계정이 아닌 서비스 계정(`agent-admin`)을 사용하여 애플리케이션을 안전하게 실행했습니다.

---

## 환경 변수 설정 및 애플리케이션 실행

```bash
# 서비스 계정 전환
sudo su - agent-admin

# 환경 변수 설정
export AGENT_HOME=/home/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app

# 애플리케이션 실행
cd $AGENT_HOME
./agent-app
```

---

## Boot Sequence 성공 로그

```plaintext
>>> Starting Agent Boot Sequence...

[1/5] Checking User Account               [OK]
 ... Running as service user 'agent-admin' (uid=1000)

[2/5] Verifying Environment Variables     [OK]
 ... All required Envs correct

[3/5] Checking Required Files             [OK]
 ... Verified 'secret.key' with correct key string.

[4/5] Checking Port Availability          [OK]
 ... Port 15034 is available.

[5/5] Verifying Log Permission            [OK]
 ... Log directory is writable: /var/log/agent-app

------------------------------------------------------------

All Boot Checks Passed!
Agent READY

2026-05-15 11:23:09,325 [INFO] Agent listening at port 15034
2026-05-15 11:23:09,325 [INFO] === Agent Started. Beginning resource cycle. ===
```

---

# 📂 Permission Policy Summary

| 사용자 | agent-common | agent-core | upload_files | api_keys | log directory |
|---|---|---|---|---|---|
| `agent-admin` | ✅ | ✅ | 접근 가능 | 접근 가능 | 접근 가능 |
| `agent-dev` | ✅ | ✅ | 접근 가능 | 접근 가능 | 접근 가능 |
| `agent-test` | ✅ | ❌ | 접근 가능 | 접근 불가 | 접근 불가 |

---

# 🛠️ Security Features Summary

- ✅ SSH 기본 포트 변경 (`22 → 20022`)
- ✅ Root 원격 로그인 차단
- ✅ UFW 기반 최소 포트 허용 정책 적용
- ✅ 그룹 기반 접근 제어(RBAC) 구성
- ✅ 민감 디렉토리 접근 제한 (`770`)
- ✅ ACL 기반 권한 검증 수행
- ✅ Root 계정이 아닌 서비스 계정으로 앱 실행
- ✅ Python 애플리케이션 안전 배포 및 실행 환경 구성

---

# 🚀 Future Improvements

- Fail2Ban 기반 SSH 공격 탐지 및 자동 차단
- SSH Key 기반 인증 전환
- Systemd 서비스 등록 자동화
- 시스템 리소스 모니터링 자동화
- 로그 분석 및 알림 시스템 구축
- Docker 기반 서비스 격리 환경 구성

