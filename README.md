# 🛡️ Linux Server Security & Application Deployment

> Ubuntu 서버 환경에서 SSH 보안 강화, 방화벽 구성, 사용자 권한 관리 및 Python 애플리케이션의 안전한 배포와 실행을 자동화한 프로젝트다.

이 프로젝트는 단순히 애플리케이션을 실행하는 데서 끝나지 않는다.  
SSH 접속 보안, 방화벽 정책, 사용자 권한 분리, 환경 변수 설정, 자동 모니터링, 로그 관리까지 서버 운영에 필요한 기본 흐름을 직접 구성하고 검증하는 데 목적이 있다.

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

## 1. 기본 보안 및 네트워크 설정

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

#포트 리슨 상태 확인
sudo ss -tulnp | grep 20022
tcp   LISTEN 0      4096               0.0.0.0:20022      0.0.0.0:*    users:(("systemd",pid=1,fd=51))          
tcp   LISTEN 0      4096                  [::]:20022         [::]:*    users:(("systemd",pid=1,fd=56))

# 방화벽 규칙 추가
#`ufw`는 Ubuntu에서 방화벽을 쉽게 설정하기 위한 도구
sudo ufw allow 20022/tcp
sudo ufw allow 15034/tcp

# UFW 활성화
sudo ufw --force enable

# 방화벽 설정확인
sudo ufw status
Status: active

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW       Anywhere                  
15034/tcp                  ALLOW       Anywhere                  
20022/tcp (v6)             ALLOW       Anywhere (v6)             
15034/tcp (v6)             ALLOW       Anywhere (v6)             


```
---
## 1-1. SSH 포트 변경과 Root 원격 접속 차단
SSH: 원격 컴퓨테에 안전하게 접속하기 이해 사용하는 암호화된 비밀통로 
기본 SSH 포트인 `22번 포트`를 그대로 사용하면 자동 스캔이나 무차별 대입 공격의 대상이 되기 쉽다.

그래서 SSH 포트를 `20022`로 변경했다.  
이는 기본 포트를 노리는 공격 시도를 줄이기 위한 기본 보안 설정이다.

또한 Root 계정은 서버 전체 권한을 가진 관리자 계정이다.  
Root 계정으로 원격 접속을 허용하면 계정이 탈취되었을 때 서버 전체가 위험해질 수 있다.

따라서 `PermitRootLogin no` 설정을 적용하여 Root 원격 접속을 차단했다.  
이 설정은 관리자 권한 탈취 위험을 줄이기 위한 기본 보안 조치다.

---
## 1-2. UFW 방화벽과 필요 포트만 허용하는 정책

서버에서는 모든 포트를 열어두면 안 된다.  
필요하지 않은 포트가 열려 있으면 공격자가 접근할 수 있는 경로가 늘어난다.

본 프로젝트에서는 UFW를 사용하여 필요한 포트만 허용했다.

허용한 포트는 다음과 같다.

| 포트 | 용도 |
|---|---|
| `20022/tcp` | SSH 접속 |
| `15034/tcp` | agent-app 실행 |

즉, SSH 접속에 필요한 포트와 애플리케이션 실행에 필요한 포트만 열고, 나머지 접근은 차단하는 구조다.

이처럼 방화벽은 단순히 켜는 것이 아니라, 어떤 포트를 왜 허용하는지 판단하는 것이 중요하다.

---

## 2. 역할 기반 계정/그룹과 ACL을 통한 권한 분리
## 그룹 및 사용자 생성

```bash
# 그룹 생성
# groupadd: 리눅스 시스템에 새로운 권한 제어용 그룹을 생성하는 명령어
sudo groupadd agent-common
sudo groupadd agent-core

# [사용자 생성 및 그룹 할당]
# useradd 주요 옵션 설명:
#   -m : 사용자의 홈 디렉토리(/home/계정명)를 시스템에 자동으로 생성
#   -s /bin/bash : 계정이 로그인 시 사용할 기본 셸을 가장 범용적인 Bash 셸로 지정
#   -G : 계정을 보조(서브) 그룹에 소속시키는 옵션 (여러 그룹은 쉼표로 구분)
sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-admin
sudo useradd -m -s /bin/bash -G agent-common,agent-core agent-dev
sudo useradd -m -s /bin/bash -G agent-common agent-test
```

---

## 디렉토리 생성 및 권한 설정

```bash
# 디렉토리 생성
# mkdir -p: 상위 디렉토리가 없으면 함께 자동 생성하고, 이미 디렉토리가 존재해도 에러를 발생시키지 않는 옵션
sudo mkdir -p /home/agent-app/{upload_files,api_keys} # 관리 폴더 하위에 공유용, 보안용 디렉토리 동시 생성
sudo mkdir -p /var/log/agent-app                    # 시스템 관제 로그를 독립적으로 보관할 전용 디렉토리 생성p

