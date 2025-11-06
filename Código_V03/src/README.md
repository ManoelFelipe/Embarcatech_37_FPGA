# Pump Controller (Simplified) — com Displays 7-Segmentos

**Escopo desta versão:** implementação fiel às regras de partida/parada *sem* robustez (sem debounce, sem estado de falha).  
**Novidade:** dois displays 7-seg (um para cada tanque) exibindo níveis **1..5** conforme 0..100%.

## Arquivos
- `pump_controller_simple.sv` — módulo SystemVerilog (com displays).
- `colorlight_i9_comentado.lpf` — pinagem final da Colorlight i9.
- `fsm_diagram_simple.mmd` — diagrama da FSM (2 estados).
- `tb_pump_controller_simple.sv` — testbench básico (opcional).

---

## Interface (I/O)

| Sinal | Direção | Largura | Descrição |
|------|---------|---------|-----------|
| `clk` | in | 1 | Clock do sistema |
| `rst_n` | in | 1 | Reset síncrono ativo–baixo |
| `lvl_inf[2:0]` | in | 3 | Nível do tanque inferior (0=0%...4=100%) |
| `lvl_sup[2:0]` | in | 3 | Nível do tanque superior (0=0%...4=100%) |
| `en_auto` | in | 1 | 1 = modo automático; 0 = manual |
| `pump_on` | out | 1 | Liga a bomba hidráulica |
| `solenoid_open` | out | 1 | Abre válvula do tanque inferior |
| `led_green` | out | 1 | ON = bomba ligada |
| `led_red` | out | 1 | ON = bomba desligada |
| `fault` | out | 1 | Sempre 0 nesta versão |
| `seg_inf[6:0]` | out | 7 | Display inferior (a..g) |
| `seg_sup[6:0]` | out | 7 | Display superior (a..g) |

---

## Parâmetros

| Parâmetro | Default | Significado |
|----------|---------|-------------|
| `CLK_HZ` | 25_000_000 | Clock (Hz) |
| `LVL_SUP_START` | 3'd1 | Liga aos 25% (tanque sup.) |
| `LVL_INF_START` | 3'd3 | Liga aos 75% (tanque inf.) |
| `LVL_SUP_STOP` | 3'd3 | Desliga aos 75% (sup.) |
| `LVL_INF_STOP` | 3'd1 | Desliga aos 25% (inf.) |
| `LVL_INF_REFILL` | 3'd4 | Fecha válvula em 100% |
| `INVERT_LEVEL_CODE` | 1'b0 | Inverte níveis (sensores ativos-baixo) |
| `SEG_ACTIVE_HIGH` | 1'b1 | 1 = comum-cátodo (ativo-alto); 0 = comum-ânodo |

> Os sensores físicos são **ativos em nível baixo** (0 V = molhado). Use `INVERT_LEVEL_CODE=1` se necessário.

---

## Regras de Controle
- **Partida:** `pump_on=1` quando `en_auto=1` **e** `lvl_sup==LVL_SUP_START` **e** `lvl_inf==LVL_INF_START`.
- **Parada:** `pump_on=0` quando `lvl_inf<=LVL_INF_STOP` **ou** `lvl_sup>=LVL_SUP_STOP` **ou** `en_auto==0`.
- **Histerese:** em `PUMPING`, permanece ligado até condição de parada.
- **Válvula:** `solenoid_open=1` enquanto `lvl_inf<LVL_INF_REFILL`; fecha quando 100%.

---

## Exibição — Displays 7-Segmentos
| Nível (%) | Dígito no Display |
|------------|------------------|
| 0 % | “1” |
| 25 % | “2” |
| 50 % | “3” |
| 75 % | “4” |
| 100 % | “5” |

- Qualquer valor fora de 0..4 mostra “E” (erro).  
- Displays **comum-cátodo**, ativo-alto (`SEG_ACTIVE_HIGH=1`).  
- Corrente limitada por resistores (~330 Ω em cada segmento).

---

