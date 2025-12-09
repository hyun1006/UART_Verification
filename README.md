# 🧪 SystemVerilog UART Verification Framework

\<div align="center"\>

\<img src="[https://img.shields.io/badge/Language-SystemVerilog-green?style=for-the-badge\&logo=systemverilog](https://www.google.com/search?q=https://img.shields.io/badge/Language-SystemVerilog-green%3Fstyle%3Dfor-the-badge%26logo%3Dsystemverilog)" /\>
\<img src="[https://img.shields.io/badge/Methodology-UVM\_Style\_OOP-blue?style=for-the-badge](https://www.google.com/search?q=https://img.shields.io/badge/Methodology-UVM_Style_OOP-blue%3Fstyle%3Dfor-the-badge)" /\>
\<img src="[https://img.shields.io/badge/Sim-Vivado\_Simulator-red?style=for-the-badge\&logo=xilinx](https://www.google.com/search?q=https://img.shields.io/badge/Sim-Vivado_Simulator-red%3Fstyle%3Dfor-the-badge%26logo%3Dxilinx)" /\>
\<img src="[https://img.shields.io/badge/Target-UART\_Controller-orange?style=for-the-badge](https://www.google.com/search?q=https://img.shields.io/badge/Target-UART_Controller-orange%3Fstyle%3Dfor-the-badge)" /\>

**Constrained Random Verification (CRV) & Self-Checking Environment**<br>
객체 지향 프로그래밍(OOP)을 적용한 계층적 테스트벤치(Layered Testbench) 설계 및 자동화된 검증 시스템

\</div\>

-----

## 📖 1. 프로젝트 개요 (Overview)

이 프로젝트는 FPGA 설계의 신뢰성을 보장하기 위해 구축된 \*\*SystemVerilog 기반의 고급 검증 환경(Advanced Verification Environment)\*\*입니다.
기존의 단순한 파형 관측 방식에서 벗어나, **클래스 기반(Class-based)** 아키텍처를 도입하여 재사용성과 확장성을 극대화했습니다. `Generator`, `Driver`, `Monitor`, `Scoreboard`로 구성된 계층적 구조를 통해 랜덤 트랜잭션을 생성하고, DUT(Device Under Test)의 응답을 자동으로 판별(Self-Checking)합니다.

### ✨ 핵심 검증 기능 (Key Verification Features)

  * **Layered Testbench Architecture:** 기능별로 모듈화된 객체들이 상호작용하는 구조로, 유지보수가 용이합니다.
  * **Transaction Level Modeling (TLM):** 신호(Pin) 레벨이 아닌 추상화된 패킷(Transaction) 단위로 데이터 흐름을 제어합니다.
  * **Constrained Random Verification (CRV):** `rand`, `randc`를 활용하여 코너 케이스(Corner Case)를 커버하는 무작위 테스트 패턴을 생성합니다.
  * **IPC (Inter-Process Communication):** `Mailbox`와 `Event`를 사용하여 쓰레드 간 동기화 및 데이터 전송을 안전하게 처리합니다.

-----

## 🏗️ 2. 검증 환경 아키텍처 (Verification Architecture)

테스트벤치는 DUT를 감싸는 **Environment** 컨테이너 내에서 독립적인 컴포넌트들이 `Mailbox`를 통해 통신하는 구조입니다.

```mermaid
graph LR
    subgraph "SystemVerilog Environment"
        GEN[Generator] -->|Put Trans| MBX1((Gen2Drv<br>Mailbox))
        MBX1 -->|Get Trans| DRV[Driver]
        
        DRV -->|Virtual Interface| IF[UART Interface]
        IF <==> DUT[UART Controller<br>(RTL Design)]
        IF -->|Sample| MON[Monitor]
        
        MON -->|Put Trans| MBX2((Mon2Scb<br>Mailbox))
        MBX2 -->|Get Trans| SCB[Scoreboard]
        
        DRV -.->|Copy Expected| MBX3((Drv2Scb<br>Mailbox)) -.-> SCB
    end
    
    SCB -->|Compare| RESULT[Pass/Fail Report]
```

### 🧩 주요 컴포넌트 상세 분석

| 컴포넌트 (Class) | 역할 (Role) | 기술적 구현 (Technical Detail) |
| :--- | :--- | :--- |
| **Transaction** | [cite_start]데이터 추상화 | [cite: 485] `randc`로 선언된 8-bit Payload를 포함하며, 전송할 데이터 패킷을 객체화합니다. |
| **Generator** | [cite_start]자극 생성 | [cite: 489] `assert(trans.randomize())`를 통해 제약 조건 내에서 유효한 랜덤 데이터를 생성하여 Driver로 전달합니다. |
| **Driver** | [cite_start]신호 구동 | [cite: 498] 트랜잭션을 물리적 신호로 변환합니다. `Virtual Interface`를 통해 DUT의 Rx 핀에 UART 프로토콜(Start-Data-Stop)을 인가합니다. |
| **Monitor** | [cite_start]신호 감지 | [cite: 504] 인터페이스의 Tx 라인을 모니터링하다가 데이터가 감지되면, 비트를 샘플링하여 트랜잭션 객체로 재조립합니다. |
| **Scoreboard** | [cite_start]무결성 검증 | [cite: 518] Driver가 보낸 \*\*기대값(Expected)\*\*과 Monitor가 수집한 \*\*실제값(Actual)\*\*을 비교하여 실시간으로 Pass/Fail을 판정합니다. |

