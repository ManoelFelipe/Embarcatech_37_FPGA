
# Pump Controller (Simplified)

**Escopo desta versão:** implementação fiel às regras de partida/parada *sem* robustez (sem debounce, sem estado de falha). Útil para estudo da FSM.

## Arquivos
- `pump_controller_simple.sv` — módulo SystemVerilog.
- `tb_pump_controller_simple.sv` — testbench básico com asserts.
- `fsm_diagram_simple.mmd` — diagrama Mermaid da FSM (2 estados).

## Interface (I/O)

| Sinal | Direção | Largura | Descrição |
|------|---------|---------|-----------|
| `clk` | in | 1 | Clock do sistema |
| `rst_n` | in | 1 | Reset **síncrono** ativo-baixo |
| `lvl_inf[2:0]` | in | 3 | Nível do tanque inferior: 0=0%,1=25%,2=50%,3=75%,4=100% |
| `lvl_sup[2:0]` | in | 3 | Nível do tanque superior: 0=0%,1=25%,2=50%,3=75%,4=100% |
| `en_auto` | in | 1 | 1 = modo automático; 0 = manual (bomba forçada OFF) |
| `pump_on` | out | 1 | 1 = rele/bomba ligada |
| `solenoid_open` | out | 1 | 1 = válvula aberta (reabastecer) |
| `led_green` | out | 1 | espelha `pump_on` |
| `led_red` | out | 1 | inverso de `pump_on` |
| `fault` | out | 1 | sempre 0 nesta versão (sem falhas) |

## Parâmetros

| Parâmetro | Default | Significado |
|----------|---------|-------------|
| `CLK_HZ` | 25_000_000 | frequência do clock (não usada para temporização nesta versão) |
| `LVL_SUP_START` | 3'd1 | 25% |
| `LVL_INF_START` | 3'd3 | 75% |
| `LVL_SUP_STOP` | 3'd3 | 75% |
| `LVL_INF_STOP` | 3'd1 | 25% |
| `LVL_INF_REFILL` | 3'd4 | 100% |

## Regras de Controle
- **Partida:** `pump_on=1` quando `en_auto=1` **e** `lvl_sup==25%` **e** `lvl_inf==75%`.
- **Parada:** `pump_on=0` quando `lvl_inf<=25%` **ou** `lvl_sup>=75%` **ou** `en_auto==0`.
- **Histerese:** em `PUMPING`, permanece até ocorrer condição de parada.
- **Válvula:** `solenoid_open=1` enquanto `lvl_inf<100%`; fecha (`0`) quando `lvl_inf==100%`.

## Tabela de Transição de Estados

| Estado Atual | Condição | Próximo Estado | Ações |
|--------------|----------|----------------|-------|
| `IDLE` | `en_auto && (lvl_sup==25%) && (lvl_inf==75%)` | `PUMPING` | `pump_on=1`, `led_green=1`, `led_red=0` |
| `IDLE` | caso contrário | `IDLE` | bomba OFF |
| `PUMPING` | `(!en_auto) || (lvl_inf<=25%) || (lvl_sup>=75%)` | `IDLE` | `pump_on=0`, `led_green=0`, `led_red=1` |
| `PUMPING` | caso contrário | `PUMPING` | mantém ON |

## Simulação
1. Compile:
   ```sh
   iverilog -g2012 -o sim tb_pump_controller_simple.sv pump_controller_simple.sv
   ```
2. Rode:
   ```sh
   vvp sim
   ```
3. Mensagem esperada: `All checks passed.`

> Observação: Em versões futuras, você pode reintroduzir debounce/validações mantendo a mesma interface (adição de estado `FAULT`).


## Versão Robusta (com Debounce e Falhas)

**Novos arquivos**
- `pump_controller_robust.sv` — sincronização + debounce, estado `FAULT`, proteções básicas.
- `tb_pump_controller_robust.sv` — cenários com debounce rápido e injeção de falhas.
- `fsm_diagram_robust.mmd` — diagrama Mermaid com estado `FAULT`.

**Debounce**: requer `DEBOUNCE_MS` de estabilidade do valor lido para considerar a troca (níveis e `en_auto`).  
**Falhas (latch até `reset`)**:
- Código inválido nos níveis (valor > 4).
- **Overflow**: `pump_on && lvl_sup==100%` (deveria ter parado em ≥75%).  
- **Dry-run**: `pump_on && lvl_inf==0%` (riscos de cavitação).  
- **Salto irreal**: diferença entre leituras debounced consecutivas maior que `MAX_STEP`.

**Parâmetros**: `CLK_HZ`, `DEBOUNCE_MS`, `MAX_STEP` (padrão = 2).

**Compatibilidade**: mesma interface lógica de alto nível; `fault_latched` substitui `fault` fixo 0.

