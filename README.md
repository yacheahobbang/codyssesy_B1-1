# Linux Server Security & Application Deployment

> Ubuntu 서버 환경에서 SSH 보안 강화, 방화벽 구성, 사용자 권한 관리 및 Python 애플리케이션의 안전한 배포와 실행을 자동화한 프로젝트다.

이 프로젝트는 단순히 애플리케이션을 실행하는 데서 끝나지 않는다.  
SSH 접속 보안, 방화벽 정책, 사용자 권한 분리, 환경 변수 설정, 자동 모니터링, 로그 관리까지 서버 운영에 필요한 기본 흐름을 직접 구성하고 검증하는 데 목적이 있다.

---

# Project Overview

| 항목 | 내용 |
|---|---|
| **목적** | 다중 사용자 환경에서의 권한 관리, 네트워크 보안 구성 및 앱 배포 자동화 |
| **Host OS** | macOS |
| **Virtualization** | OrbStack |
| **Guest OS** | Ubuntu 24.04 LTS (Noble Numbat) |
| **Server Name** | `my-new-server` |
| **Server IP** | `192.168.139.187` |
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
tcp   LISTEN 0      128                 0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=4268,fd=3))           
tcp   LISTEN 0      128                    [::]:20022         [::]:*    users:(("sshd",pid=4268,fd=4)) 

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

## 2. 계정/그룹/권한 체계(협업 + 최소 권한)
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

## 3. 애플리케이션 실행 환경 구성(제공 Python 앱)

## Root Cause & Resolution

### 원인

제공된 애플리케이션이 Ubuntu 24.04 환경(GLIBC 2.38 기반)에서 빌드되었으나, 초기 테스트 서버는 Ubuntu 22.04(GLIBC 2.35) 환경으로 구성되어 있어 하위 호환성 문제가 발생했다.

즉, 애플리케이션이 요구하는 GLIBC 버전과 서버에 설치된 GLIBC 버전이 맞지 않았다.

### 해결

시스템 안정성을 위해 기존 서버의 `libc`를 강제 업데이트하지 않고, OrbStack을 활용하여 Ubuntu 24.04 LTS 기반의 신규 서버(`my-new-server`)를 구축한 뒤 환경을 마이그레이션하여 문제를 해결했다.

`libc`는 시스템 핵심 라이브러리이므로 강제 업데이트하면 다른 프로그램에 문제가 생길 수 있다.  
따라서 OS 버전을 맞추는 방식이 더 안전하다고 판단했다.

---

## 보안 파일 전송 (SCP)

새롭게 변경된 SSH 포트(`20022`)와 레거시 프로토콜(`-O`) 옵션을 사용하여 애플리케이션을 안전하게 전송했다.

```bash
# Host(macOS) -> Guest(Ubuntu)
scp -O -P 20022 /Users/kangoss40272/Downloads/agent-app.zip kangoss40272@192.168.139.187:~/
```

`-P 20022`는 변경된 SSH 포트를 사용하기 위한 옵션이다.  
`-O`는 레거시 SCP 방식을 사용하기 위한 옵션이다.

---

## 애플리케이션 셋팅 및 인증 키 생성

```bash
# 1. 압축 해제 도구 설치 및 파일 압축 해제
sudo apt install unzip -y
unzip ~/agent-app.zip -d ~/

# 2. 과제 요구사항에 맞춘 AGENT_HOME 디렉토리 생성
sudo mkdir -p /home/agent-app/{upload_files,api_keys}
sudo mkdir -p /var/log/agent-app

# 3. 애플리케이션 파일 이동 및 실행 권한(+x) 부여
sudo cp ~/agent-app /home/agent-app/
sudo chmod +x /home/agent-app/agent-app

# 4. 요구사항에 따른 1줄짜리 텍스트 API Key 생성 (보안 구역 내 저장)
sudo -u agent-admin bash -c "echo 'agent_api_key_test' > /home/agent-app/api_keys/t_secret.key"

# 5. 서비스 계정(agent-admin)이 앱을 구동할 수 있도록 파일 소유권 변경
sudo chown -R agent-admin:agent-common /home/agent-app
```