## Tabela de Estados (resumo)
| Estado Atual | Condição | Próximo Estado | Ações |
|--------------|----------|----------------|-------|
| `IDLE` | `en_auto && start_cond` | `PUMPING` | Liga bomba / LED verde ON |
| `IDLE` | outro caso | `IDLE` | Bomba OFF |
| `PUMPING` | `!en_auto || stop_cond` | `IDLE` | Desliga bomba / LED vermelho ON |
| `PUMPING` | outro caso | `PUMPING` | Mantém ON |

onde:  
`start_cond = (lvl_sup==LVL_SUP_START) && (lvl_inf==LVL_INF_START)`  
`stop_cond = (lvl_inf<=LVL_INF_STOP) || (lvl_sup>=LVL_SUP_STOP)`

---

## Tabela de Transição de Estados (pump_controller_simple)

| Estado Atual | fault\_cond | en\_auto | start\_cond | stop\_cond | Próximo Estado | Condição Lógica da Transição |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `IDLE` | 0 | 1 | 1 | X | `PUMPING` | Modo automático ligado e condição de partida atendida. |
| `IDLE` | 0 | 0 | X | X | `IDLE` | Modo automático desligado (permanece em repouso). |
| `IDLE` | 0 | 1 | 0 | X | `IDLE` | Modo automático ligado, mas aguardando partida. |
| | | | | | | |
| `PUMPING` | 0 | 0 | X | X | `IDLE` | Modo automático foi desabilitado (força parada). |
| `PUMPING` | 0 | 1 | X | 1 | `IDLE` | Condição de parada atendida. |
| `PUMPING` | 0 | 1 | X | 0 | `PUMPING` | Senão (permanece bombeando / Histerese). |

## Pinagem — **Colorlight i9**

| Sinal | SITE | Observação |
|-------|------|------------|
| `clk` | **P3** | Clock principal (25 MHz) |
| `rst_n` | **P4** | Reset síncrono ativo-baixo |
| `lvl_inf[0]` | **N16** | Bit 0 – Nível tanque inferior |
| `lvl_inf[1]` | **N17** | Bit 1 – Nível tanque inferior |
| `lvl_inf[2]` | **M17** | Bit 2 – Nível tanque inferior |
| `lvl_sup[0]` | **R16** | Bit 0 – Nível tanque superior |
| `lvl_sup[1]` | **T16** | Bit 1 – Nível tanque superior |
| `lvl_sup[2]` | **U16** | Bit 2 – Nível tanque superior |
| `en_auto` | **U17** | Habilita modo automático |
| `pump_on` | **K4** | Saída relé bomba |
| `solenoid_open` | **J3** | Saída relé válvula |
| `led_green` | **J2** | LED verde (bomba ligada) |
| `led_red` | **H2** | LED vermelho (bomba off) |
| `fault` | **G2** | Reservado (sempre 0) |
| `seg_inf[6]` | **A3** | Segmento a – Display Inferior |
| `seg_inf[5]` | **B3** | Segmento b |
| `seg_inf[4]` | **C3** | Segmento c |
| `seg_inf[3]` | **D3** | Segmento d |
| `seg_inf[2]` | **E3** | Segmento e |
| `seg_inf[1]` | **F3** | Segmento f |
| `seg_inf[0]` | **G3** | Segmento g |
| `seg_sup[6]` | **A4** | Segmento a – Display Superior |
| `seg_sup[5]` | **B4** | Segmento b |
| `seg_sup[4]` | **C4** | Segmento c |
| `seg_sup[3]` | **D4** | Segmento d |
| `seg_sup[2]` | **E4** | Segmento e |
| `seg_sup[1]` | **F4** | Segmento f |
| `seg_sup[0]` | **G4** | Segmento g |

> Todos os segmentos com resistores (~330 Ω) em série.  
> IO Type = LVCMOS33, DRIVE = 8. Displays comum-cátodo (ativo-alto).

---

## Conformidade com o Prompt_v3
- FSM simples (IDLE/PUMPING) conforme especificado.  
- Compatível com sensores ativos-baixo (`INVERT_LEVEL_CODE`).  
- Dois displays 7-seg adicionados com controle direto (ativo-alto).  
- Estrutura pronta para evolução com debounce e estado `FAULT`.
