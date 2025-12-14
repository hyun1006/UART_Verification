# 🧪 SystemVerilog UART Verification Framework

<div align="center">

<img src="https://img.shields.io/badge/Language-SystemVerilog-green?style=for-the-badge&logo=systemverilog&logoColor=white" />
<img src="https://img.shields.io/badge/Methodology-UVM_Style_OOP-blue?style=for-the-badge" />
<img src="https://img.shields.io/badge/Sim-Vivado_Simulator-red?style=for-the-badge&logo=xilinx&logoColor=white" />
<img src="https://img.shields.io/badge/Target-UART_Controller-orange?style=for-the-badge" />

<br>

**Constrained Random Verification (CRV) & Self-Checking Environment**<br>
객체 지향 프로그래밍(OOP)을 적용한 계층적 테스트벤치(Layered Testbench) 설계 및 자동화된 검증 시스템

</div>

---

## 📖 1. 프로젝트 개요 (Overview)

이 프로젝트는 FPGA 설계의 신뢰성을 보장하기 위해 구축된 **SystemVerilog 기반의 고급 검증 환경(Advanced Verification Environment)**입니다.

기존의 단순한 파형 관측(Directed Test) 방식은 복잡한 디지털 로직의 모든 상태를 검증하는 데 한계가 있습니다. 이를 극복하기 위해 본 프로젝트는 **클래스 기반(Class-based)** 아키텍처를 도입하여 재사용성과 확장성을 극대화했습니다. `Generator`, `Driver`, `Monitor`, `Scoreboard`로 구성된 계층적 구조를 통해 수천 개의 **랜덤 트랜잭션**을 자동으로 생성하고, DUT(Device Under Test)의 응답을 실시간으로 비교·판별(Self-Checking)하여 검증 커버리지를 획기적으로 높였습니다.

### ✨ 핵심 검증 철학 (Key Philosophies)
* **Layered Architecture:** 신호 레벨(Signal Level)과 트랜잭션 레벨(TLM)을 분리하여 테스트벤치의 유지보수성을 확보했습니다.
* **Constrained Random Verification (CRV):** `rand`, `randc`를 활용해 사람이 놓치기 쉬운 코너 케이스(Corner Case)와 경계 조건을 집중적으로 타격합니다.
* **Self-Checking Mechanism:** 시뮬레이션 파형을 눈으로 확인하지 않아도, Scoreboard가 데이터 무결성을 자동으로 판단하여 Pass/Fail을 리포팅합니다.

---

## 🏗️ 2. 검증 환경 아키텍처 (Verification Architecture)

테스트벤치는 DUT를 감싸는 **Environment** 컨테이너 내에서 독립적인 객체들이 `Mailbox`와 `Event`를 통해 비동기적으로 통신하는 구조입니다.