-----

## 🔍 3. 테스트 시나리오 (Test Scenarios)

### 3.1 Random Data Loopback Test (`tb_uart_top.sv`)

  * **목적:** UART RX FIFO → UART TX FIFO 경로의 데이터 무결성 및 고속 전송 안정성 검증.
  * **동작:**
    1.  Generator가 256개의 중복 없는 무작위 패턴(`randc`) 생성.
    2.  Driver가 UART 프로토콜에 맞춰 주입.
    3.  DUT가 데이터를 수신하여 FIFO에 저장 후 다시 송신(Loopback).
    4.  Scoreboard가 데이터 손실 여부 확인.

### 3.2 Functional Control Test (`tb_top_function.sv`)

  * **목적:** 실제 애플리케이션(카운터/타이머) 제어 프로토콜 검증.
  * **시나리오:**
      * [cite_start]**Command 'r' (Run):** [cite: 569] `send_char("r")` 호출 → 시스템 Enable 신호 활성화 확인.
      * [cite_start]**Command 'c' (Clear):** [cite: 571] `send_char("c")` 호출 → 내부 레지스터 초기화 확인.
      * [cite_start]**Command 'm' (Mode):** [cite: 573] `send_char("m")` 호출 → 동작 모드 전환 확인.

-----

## 💻 4. 핵심 기술 및 코드 리뷰 (Technical Highlights)

### 4.1 가상 인터페이스 (Virtual Interface)

클래스(동적 객체)는 정적 모듈(Static Module)인 DUT의 신호에 직접 접근할 수 없습니다. 이를 해결하기 위해 `interface`를 정의하고, 클래스 내부에서는 `virtual interface` 핸들을 사용하여 하드웨어 신호를 제어합니다.

```systemverilog
// Driver Class Example
virtual uart_interface uart_if; [cite_start]// [cite: 492] Virtual Interface handle
task run();
    uart_if.rx = 1'b0; // Drive logic via interface
    ...
endtask
```

### 4.2 Mailbox를 이용한 동기화

독립적으로 실행되는 스레드(Generator, Driver 등) 간의 데이터 전달을 위해 `mailbox`를 사용합니다. 이는 생산자-소비자 패턴을 구현하며 데이터 레이스 컨디션을 방지합니다.

```systemverilog
// Generator puts data
gen2drv_mbox.put(trans); [cite_start]// [cite: 490]
// Driver gets data
gen2drv_mbox.get(trans); [cite_start]// [cite: 496]
```

### 4.3 Self-Checking Scoreboard

별도의 파형 분석 없이 시뮬레이션 로그만으로 성공 여부를 판단할 수 있도록 자동화된 비교 로직을 포함합니다.

```systemverilog
if (trans.send_data == tr.send_data) begin
    pass_count++;
    $display("[SCB] data matched!"); [cite_start]// [cite: 519]
end else begin
    fail_count++;
    $display("[SCB] mismatch!"); [cite_start]// [cite: 522]
end
```

-----

## 📊 5. 시뮬레이션 결과 리포트 (Report)

테스트벤치 실행이 완료되면 `Environment` 클래스는 수집된 통계를 바탕으로 최종 리포트를 출력합니다.

```text
===================================
=========== test report ===========
===================================
[cite_start]==    Total Test : 256           ==  <-- [cite: 528] Generated Packets
[cite_start]==    Pass Test  : 256           ==  <-- [cite: 529] Matched Transactions
[cite_start]==    Fail Test  : 0             ==  <-- [cite: 530] Mismatched / Errors
===================================
==     Testbench is finished     ==
===================================
```

-----

## 📂 6. 폴더 구조 (Directory Structure)

```text
📦 UART-SystemVerilog-Verification
 ┣ 📂 src
 [cite_start]┃ ┣ 📜 uart_top.sv         # [DUT] UART Top (FIFO + RX/TX) [cite: 1]
 [cite_start]┃ ┣ 📜 uart_rx.sv          # [DUT] RX Module (Oversampling) [cite: 228]
 [cite_start]┃ ┣ 📜 uart_tx.sv          # [DUT] TX Module [cite: 8]
 [cite_start]┃ ┗ 📜 fifo.sv             # [DUT] Circular FIFO Buffer [cite: 35]
 ┣ 📂 verification
 [cite_start]┃ ┣ 📜 tb_uart_top.sv      # [TB] Random Verification Top (Class definitions) [cite: 485]
 [cite_start]┃ ┣ 📜 tb_uart_rx.sv       # [TB] RX Unit Test [cite: 260]
 [cite_start]┃ ┗ 📜 tb_top_function.sv  # [TB] Functional Scenario Test [cite: 553]
 ┗ 📜 README.md             # Project Documentation
```

-----

\<div align="center"\>
\<i\>Verified with SystemVerilog OOP Methodology on Xilinx Vivado\</i\>
\</div\>