# 소유 그룹 설정
# chown [소유자]:[소유그룹] : 파일이나 디렉토리의 소유권자와 관리 그룹을 명시적으로 변경하는 명령어
# 시스템 안정성을 위해 주인(소유자)은 root로 고정하고, 소유 그룹만 변경하여 그룹 권한 제어 기반 마련
sudo chown root:agent-common /home/agent-app/upload_files
sudo chown root:agent-core /home/agent-app/api_keys
sudo chown root:agent-core /var/log/agent-app

# 접근 권한 설정
# chmod 770 : 8진수 숫자를 이용해 파일의 삼중 접근 권한(소유자-그룹-기타 사용자)을 통제하는 명령어
#   - 첫 번째 '7' (소유자 권한)   : rwx (읽기, 쓰기, 실행 모두 허용)
#   - 두 번째 '7' (소유그룹 권한) : rwx (지정된 그룹원 전체에게 읽기, 쓰기, 실행 모두 허용)
#   - 세 번째 '0' (기타 사용자 권한) : --- (그룹에 속하지 않은 일반 외인은 읽기조차 불가능하게 전면 차단)
sudo chmod 770 /home/agent-app/upload_files
sudo chmod 770 /home/agent-app/api_keys
sudo chmod 770 /var/log/agent-app
```

---
## 사용자 역할

| 사용자 | 그룹 | 역할 |
|---|---|---|
| `agent-admin` | `agent-common`, `agent-core` | 앱 실행 및 핵심 파일 관리 |
| `agent-dev` | `agent-common`, `agent-core` | 개발 및 보안 파일 접근 |
| `agent-test` | `agent-common` | 일반 테스트 및 공유 파일 접근 |

`agent-test`는 `agent-core`에 포함되지 않는다.  
따라서 API Key나 로그 디렉토리 같은 보안 영역에는 접근할 수 없다.

---

## 권한 설정 설명

`upload_files`는 공유 파일을 저장하는 디렉토리다.  
따라서 `agent-common` 그룹이 접근할 수 있게 설정했다.

`api_keys`는 인증 키를 저장하는 보안 디렉토리다.  
따라서 `agent-core` 그룹만 접근할 수 있게 설정했다.

`/var/log/agent-app`는 로그 저장 디렉토리다.  
로그에는 실행 정보와 오류 정보가 포함될 수 있으므로 `agent-core` 그룹만 접근하도록 제한했다.

`chmod 770`은 소유자와 그룹에게만 모든 권한을 주고, 기타 사용자는 접근하지 못하게 하는 설정이다.

---

## 사용자 그룹 검증

```bash
id agent-admin
id agent-dev
id agent-test
```

### 결과

```bash
# uid: 시스템이 인식하는 유저 고유 ID / groups: 해당 사용자가 현재 발을 걸치고 있는 모든 권한 그룹 목록
uid=1000(agent-admin) groups=1000(agent-common),1002(agent-core)
uid=1001(agent-dev)   groups=1000(agent-common),1002(agent-core)
uid=1002(agent-test)  groups=1000(agent-common)
```

이 결과를 통해 각 사용자가 의도한 그룹에 포함되었음을 확인했다.

---

## 디렉토리 권한 검증

```bash
ls -ld /home/agent-app/upload_files
ls -ld /home/agent-app/api_keys
ls -ld /var/log/agent-app
```

### 결과

```bash
# drwxrwx--- 구조: [d]=디렉토리 / [rwx]=소유자(root)권한 풀림 / [rwx]=소유그룹 권한 풀림 / [---]=외부인 권한 완전 폐쇄
drwxrwx--- 1 root agent-common 0 May 15 09:50 /home/agent-app/upload_files
drwxrwx--- 1 root agent-core   0 May 15 09:50 /home/agent-app/api_keys
drwxrwx--- 1 root agent-core   0 May 15 09:50 /var/log/agent-app
```

이 결과를 통해 공유 디렉토리와 보안 디렉토리가 그룹별로 분리되었음을 확인했다.

---

## ACL 권한 확인 (getfacl)

ACL은 디렉토리 권한을 더 자세히 확인하는 기능이다.  
`getfacl` 명령어를 사용하면 소유자, 그룹, 기타 사용자 권한을 명확히 볼 수 있다.
file: 분석 대상 디렉토리 실제 경로
owner: 최상위 소유 권한자
group: 접근 권한을 위임받은 관리 대상 소유 그룹

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
## 2-1. 역할 기반 계정/그룹과 ACL을 통해 “공유 디렉토리”와 “보안 디렉토리”를 분리하는 이유

다중 사용자 환경에서는 모든 사용자에게 같은 권한을 주면 안 된다. 모든 사용자에게 동일한 수준의 권한을 부여하는 건 자원 오용 및 보안 취약점 노출의 원인이 된다.   
사용자 역할에 따라 접근할 수 있는 디렉토리와 파일을 분리해야 한다.

본 프로젝트에서는 다음 그룹을 사용했다.

| 그룹 | 역할 |
|---|---|
| `agent-common` | 공유 파일 접근 |
| `agent-core` | API Key, 로그 등 보안 파일 접근 |

공유 디렉토리와 보안 디렉토리는 다음과 같이 나누었다.

| 디렉토리 | 목적 | 접근 그룹 |
|---|---|---|
| `/home/agent-app/upload_files` | 공유 파일 저장 | `agent-common` |
| `/home/agent-app/api_keys` | API Key 저장 | `agent-core` |
| `/var/log/agent-app` | 로그 저장 | `agent-core` |

`upload_files`는 일반 공유용 디렉토리다.  
반면 `api_keys`와 로그 디렉토리는 민감한 정보가 포함될 수 있으므로 핵심 그룹만 접근하도록 제한했다.

이 구조를 사용하면 일반 사용자와 관리자 사용자의 권한을 분리할 수 있다. 
일반 권한을 가진 계정이 외부 공격자에게 탈취되거나 내부 직원의 작업 실수가 발생하더라도, 보안 디렉토리를 격리되어 있어 시스템 전체로 피해가 확산되는 것을 방지한다.

---

## 3-4. 환경 변수로 실행 환경 고정

애플리케이션 실행에는 경로, 포트, 업로드 디렉토리, 키 파일 위치, 로그 위치가 필요하다.  
이 값을 코드에 직접 넣으면 환경이 바뀔 때마다 코드를 수정해야 한다.

그래서 본 프로젝트에서는 환경 변수를 사용했다.

| 환경 변수 | 의미 |
|---|---|
| `AGENT_HOME` | 애플리케이션 기본 경로 |
| `AGENT_PORT` | 실행 포트 |
| `AGENT_UPLOAD_DIR` | 업로드 파일 경로 |
| `AGENT_KEY_PATH` | API Key 파일 경로 |
| `AGENT_LOG_DIR` | 로그 저장 경로 |

환경 변수를 사용하면 실행 환경을 명확하게 고정할 수 있다.  
또한 서버 환경이 바뀌어도 환경 변수만 수정하면 애플리케이션을 다시 실행할 수 있다.

애플리케이션 실행 시 Boot Sequence에서 환경 변수, 파일, 포트, 로그 권한을 확인했다.  
이를 통해 실행 환경이 올바르게 구성되었는지 검증했다.

---

## 3-5. 쉘 스크립트를 이용한 상태 수집과 로그 기록

서버 운영 중에는 애플리케이션이 정상 실행 중인지 계속 확인해야 한다.  
또한 CPU, 메모리, 디스크 사용량도 함께 확인해야 한다.

본 프로젝트에서는 `monitor.sh`를 작성하여 다음 정보를 수집했다.

- 프로세스 실행 상태
- 포트 LISTEN 상태
- CPU 사용률
- Memory 사용률
- Disk 사용률
- 경고 로그

수집한 정보는 `/var/log/agent-app/monitor.log`에 저장했다.  
로그를 남기면 문제가 발생했을 때 언제 어떤 상태였는지 확인할 수 있다.

즉, 쉘 스크립트는 서버 상태를 자동으로 점검하고, 로그는 운영 문제를 추적하기 위한 기록이다.

---

## 3-6. crontab 자동 실행과 로그 보존 정책

모니터링은 한 번 실행하는 것으로 끝나면 안 된다.  
서버 상태는 계속 변하기 때문에 주기적으로 확인해야 한다.

본 프로젝트에서는 crontab을 사용하여 `monitor.sh`를 1분마다 자동 실행했다.

```cron
* * * * * /home/agent-app/bin/monitor.sh
```

이를 통해 사용자가 직접 실행하지 않아도 서버 상태가 계속 기록된다.

또한 로그는 계속 쌓이면 파일 크기가 커진다.  
로그가 너무 커지면 디스크 공간을 차지하고, 필요한 내용을 찾기 어려워진다.

그래서 로그 파일이 일정 크기를 넘으면 백업하고, 오래된 로그를 정리하는 정책이 필요하다.  
본 프로젝트에서는 로그 파일 10MB 초과 시 자동 백업하고 최대 10개까지 순환 저장하도록 구성했다.

---

# 🚨 Trouble Shooting: OS Version Compatibility & Migration

초기 환경 구성 중 제공된 바이너리 애플리케이션(`agent-app`) 실행 시 라이브러리 의존성 문제가 발생했다.

## Error Log

```plaintext
/lib/x86_64-linux-gnu/libm.so.6: version `GLIBC_2.38' not found (required by libpython3.12.so.1.0)
```