```mermaid
graph LR
    subgraph "SystemVerilog Environment (OOP)"
        GEN[Generator] -->|Randomize & Put| MBX1(("Gen2Drv<br>Mailbox"))
        MBX1 -->|Get Trans| DRV[Driver]
        
        DRV -->|Virtual Interface| IF[UART Interface]
        IF <==> DUT["UART Controller<br>(RTL Design)"]
        IF -->|Sample Signals| MON[Monitor]
        
        MON -->|Reassemble| MBX2(("Mon2Scb<br>Mailbox"))
        MBX2 -->|Get Actual| SCB[Scoreboard]
        
        DRV -.->|Copy Expected| MBX3(("Drv2Scb<br>Mailbox")) -.-> SCB
    end
    
    SCB -->|Compare & Verify| RESULT[Pass/Fail Report]
````

### 🧩 주요 컴포넌트 상세 분석 (Component Details)

| 컴포넌트 (Class) | 역할 (Role) | 기술적 구현 상세 (Technical Implementation) |
| :--- | :--- | :--- |
| **Transaction** | 데이터 객체화 | • 검증 대상 데이터(Payload)와 제어 정보를 포함한 클래스.<br>• `randc bit [7:0] data`로 선언하여 중복 없는 랜덤 패턴 생성을 보장.<br>• `function display()`를 통해 디버깅 정보 출력 지원. |
| **Generator** | 자극(Stimulus) 생성 | • `assert(trans.randomize())`를 호출하여 제약 조건(Constraints)을 만족하는 유효한 랜덤 데이터를 생성.<br>• 생성된 객체(Deep Copy)를 Mailbox를 통해 Driver로 전달. |
| **Driver** | 신호 구동 (Driving) | • 추상화된 트랜잭션 패킷을 받아 물리적 신호(Pin-level)로 변환.<br>• `Virtual Interface`를 통해 RTL의 타이밍(Baudrate)에 맞춰 Start bit → Data bits → Stop bit 순서로 신호를 인가. |
| **Monitor** | 신호 감지 (Passive) | • DUT의 출력 신호를 간섭 없이 관찰(Spying).<br>• UART 프로토콜의 타이밍에 맞춰 Tx 라인을 샘플링하고, 이를 다시 트랜잭션 객체로 재조립(Reassemble)하여 Scoreboard로 전달. |
| **Scoreboard** | 무결성 검증 | • **Golden Reference Model:** Driver가 보낸 \*\*기대값(Expected)\*\*과 Monitor가 수집한 \*\*실제값(Actual)\*\*을 큐(Queue)에 저장.<br>• 실시간 비교(Compare)를 수행하여 데이터 유실이나 변조 여부를 즉시 판정. |

-----

## 🔍 3. 테스트 시나리오 (Test Scenarios)

### 3.1 Random Data Loopback Test (`tb_uart_top.sv`)

가장 핵심적인 검증 시나리오로, 데이터의 송수신 무결성을 확인합니다.

  * **목적:** UART RX FIFO → UART TX FIFO 경로의 데이터 무결성 및 고속 전송 안정성 검증.
  * **동작 흐름:**
    1.  Generator가 256회 반복하며 `randc`로 0\~255까지의 중복 없는 랜덤 바이트 생성.
    2.  Driver가 UART 프로토콜(Start/Stop 비트 포함)에 맞춰 비동기적으로 데이터 주입.
    3.  DUT는 수신한 데이터를 내부 FIFO에 저장 후 즉시 재전송(Loopback).
    4.  Scoreboard는 입력된 랜덤 값과 출력된 값이 정확히 일치하는지 비트 단위로 대조.

### 3.2 Functional Control Test (`tb_top_function.sv`)

시스템 제어 명령어가 올바르게 파싱되고 동작하는지 확인합니다.

  * **목적:** ASCII 명령어(Keyboard Input)에 따른 내부 FSM 상태 전이 및 레지스터 제어 검증.
  * **검증 항목:**
      * **Command 'r' (Run):** 스톱워치/카운터 모듈의 Enable 신호 활성화 여부.
      * **Command 'c' (Clear):** 내부 레지스터 리셋 및 초기화 동작 확인.
      * **Command 'm' (Mode):** 시계 ↔ 스톱워치 간 모드 전환 플래그 동작 확인.

-----

## 💻 4. 핵심 기술 및 코드 리뷰 (Technical Highlights)

### 4.1 가상 인터페이스 (Virtual Interface)

SystemVerilog의 클래스(OOP)는 동적(Dynamic) 객체이므로 정적인(Static) 하드웨어 모듈(Module)에 직접 접근할 수 없습니다. 이를 연결하기 위해 **가상 인터페이스** 핸들을 사용합니다.

```systemverilog
// Interface Definition
interface uart_interface;
    logic rx, tx; // Physical signals
endinterface

// Driver Class utilizing Virtual Interface
class driver;
    virtual uart_interface uart_if; // Handle to the physical interface
    
    task run();
        uart_if.rx = 1'b0; // Drive Start Bit directly to RTL
        // ... (Driving Data Bits)
    endtask
endclass
```

### 4.2 Mailbox를 이용한 스레드 동기화 (IPC)

독립적으로 실행되는 스레드(Generator, Driver 등) 간의 데이터 충돌을 방지하고 안전하게 데이터를 전달하기 위해 `mailbox`를 사용합니다. 이는 생산자-소비자 패턴(Producer-Consumer Pattern)을 구현합니다.

```systemverilog
// Generator (Producer)
gen2drv_mbox.put(trans); // Put transaction into the mailbox