---
## 애플리케이션 배포 및 권한 설정 과정 요약

과제에서 요구한 **"Python 앱 실행 환경 구성"** 및 **"일반 계정(agent-admin)으로 실행"** 조건을 충족하기 위해 진행한 5단계 작업의 핵심 이유를 정리한 문서입니다.

---

### 📦 1. 압축 해제 (`unzip`)
* macOS(로컬)에서 전송된 파일은 압축 상자(`zip`) 상태. 리눅스 서버가 내부 코드를 인식하고 실행할 수 있도록 내용물을 꺼내는 필수 작업이다.

### 🏗️ 2. 전용 디렉토리 생성 (`mkdir -p`)
*  제공된 Python 앱은 실행되자마자 가이드에 명시된 특정 경로들을 자동 탐색. 해당 폴더들이 없으면 구동 에러가 나며 즉시 종료되므로 미리 바닥 공사를 해둔 것이다.

### 🚚 3. 파일 이동 및 실행 권한 부여 (`cp`, `chmod +x`)
*  리눅스는 보안상 외부에서 들어온 파일을 '실행 불가능한 일반 텍스트' 상태로 락을 걸어둔다. 앱을 공식 경로로 옮긴 뒤, 프로세스로 작동할 수 있게 **실행 스위치(`+x`)**를 켜준 것.

### 🔑 4. 인증 키 생성 (`sudo -u agent-admin ...`)
*  과제 필수 조건인 `t_secret.key` 파일을 생성하는 과정. 앱을 관리할 서비스 계정(`agent-admin`)의 권한을 빌려 보안 구역 내에 올바른 암호문 문자열을 심어두었다.

### 👑 5. 최종 소유권 변경 (`chown -R`) -> 핵심 보안 단계
* 앞선 설정 과정에서 `sudo`를 썼기 때문에 모든 파일의 주인이 최고 관리자인 `root`로 잡혀있다. 이 상태로 두면 과제 조건인 "일반 계정(`agent-admin`)으로 실행"할 때 **권한 거부(Permission Denied)** 에러가 난다. 주방의 최종 소유 명패를 `agent-admin`으로 확실하게 넘겨주는 작업이다.

---

### 💡 인프라 관점의 한 줄 요약
최고 관리자(`root`)의 힘으로 서버에 주방(환경)을 안전하게 인테리어한 뒤, 마지막에 실제 일할 주방장(`agent-admin`)에게 **주방 열쇠(소유권)와 조리법(실행 권한)을 통째로 넘겨주어 안전하게 독립 구동하도록 만드는 정석 프로세스**입니다.
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

## 4. 시스템 관제 자동화 스크립트

## 4-1. 관제 자동화 스크립트 소스 코드 (`monitor.sh`)

*   **배포 경로**: `/home/agent-app/bin/monitor.sh`
*   **소유 구조**: 소유자 `agent-dev` / 관리 그룹 `agent-core`
*   **접근 권한 스키마**: `750 (rwxr-x---)` -> 소유자와 그룹원만 제어 가능, 외부인 차단

1.  **1단계: Health Check (서비스 가용성 검증)**
    *   **프로세스 활성 검사**: `pgrep -x "agent-app"` 명령어를 통해 애플리케이션의 고유 프로세스 ID(PID)가 메모리 상에 살아있는지 실시간으로 추적한다.
    *   **네트워크 소켓 검사**: `ss -tln` 명령어로 대외 서비스 창구인 TCP `15034` 포트가 정상적으로 연결 대기(`LISTEN`) 상태를 유지하고 있는지 검증한다. 두 조건 중 하나라도 충족하지 못하면 비정상 상황으로 판단하여 에러 로그를 남기고 즉시 스크립트를 안전하게 종료(`exit 1`)한다.