---

## Root Cause & Resolution

### 원인

제공된 애플리케이션이 Ubuntu 24.04 환경(GLIBC 2.38 기반)에서 빌드되었으나, 초기 테스트 서버는 Ubuntu 22.04(GLIBC 2.35) 환경으로 구성되어 있어 하위 호환성 문제가 발생했다.

즉, 애플리케이션이 요구하는 GLIBC 버전과 서버에 설치된 GLIBC 버전이 맞지 않았다.

### 해결

시스템 안정성을 위해 기존 서버의 `libc`를 강제 업데이트하지 않고, OrbStack을 활용하여 Ubuntu 24.04 LTS 기반의 신규 서버(`my-new-server`)를 구축한 뒤 환경을 마이그레이션하여 문제를 해결했다.

`libc`는 시스템 핵심 라이브러리이므로 강제 업데이트하면 다른 프로그램에 문제가 생길 수 있다.  
따라서 OS 버전을 맞추는 방식이 더 안전하다고 판단했다.

---

# ⚙️ 1. Server Initialization & Security Hardening

OrbStack 초경량 Ubuntu 이미지 환경에 필수 패키지를 설치하고 SSH 및 UFW 보안을 강화했다.

이 단계의 목적은 서버에 원격 접속할 수 있는 기본 환경을 만들고, 동시에 불필요한 외부 접근을 줄이는 것이다.

