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



### Tabela de Descrição de Variáveis (pump_controller_simple)

Esta tabela descreve todos os parâmetros, entradas e saídas do módulo `pump_controller_simple.sv`.

| Tipo | Nome | Largura | Descrição |
| :--- | :--- | :--- | :--- |
| **Parâmetro** | `CLK_HZ` | (int) | Frequência do clock (Default: 25\_000\_000) |
| **Parâmetro** | `LVL_SUP_START` | 3 bits | Nível superior para ligar (Default: 3'd1 / 25%) |
| **Parâmetro** | `LVL_INF_START` | 3 bits | Nível inferior para ligar (Default: 3'd3 / 75%) |
| **Parâmetro** | `LVL_SUP_STOP` | 3 bits | Nível superior para parar (Default: 3'd3 / 75%) |
| **Parâmetro** | `LVL_INF_STOP` | 3 bits | Nível inferior para parar (Default: 3'd1 / 25%) |
| **Parâmetro** | `LVL_INF_REFILL` | 3 bits | Nível inferior para fechar válvula (Default: 3'd4 / 100%) |
| **Entrada** | `clk` | 1 bit | Clock do sistema |
| **Entrada** | `rst_n` | 1 bit | Reset síncrono ativo-baixo |
| **Entrada** | `lvl_inf` | 3 bits | Nível do tanque inferior (0=0%... 4=100%) |
| **Entrada** | `lvl_sup` | 3 bits | Nível do tanque superior (0=0%... 4=100%) |
| **Entrada** | `en_auto` | 1 bit | 1 = modo automático; 0 = manual (bomba forçada OFF) |
| **Saída** | `pump_on` | 1 bit | 1 = relé/bomba ligada |
| **Saída** | `solenoid_open` | 1 bit | 1 = válvula aberta (reabastecer) |
| **Saída** | `led_green` | 1 bit | Espelha `pump_on` |
| **Saída** | `led_red` | 1 bit | Inverso de `pump_on` |
| **Saída** | `fault` | 1 bit | Sempre 0 nesta versão (para compatibilidade) |

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

## Pinout / LPF (Colorlight i9)

O arquivo `colorlight_i9.lpf` deve ter **os mesmos nomes** dos sinais do `pump_controller_simple.sv`. 
Geramos um esqueleto com todos os `LOCATE` e `IOBUF` para você apenas preencher os `SITE` corretos da PCB.

> Importante: os sensores são **ativos em nível baixo** em hardware. O módulo já lida com isso via parâmetro `INVERT_LEVEL_CODE` (coloque `1` se for necessário inverter o código 0..4).

Arquivos auxiliares:
- `colorlight_i9_updated.lpf` — esqueleto gerado automaticamente com todos os sinais.

## Conformidade com o Prompt_v2

- Reset **síncrono** ativo-baixo (`rst_n`).
- Condições de partida/parada exatamente como descritas.
- `en_auto=0` força **IDLE** imediatamente.
- Parâmetro `INVERT_LEVEL_CODE` para compatibilidade com sensores ativos-baixo.
- (Pendentes, por opção): debounce e estado `FAULT`.