2.  **2단계: 인프라 핵심 리소스 수집**
    *   현재 서버의 물리 자원 상태를 파싱한다. `top` 명령어를 스냅샷 형태로 호출하여 유휴(idle) 수치를 제외한 순수 **CPU 사용률**을 계산하고, `free` 명령어로 전체 RAM 대비 **메모리 점유율**을, `df` 명령어로 최상위 루트 파티션(/)의 **디스크 사용 공간** 퍼센트를 동적으로 추출한다.
3.  **3단계: 자원 임계치 판정 (Threshold Check)**
    *   스크립트 내부의 `if` 조건문 제어 구조를 거치며 수집된 자원이 인프라 안전 가이드라인 범위를 벗어났는지 연산한다. (예: CPU > 20%, MEM > 10%, DISK > 80%) 임계값을 초과하는 과부하 징후가 포착되면 로그 라인 끝에 `[WARNING]` 식별자와 세부 지표를 유기적으로 결합(Overlay)한다.
4.  **4단계: 정형화된 시계열 로그 기록 (Logging)**
    *   최종 가공된 자원 데이터 전면에 실시간 날짜 및 시간 데이터(`date '+%Y-%m-%d %H:%M:%S'`)를 꼬리표로 붙여, 한 줄짜리 표준 포맷 문장으로 구성한다. 이후 리눅스 출력 리다이렉션 기호(`>>`)를 사용하여 관제 파일(`monitor.log`) 꼬리칸에 무중단으로 누적 적재한다.

```bash
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
if [ -f "$LOG_FILE" ]; then
    CURRENT_SIZE=$(stat -c%s "$LOG_FILE")
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
PID=$(pgrep -x "agent-app")
if [ -z "$PID" ]; then
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
```
---


## 4-2. 자동 관제 스크립트 핵심 방어 정책 명세

작성된 스크립트 내부 로직은 단순히 자원을 기록하는 목적을 넘어, 과제 설명서의 필수 요구 조건을 완벽히 충족하도록 설계되었다.

| 관제 항목 및 정책 | 세부 구현 로직 내용 설명 |
|---|---|
| **Health Check<br>(실패 시 즉시 종료)** | `pgrep`으로 앱의 데몬 활성 상태를 추적하고 `ss`로 `15034` 포트 점유 여부를 검사한다. 둘 중 하나라도 깨져있다면 정상 서비스가 불가능하므로 에러 로그를 남기고 즉시 `exit 1`로 가동을 중단한다. |
| **상태 점검 및 자원 수집<br>(경고만 출력)** | 방화벽(UFW)이 꺼져있거나, CPU > 20%, MEM > 10%, DISK > 80%를 초과하는 과부하 발생 시 로그 끝에 `[WARNING]` 메시지를 출력하되, 시스템 다운을 막기 위해 스크립트 자체는 종료하지 않고 유지한다. |
| **로그 파일 용량 관리<br>(자체 순환)** | 로그 유출 및 포화로 인한 디스크 고갈을 차단하기 위해 `stat` 명령어로 용량을 상시 계산한다. **10MB 초과 시 자동으로 기존 로그를 백업하고 최대 10개까지만 순환(Rotation)** 보존한다. |
---
1.  **1단계: Health Check (서비스 가용성 검증)**
    *   **프로세스 활성 검사**: `pgrep -x "agent-app"` 명령어를 통해 애플리케이션의 고유 프로세스 ID(PID)가 메모리 상에 살아있는지 실시간으로 추적한다.
    *   **네트워크 소켓 검사**: `ss -tln` 명령어로 대외 서비스 창구인 TCP `15034` 포트가 정상적으로 연결 대기(`LISTEN`) 상태를 유지하고 있는지 검증한다. 두 조건 중 하나라도 충족하지 못하면 비정상 상황으로 판단하여 에러 로그를 남기고 즉시 스크립트를 안전하게 종료(`exit 1`)한다.