// Driver (Consumer)
gen2drv_mbox.get(trans); // Block until data is available, then retrieve
```

### 4.3 Self-Checking Logic (Scoreboard)

별도의 파형 분석 없이 시뮬레이션 로그만으로 성공 여부를 판단할 수 있도록 자동화된 비교 로직을 포함합니다.

```systemverilog
if (expected_data == actual_data) begin
    pass_count++;
    $display("[SCB] PASS: Data matched! (Val: %h)", actual_data);
end else begin
    fail_count++;
    $error("[SCB] FAIL: Mismatch! Exp: %h, Act: %h", expected_data, actual_data);
end
```

-----

## 📊 5. 시뮬레이션 리포트 (Verification Report)

테스트벤치 실행이 완료되면 `Environment` 클래스는 수집된 통계를 바탕으로 최종 리포트를 콘솔에 출력합니다. 이를 통해 검증의 성공 여부를 한눈에 파악할 수 있습니다.

```text
===================================
=========== TEST REPORT ===========
===================================
==    Total Test Cases : 256     ==  <-- Generated Random Packets
==    Passed Cases     : 256     ==  <-- Successfully Verified
==    Failed Cases     : 0       ==  <-- Mismatches / Errors
===================================
==      STATUS: TEST PASSED      ==
===================================
```

-----

## 📂 6. 프로젝트 발표 자료 (Presentation)

검증 환경의 상세 설계 구조와 시뮬레이션 파형 분석 결과는 아래 보고서를 통해 확인하실 수 있습니다.

\<div align="center"\>

[![PDF Report](https://img.shields.io/badge/📄_PDF_Report-View_Document-FF0000?style=for-the-badge&logo=adobeacrobatreader&logoColor=white)](https://www.google.com/search?q=https://github.com/seokhyun-hwang/files/blob/main/UART_Verification.pdf)

\</div\>

-----

## 📂 7. 디렉토리 구조 (Directory Structure)

```text
📦 UART-SystemVerilog-Verification
 ┣ 📂 src                    # RTL Design Sources (DUT)
 ┃ ┣ 📜 uart_top.sv          # [DUT] UART Top Wrapper (FIFO + RX/TX)
 ┃ ┣ 📜 uart_rx.sv           # [DUT] RX Module (Oversampling Logic)
 ┃ ┣ 📜 uart_tx.sv           # [DUT] TX Module
 ┃ ┗ 📜 fifo.sv              # [DUT] Circular FIFO Buffer
 ┣ 📂 verification           # SystemVerilog Testbench
 ┃ ┣ 📜 tb_uart_top.sv       # [TB] Random Verification Top (Class definitions)
 ┃ ┣ 📜 tb_uart_rx.sv        # [TB] RX Unit Level Test
 ┃ ┣ 📜 tb_top_function.sv   # [TB] Functional Scenario Test
 ┃ ┗ 📜 interface.sv         # [TB] Interface Definition
 ┗ 📜 README.md              # Project Documentation
```

-----

## 🚀 8. 실행 방법 (How to Run)

1.  **Vivado 실행:** Xilinx Vivado Design Suite를 실행합니다.
2.  **소스 추가:** `src` 폴더의 RTL 파일과 `verification` 폴더의 Testbench 파일을 프로젝트에 추가합니다.
3.  **시뮬레이션 설정:**
      * **랜덤 검증:** `tb_uart_top` 모듈을 Simulation Top으로 설정 후 실행.
      * **기능 검증:** `tb_top_function` 모듈을 Simulation Top으로 설정 후 실행.
4.  **결과 확인:**
      * **Waveform:** 신호 파형을 통해 타이밍 및 데이터 흐름 확인.
      * **Tcl Console:** Scoreboard가 출력하는 Pass/Fail 리포트 확인.

<br>

-----
Copyright ⓒ 2025. SEOKHYUN HWANG. All rights reserved.
