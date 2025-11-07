# Controlador Digital de Nível de Líquido (FSM)  
Sistema automatizado de bombeamento entre dois reservatórios utilizando Máquina de Estados Finitos (FSM) em Verilog, com implementação direcionada à FPGA **Lattice ECP5 (Colorlight i9)**.

Repositório oficial: https://github.com/ManoelFelipe/Embarcatech_37_FPGA

---

## 📌 Visão Geral

Este projeto implementa um **controlador digital de nível de líquido** baseado em FSM, capaz de monitorar sensores discretos (0–100 % em 5 níveis) e acionar:

- **Bomba hidráulica** (transferência entre tanques)  
- **Válvula solenóide** (reposição do reservatório inferior)  
- **Indicadores visuais (LEDs + Displays 7 segmentos)**  

A lógica inclui histerese (25 % / 75 %) para evitar chattering e foi modelada seguindo boas práticas de projeto digital sequencial.

> O projeto pode ser usado didaticamente em cursos de eletrônica digital, sistemas embarcados, HDL ou automação.

---

## 🧠 Arquitetura Funcional

Fluxo principal:

Sensores discretos → FSM → Atuadores (bomba/válvula) + LEDs/Displays


![Figura 1 – Arquitetura funcional](/docs/figures/fig1_arch.png)

---

## 🔁 Máquina de Estados (FSM)

| Estado     | Condição de Transição                           | Ação                              |
|------------|-------------------------------------------------|-----------------------------------|
| `IDLE`     | Sup ≤ 25 % **e** Inf ≥ 75 %                     | Liga bomba / válvula aberta       |
| `PUMPING`  | Sup ≥ 75 % **ou** Inf ≤ 25 %                    | Desliga bomba / válvula aberta\*  |

\* A válvula só fecha quando o nível inferior atinge **100 %**.

FSM mínima: dois estados → `IDLE` e `PUMPING`.

---

## 🗂️ Estrutura do Repositório

Embarcatech_37_FPGA/
│
├── src/hdl/ # módulos Verilog
│ ├── fsm_core.v
│ ├── sensors.v
│ ├── drivers.v
│ └── top.v
│
├── sim/ # testbenches + scripts
│ ├── tb_fsm.v
│ └── waves.gtkw
│
├── docs/
│ ├── figures/
│ │ └── fig1_arch.png
│ └── nivel_liquido.pdf # artigo do projeto
│
├── hw/ # pinout, esquemas, PCB ou ligação Colorlight i9
│
├── Makefile # (opcional) automação simulação/síntese
└── README.md


---

## ▶️ Simulação (Icarus Verilog + GTKWave)

Requisitos:

```bash
sudo apt install iverilog gtkwave

Rodar simulação:

cd sim
iverilog -o fsm_tb tb_fsm.v ../src/hdl/*.v
vvp fsm_tb
gtkwave waves.vcd

sudo apt install yosys nextpnr-ecp5 fpga-toolchain
yosys -p "synth_ecp5 -top top -json top.json" src/hdl/*.v
nextpnr-ecp5 --json top.json --lpf colorlight_i9.lpf --textcfg top.cfg --um5g-85k
ecppack top.cfg top.bit
openFPGALoader -b colorlight_i9 top.bit

 ```

Roadmap / Trabalhos Futuros

 FSM robusta (timeout, debounce, FAULT recovery)

 Modo manual/teste

 Exibição de falhas no display

 Integração com supervisório UART/MQTT

 Versão com sensores analógicos (ADC)



👨‍💻 Autores

Projeto acadêmico — Instituto Federal do Maranhão (IFMA)
Manoel Furtado, Yuri Cândido, Paulo Gomes

📜 Licença

Distribuído sob a licença MIT.
Você é livre para usar, modificar e distribuir, mantendo os créditos.
Roadmap / Trabalhos Futuros

 FSM robusta (timeout, debounce, FAULT recovery)

 Modo manual/teste

 Exibição de falhas no display

 Integração com supervisório UART/MQTT

 Versão com sensores analógicos (ADC)

👨‍💻 Autores

Projeto acadêmico — Instituto Federal do Maranhão (IFMA)
Manoel Furtado, Yuri Cândido, Paulo Gomes

📜 Licença

Distribuído sob a licença MIT.
Você é livre para usar, modificar e distribuir, mantendo os créditos.