2.  **2단계: 인프라 핵심 리소스 수집**
    *   현재 서버의 물리 자원 상태를 파싱한다. `top` 명령어를 스냅샷 형태로 호출하여 유휴(idle) 수치를 제외한 순수 **CPU 사용률**을 계산하고, `free` 명령어로 전체 RAM 대비 **메모리 점유율**을, `df` 명령어로 최상위 루트 파티션(/)의 **디스크 사용 공간** 퍼센트를 동적으로 추출한다.
3.  **3단계: 자원 임계치 판정 (Threshold Check)**
    *   스크립트 내부의 `if` 조건문 제어 구조를 거치며 수집된 자원이 인프라 안전 가이드라인 범위를 벗어났는지 연산한다. (예: CPU > 20%, MEM > 10%, DISK > 80%) 임계값을 초과하는 과부하 징후가 포착되면 로그 라인 끝에 `[WARNING]` 식별자와 세부 지표를 유기적으로 결합(Overlay)한다.
4.  **4단계: 정형화된 시계열 로그 기록 (Logging)**
    *   최종 가공된 자원 데이터 전면에 실시간 날짜 및 시간 데이터(`date '+%Y-%m-%d %H:%M:%S'`)를 꼬리표로 붙여, 한 줄짜리 표준 포맷 문장으로 구성한다. 이후 리눅스 출력 리다이렉션 기호(`>>`)를 사용하여 관제 파일(`monitor.log`) 꼬리칸에 무중단으로 누적 적재한다.

---

### 4-3. 운영 문제 추적(Troubleshooting)에서의 핵심 역할

이러한 쉘 스크립트 관제 흐름은 시스템 운영 중 발생하는 불시의 장애를 해결하는 데 결정적인 역할을 수행한다.

*   **과거 장애 시점의 완벽한 재구성**: 서버가 새벽 시간대나 관리자가 자리를 비운 주말에 갑자기 다운되었을 때, 무작정 서버를 재시작하는 임시방편을 배제할 수 있다. 장애 발생 직전 축적된 시계열 로그의 타임스탬프를 역추적하여 근본 원인을 진단한다.
*   **근본 원인(Root Cause)의 가시적 분석**: `[WARNING] CPU > 20%`가 수 분간 누적되다가 죽었는지, `DISK_USED: 100%`로 스토리지가 완전히 포화되어 프로세스가 크래시(Crash)를 일으켰는지 로그의 실증 지표를 통해 명확히 식별할 수 있다. 결과적으로 정밀한 사후 방지 대책을 수립하고 인프라의 아키텍처적 신뢰성을 고도화하는 핵심 데이터 백서가 된다.
---

## 5. 자동 실행(Cron) 설정 및 관제 결과 검증

### 5-1. 크론 스케줄러 등록 및 자동 구동

```cron
# agent-admin 계정의 crontab 설정 내부 명세
# 분 시 일 월 요일 [실행할 스크립트의 절대 경로]
* * * * * /home/agent-app/bin/monitor.sh
```

#### 💡 크론(Cron) 설정 및 필요성 설명
*   **지속적인 상태 추적**: 서버의 부하량이나 프로세스 헬스 상태는 시시각각 가변적으로 변하기 때문에 관리자가 매번 수동으로 실행해서 확인할 수 없다. `crontab` 시스템 데몬을 이용하여 `monitor.sh`를 **매 분 정각마다 자동 실행**하도록 등록했다.
*   **무인 관제 자동화**: 이를 통해 사용자가 직접 서버에 로그인하여 명령어를 입력하지 않아도, 백그라운드에서 주기적으로 인프라 자원 상태가 유실 없이 기록되는 자동화 환경을 완성했다.

---

### 5-2. 로그 파일 용량 관리 및 보존 정책 (Log Rotation)

실시간으로 인프라 지표를 수집하면 로그 파일의 크기가 끊임없이 늘어난다. 파일이 지나치게 비대해지면 다음과 같은 인프라 장애 리스크가 발생한다.
1.  **디스크 공간 포화**: 로그가 전체 스토리지를 잠식하여 시스템 자체가 마비될 수 있다.
2.  **데이터 가독성 저하**: 파일 용량이 너무 크면 텍스트 에디터로 아예 열리지 않거나, 장애 발생 시점의 기록을 역추적하여 검색하기가 매우 어려워진다.