---


# 👥 2. User & Permission Management

협업 환경 및 최소 권한 원칙(Least Privilege)을 고려하여 그룹 기반 접근 제어(RBAC)를 구성했다.

최소 권한 원칙이란 사용자에게 필요한 권한만 부여하는 것이다.  
이 원칙을 적용하면 실수나 공격이 발생했을 때 피해 범위를 줄일 수 있다.

---



# 📦 3. Application Deployment & Configuration

로컬 macOS 환경에서 Ubuntu 서버로 애플리케이션을 안전하게 배포하고 실행 환경을 구성했다.

이 단계에서는 애플리케이션 파일을 서버로 옮기고, 실행 권한을 부여하고, API Key를 생성하고, 실행에 필요한 디렉토리 권한을 정리했다.

---

## 보안 파일 전송 (SCP)

새롭게 변경된 SSH 포트(`20022`)와 레거시 프로토콜(`-O`) 옵션을 사용하여 애플리케이션을 안전하게 전송했다.

```bash
# Host(macOS) -> Guest(Ubuntu)
scp -O -P 20022 /Users/kangoss40272/Downloads/agent-app.zip kangoss40272@192.168.139.21:~/
```

`-P 20022`는 변경된 SSH 포트를 사용하기 위한 옵션이다.  
`-O`는 레거시 SCP 방식을 사용하기 위한 옵션이다.

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

## 배포 설명

`chmod +x`는 실행 권한을 부여하는 명령어다.  
이 권한이 없으면 파일이 있어도 프로그램으로 실행할 수 없다.

API Key는 `/home/agent-app/api_keys`에 저장했다.  
이 디렉토리는 보안 디렉토리이므로 일반 사용자가 접근하지 못한다.

`chown -R agent-admin:agent-common /home/agent-app`는 애플리케이션 디렉토리의 소유자와 그룹을 설정하는 명령어다.  
이를 통해 서비스 계정이 앱을 실행할 수 있도록 구성했다.

---

# ✅ 4. Execution & Validation

Root 계정이 아닌 서비스 계정(`agent-admin`)을 사용하여 애플리케이션을 안전하게 실행했다.

