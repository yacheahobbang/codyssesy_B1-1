# 🛡️ Linux Server Security & Monitoring Automation

> Ubuntu 서버 환경에서 SSH 보안 강화, 방화벽 구성, 사용자 권한 관리 및 로그 디렉토리 접근 제어를 자동화한 프로젝트입니다.

---

# 📌 Project Overview

| 항목 | 내용 |
|---|---|
| **목적** | 다중 사용자 환경에서의 권한 관리 및 네트워크 보안 구성 자동화 |
| **Host OS** | macOS |
| **Virtualization** | OrbStack |
| **Guest OS** | Ubuntu 22.04 LTS |
| **Server Name** | `my-server` |
| **Server IP** | `192.168.139.188` |
| **Language** | Python 3, Bash Script |

---

# ⚙️ 1. Server Initialization (OrbStack)

## Ubuntu 서버 생성 및 접속

```bash
# Ubuntu 22.04 서버 생성
orb create ubuntu:22.04 my-server

# 서버 접속
orb -m my-server
```

## 계정 비밀번호 설정 및 IP 확인

```bash
# 계정 비밀번호 설정
sudo passwd kangoss40272

# 서버 IP 확인
ip a
```

---

# 🔐 2. SSH Security Hardening

기본 SSH 포트를 변경하여 무차별 대입 공격(Brute Force Attack)을 완화하고, Root 계정의 원격 접속을 차단하여 보안을 강화했습니다.

---

## SSH 설정 변경

```bash
sudo nano /etc/ssh/sshd_config
```

### 변경 내용

```conf
# 기본 포트 변경
Port 20022

# Root 원격 로그인 차단
PermitRootLogin no

# 테스트를 위한 비밀번호 인증 허용
PasswordAuthentication yes
```

---

## SSH 서비스 재시작

```bash
sudo systemctl restart sshd
```

---

## 설정 검증

### SSH 설정 확인

```bash
sudo grep -E "^Port|^PermitRootLogin" /etc/ssh/sshd_config
```

### 결과

```bash
Port 20022
PermitRootLogin no
```

---

### SSH Listening Port 확인

```bash
sudo ss -tulnp | grep sshd
```

### 결과

```bash
tcp   LISTEN 0      128      0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=2988,fd=3))
tcp   LISTEN 0      128         [::]:20022         [::]:*    users:(("sshd",pid=2988,fd=4))
```

---

# 🔥 3. Firewall Configuration (UFW)

기본적으로 모든 접근을 차단하고, 필요한 서비스 포트만 허용하도록 설정했습니다.

| 포트 | 용도 |
|---|---|
| `20022/tcp` | SSH |
| `15034/tcp` | Application |

---

## UFW 규칙 설정

```bash
# SSH 포트 허용
sudo ufw allow 20022/tcp

# Application 포트 허용
sudo ufw allow 15034/tcp

# 방화벽 활성화
sudo ufw enable
```

---

## 방화벽 상태 확인

```bash
sudo ufw status
```

### 결과

```bash
Status: active

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW       Anywhere
15034/tcp                  ALLOW       Anywhere
20022/tcp (v6)             ALLOW       Anywhere (v6)
15034/tcp (v6)             ALLOW       Anywhere (v6)
```

---

# 👥 4. User & Permission Management

협업 환경을 고려하여 그룹 기반 권한 제어(Role-Based Access Control)를 구성했습니다.

---

## 그룹 및 사용자 생성

```bash
# 그룹 생성
sudo groupadd agent-common
sudo groupadd agent-core

# 사용자 생성
sudo useradd -m -G agent-common,agent-core agent-admin
sudo useradd -m -G agent-common,agent-core agent-dev
sudo useradd -m -G agent-common agent-test
```

---

## 디렉토리 생성 및 권한 설정

```bash
# 디렉토리 생성
sudo mkdir -p /home/agent-app/upload_files
sudo mkdir -p /home/agent-app/api_keys
sudo mkdir -p /var/log/agent-app

# 그룹 소유권 설정
sudo chown :agent-common /home/agent-app/upload_files
sudo chown :agent-core /home/agent-app/api_keys
sudo chown :agent-core /var/log/agent-app

# 권한 설정
sudo chmod 770 /home/agent-app/upload_files
sudo chmod 770 /home/agent-app/api_keys
sudo chmod 770 /var/log/agent-app
```

---

# ✅ 5. Permission Validation

설정된 사용자 그룹 및 디렉토리 권한이 의도한 정책과 일치하는지 검증했습니다.

---

## 사용자 그룹 확인

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

## 디렉토리 권한 확인

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

# 📂 Permission Policy Summary

| 사용자 | agent-common | agent-core | upload_files | api_keys | log directory |
|---|---|---|---|---|---|
| `agent-admin` | ✅ | ✅ | 접근 가능 | 접근 가능 | 접근 가능 |
| `agent-dev` | ✅ | ✅ | 접근 가능 | 접근 가능 | 접근 가능 |
| `agent-test` | ✅ | ❌ | 접근 가능 | 접근 불가 | 접근 불가 |

---