*   **본 프로젝트의 정책**: 이러한 고갈 문제를 사전에 예방하기 위해 스크립트 내부에 자체 순환 제어 로직을 주입했다. **로그 파일이 10MB를 초과하면 자동으로 백업본으로 밀어내고, 최대 10개까지만 순환(Rotation) 보존**하여 디스크 용량을 상시 안전 범위 내로 통제한다.

---

### 5-3. 자동 관제 결과 및 실증 로그 검증

스케줄러 등록 완료 후 약 1~2분의 유예 시간을 두고 `/var/log/agent-app/monitor.log` 파일을 조회하여 가이드라인 포맷에 맞춰 데이터가 정상 적재되는 것을 확인했다.

```plaintext
sudo tail -f /var/log/agent-app/monitor.log
[2026-05-29 13:14:01] PID:5769
5770 CPU:3.3% MEM:5.47304% DISK_USED:1%
[2026-05-29 13:15:01] PID:5769
5770 CPU:4.8% MEM:4.13903% DISK_USED:1%
[2026-05-29 13:16:01] PID:5769
5770 CPU:3.2% MEM:5.99338% DISK_USED:1%
```

#### 🎯 실증 로그 필드별 세부 해석

출력된 정형화 로그의 한 줄 한 줄이 가진 인프라적 기술 의미는 다음과 같이 매핑된다.

| 로그 출력 항목 | 실제 기록 데이터 예시 | 데이터 해석 및 검증 의미 |
|---|---|---|
| **타임스탬프** | `[2026-05-15 13:33:01]` | 크론탭에 의해 **정확히 1분 간격**으로 스크립트가 유실 없이 깨어나 시계열 데이터를 누적하고 있음을 증명한다. |
| **프로세스 ID** | `PID:839` | 내부 헬스 체크 로직이 정상 구동되어, 현재 가동 중인 `agent-app` 고유 프로세스 번호를 정확히 실시간 추적하고 있다. |
| **CPU 사용률** | `CPU:100.0%` / `CPU:1.6%` | 연산 장치의 부하 상태를 연산하여 소수점 첫째 자리까지 정밀하게 반영한다. |
| **메모리 사용률** | `MEM:4.3%` | 전체 RAM 용량 중 애플리케이션 및 시스템 데몬들이 점유 중인 실제 가용 메모리 비율을 덤프한다. |
| **디스크 사용률** | `DISK_USED:1%` | 최상위 루트 파티션(/)의 순수 스토리지 사용량을 모니터링하여 디스크 포화 가능성을 상시 체크한다. |
| **임계치 예외 경고** | `[WARNING] CPU > 20%` | 설정한 임계값(CPU > 20%)을 초과하는 오버 스펙 부하를 탐지했을 때, 로그 끝에 경고 식별 문구를 정상 오버레이 시켰음을 실증한다. |

---
## 5-1. 크론(Cron) 주기 실행 및 로그 보존 정책의 필요성

### 크론 스케줄러(Crontab) 주기 실행이 필요한 이유

*   **인프라 상태의 연속성 확보 (시계열 데이터)**: 서버 부하나 프로세스의 생사 상태는 실시간으로 끊임없이 변동한다. 어쩌다 한 번 수동으로 확인하는 것으로는 불시의 장애나 전조증상을 잡아낼 수 없다. 크론탭을 통해 주기적(예: 1분 간격)으로 관제 스크립트를 밀어 넣어야만 **인프라 상태의 연속적인 흐름을 유실 없이 모니터링**할 수 있다.
*   **무인 관제 및 실시간 대응**: 엔지니어가 근무하지 않는 주말, 공휴일 또는 새벽 시간대에도 시스템 스스로 상태를 진단하고 비정상 상태 발생 시 즉각적인 경고(`[WARNING]`)를 기록할 수 있도록 인프라 감시를 완전 자동화하기 위함이다.