Root로 앱을 실행하면 앱에 문제가 생겼을 때 서버 전체 권한이 위험해질 수 있다.  
따라서 필요한 권한만 가진 서비스 계정으로 실행하는 것이 안전하다.

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

## 환경 변수 설명

| 환경 변수 | 설명 |
|---|---|
| `AGENT_HOME` | 앱 기본 경로 |
| `AGENT_PORT` | 앱 실행 포트 |
| `AGENT_UPLOAD_DIR` | 업로드 파일 경로 |
| `AGENT_KEY_PATH` | 인증 키 파일 경로 |
| `AGENT_LOG_DIR` | 로그 저장 경로 |

환경 변수를 사용하면 실행 환경을 코드와 분리할 수 있다.  
따라서 경로나 포트가 바뀌어도 코드 수정 없이 환경 변수만 바꾸면 된다.

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

## 실행 검증 설명

Boot Sequence는 앱 실행 전에 필요한 조건을 확인하는 과정이다.

위 로그를 통해 다음 내용을 확인했다.

- `agent-admin` 계정으로 실행됨
- 환경 변수가 정상 설정됨
- secret key 파일이 정상 확인됨
- `15034` 포트 사용 가능
- 로그 디렉토리에 쓰기 가능

따라서 앱이 정상 실행 조건을 만족했음을 확인했다.

---

## 📊 Mission 4. Automated Monitoring Script (monitor.sh)

시스템 자원과 애플리케이션 상태를 1분 단위로 기록하는 자동 관제 시스템을 구축했다.

모니터링은 운영 중인 서버의 상태를 계속 확인하기 위한 과정이다.  
문제가 생겼을 때 로그를 통해 원인을 추적할 수 있다.

---

### 주요 기능

#### ✅ Health Check

- PID 기반 프로세스 상태 확인
- LISTEN 포트 점검
- 비정상 상태 시 로그 기록 중단 및 종료

Health Check는 애플리케이션이 실제로 실행 중인지 확인하는 과정이다.  
프로세스가 없거나 포트가 열려 있지 않으면 정상 서비스 상태가 아니라고 판단한다.

#### ✅ Resource Monitoring

- CPU 사용률 수집
- Memory 사용률 수집
- Disk 사용률 수집
- 임계치 초과 시 `[WARNING]` 로그 출력

리소스 모니터링은 서버 부하를 확인하기 위한 과정이다.  
CPU, 메모리, 디스크 사용량이 높으면 성능 저하나 장애가 발생할 수 있다.

#### ✅ Log Rotation

- 로그 파일 10MB 초과 시 자동 백업
- 최대 10개 순환 저장

로그는 계속 쌓이기 때문에 관리가 필요하다.  
파일이 너무 커지면 디스크 공간을 차지하고 확인도 어려워진다.

따라서 일정 크기를 넘으면 백업하고, 오래된 로그는 정리하는 로그 보존 정책이 필요하다.

#### ✅ Automation

- Crontab 기반 1분 주기 자동 실행

자동 실행을 적용하면 사용자가 직접 명령어를 입력하지 않아도 모니터링이 계속 수행된다.

---

### Cron 등록

```cron
* * * * * /home/agent-app/bin/monitor.sh
```

이 설정은 `monitor.sh`를 매 1분마다 실행한다는 뜻이다.  
따라서 서버 상태가 주기적으로 로그에 기록된다.

---

# ✅ 3. Final Verification (최종 결과)

모든 설정 완료 후 `/var/log/agent-app/monitor.log` 파일에 자원 사용량 및 경고 로그가 정상적으로 누적되는 것을 확인했다.

---

## 실제 구동 로그 예시

```plaintext
[2026-05-15 11:48:01] PID:4812 CPU:100.0% MEM:4.6% DISK_USED:1% [WARNING] CPU > 20%

[2026-05-15 13:32:50] PID:839 CPU:100.0% MEM:5.7% DISK_USED:1% [WARNING] CPU > 20%

[2026-05-15 13:33:01] PID:839 CPU:1.6% MEM:4.3% DISK_USED:1%
```

위 로그를 통해 PID, CPU, Memory, Disk 사용량이 기록되는 것을 확인했다.  
CPU 사용률이 기준치를 넘으면 `[WARNING]` 메시지도 함께 기록된다.

## 최근 로그 조회

```bash
tail -n 5 /var/log/agent-app/monitor.log
```

### 결과

```plaintext
[2026-05-15 13:32:50] PID:839 CPU:100.0% MEM:5.7% DISK_USED:1% [WARNING] CPU > 20%

[2026-05-15 13:33:01] PID:839 CPU:1.6% MEM:4.3% DISK_USED:1%
```

→ 로그 파일 지속 누적 정상 확인

---

## ⏰ Cron 자동 실행 검증

### Cron 등록 확인

```bash
crontab -l
```

### 결과

```cron
* * * * * /home/agent-app/bin/monitor.sh
```

---

### 자동 실행 검증

1분 후 로그 증가 여부 확인:

```bash
tail /var/log/agent-app/monitor.log
```

### 결과

```plaintext
[2026-05-15 13:48:01] PID:839 CPU:1.3% MEM:4.8% DISK_USED:1%
[2026-05-15 13:49:01] PID:839 CPU:1.6% MEM:3.8% DISK_USED:1%
```

→ Cron 기반 1분 주기 자동 모니터링 정상 동작 확인 완료

이 결과를 통해 crontab이 정상 등록되었고, 모니터링 스크립트가 자동으로 실행되고 있음을 확인했다.

---

# 🛠️ 4. Troubleshooting (문제 해결 과정)

프로젝트 수행 중 발생한 주요 에러와 해결 과정이다.

---

## 4-1. GLIBC 버전 호환성 이슈

### 문제

Ubuntu 22.04 환경에서 앱 실행 시 `GLIBC_2.38 not found` 에러 발생.

### 원인

바이너리 빌드 환경과 운영 OS 버전 간 라이브러리 불일치.

### 해결

시스템 안정성을 위해 OS 환경을 Ubuntu 24.04로 마이그레이션하여 해결했다.

---

## 4-2. SSH/SFTP 통신 거부 (SCP)

### 문제

파일 전송 시 `subsystem request failed` 에러 발생.

### 원인

최신 macOS SCP의 SFTP 프로토콜과 서버 SSH 설정 간 충돌.

### 해결

`-O` 옵션을 사용하여 레거시 SCP 프로토콜로 강제 전송했다.

```bash
scp -O -P 20022 ...
```

---

## 4-3. 터미널 버퍼 오버플로우 및 코드 유실

### 문제

긴 Shell Script를 붙여넣을 때 코드 일부가 유실되며 `syntax error` 발생.

### 원인

SSH 세션 내 터미널 버퍼 제한 초과.

### 해결

스크립트를 여러 개의 Chunk로 분할하여 `tee -a` 방식으로 순차 병합했다.

---

## 4-4. Health Check에 의한 로그 생성 중단

### 문제

모니터링 로그가 생성되지 않고 즉시 종료됨.

### 원인

`agent-app` 프로세스 종료로 인해 PID 검사 로직이 `exit 1` 수행.

### 해결

`pgrep`으로 프로세스 상태를 확인 후 `nohup`으로 백그라운드 재실행했다.

---

## 4-5. 권한 제어 시스템 검증

### 문제

일반 사용자 계정에서 로그 파일 접근 시 `Permission denied` 발생.

### 원인 및 결과

로그 디렉토리 권한을 `770`으로 설정하여 비그룹 사용자의 접근을 차단한 결과다.  
이는 오류가 아니라 설계한 보안 정책이 정상 동작한 것이다.

---

# 🧾 Conclusion

본 프로젝트에서는 Ubuntu 24.04 서버 환경에서 `agent-app`을 안전하게 배포하고 실행했다.

SSH 포트를 변경하고 Root 원격 접속을 차단하여 원격 접속 보안을 강화했다.  
UFW 방화벽을 사용하여 SSH 포트와 애플리케이션 포트만 허용했다.

또한 사용자와 그룹을 역할에 따라 나누고, 공유 디렉토리와 보안 디렉토리를 분리했다.  
이를 통해 최소 권한 원칙을 적용했다.

환경 변수를 사용하여 실행 경로, 포트, 업로드 디렉토리, 키 파일 경로, 로그 경로를 고정했다.  
Boot Sequence를 통해 실행 환경이 올바르게 구성되었는지도 확인했다.

마지막으로 `monitor.sh`와 crontab을 사용하여 서버 상태를 1분 단위로 자동 기록했다.  
로그 보존 정책을 통해 로그 파일이 과도하게 커지는 문제도 방지했다.

결과적으로 이 프로젝트는 Linux 서버 보안 설정, 권한 관리, 애플리케이션 배포, 실행 검증, 모니터링 자동화, 로그 관리까지 서버 운영의 기본 흐름을 실습한 프로젝트다.