---

### 로그 보존 정책 (압축 / 삭제 / 순환)이 반드시 필요한 이유

방치된 로그 파일은 리눅스 시스템의 스토리지를 가득 채워 서버를 마비시키는 시한폭탄과 같다. 따라서 안전한 운영을 위해 다음과 같은 세 단계의 용량 관리 정책이 필수적으로 동반되어야 한다.

| 관리 기법 | 구체적인 처리 방식 | 기술적 필요성 및 인프라적 목적 |
|---|---|---|
| **로그 순환<br>(Rotation)** | `monitor.log`가 일정 크기(예: 10MB)를 넘으면 기존 파일을 `monitor.log.1`로 명패를 바꾸고 새로 쓰기 시작한다. | **가독성 및 시스템 성능 유지**<br>단일 로그 파일이 수 GB 단위로 비대해지면 `grep`이나 `tail` 명령어 등으로 장애 시점을 조회할 때 서버 메모리가 고갈되거나 파일 자체가 열리지 않는 현상을 방지한다. |
| **로그 압축<br>(Compression)** | 순환 프로세스에 의해 뒤로 밀려난 과거 로그 파일들을 `gzip` 등의 도구를 이용해 `.gz` 형태로 압축한다. | **디스크 스토리지 효율화**<br>텍스트 기반의 로그 파일은 압축률이 매우 높기 때문에(최대 80~90%), 가상 서버의 한정된 디스크 공간을 수배 이상 아끼고 효율적으로 공간을 확보할 수 있다. |
| **로그 삭제<br>(Deletion)** | 보존할 백업 파일의 개수를 제한(예: 최대 10개)하여, 그 개수를 초과하는 가장 오래된 로그부터 자동 소멸시킨다. | **디스크 포화(Full Space)에 따른 서버 다운 방지**<br>리눅스는 디스크 사용량이 100%가 되면 시스템 필수 핵심 프로세스조차 정상 동작하지 못하고 **서버 전체가 크래시(Crash)**된다. 이를 막기 위해 상시 안전 여유 용량을 강제로 확보해 두는 방어벽 역할을 한다. |
---

# 🛠️ 6. Troubleshooting (문제 해결 과정)

프로젝트 수행 중 발생한 주요 에러와 해결 과정이다.

---

## 6-1. GLIBC 버전 호환성 이슈

### 문제

Ubuntu 22.04 환경에서 앱 실행 시 `GLIBC_2.38 not found` 에러 발생.

### 원인

바이너리 빌드 환경과 운영 OS 버전 간 라이브러리 불일치.

### 해결

시스템 안정성을 위해 OS 환경을 Ubuntu 24.04로 마이그레이션하여 해결했다.

---

## 6-2. SSH/SFTP 통신 거부 (SCP)

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

## 6-3. 터미널 버퍼 오버플로우 및 코드 유실

### 문제

긴 Shell Script를 붙여넣을 때 코드 일부가 유실되며 `syntax error` 발생.

### 원인

SSH 세션 내 터미널 버퍼 제한 초과.

### 해결

스크립트를 여러 개의 Chunk로 분할하여 `tee -a` 방식으로 순차 병합했다.

---

## 6-4. Health Check에 의한 로그 생성 중단

### 문제

모니터링 로그가 생성되지 않고 즉시 종료됨.

### 원인

`agent-app` 프로세스 종료로 인해 PID 검사 로직이 `exit 1` 수행.

### 해결

`pgrep`으로 프로세스 상태를 확인 후 `nohup`으로 백그라운드 재실행했다.

---

## 6-5. 권한 제어 시스템 검증

### 문제

일반 사용자 계정에서 로그 파일 접근 시 `Permission denied` 발생.

### 원인 및 결과

로그 디렉토리 권한을 `770`으로 설정하여 비그룹 사용자의 접근을 차단한 결과다.  
이는 오류가 아니라 설계한 보안 정책이 정상 동작한 것이다.

---

# Conclusion

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

