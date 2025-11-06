// ============================================================================
// pump_controller_simple.sv
// Simplified pump controller FSM (sem debounce, sem estado de falha por enquanto)
// Base da especificação (Prompt_v2):
//  - Partida: liga se (lvl_sup == LVL_SUP_START) E (lvl_inf == LVL_INF_START).
//  - Parada: desliga se (lvl_inf <= LVL_INF_STOP) OU (lvl_sup >= LVL_SUP_STOP).
//  - Solenoide: aberta enquanto lvl_inf < LVL_INF_REFILL (fecha ao atingir).
//  - LEDs: led_green = pump_on; led_red = ~pump_on.
//  - Reset: síncrono, ativo em nível baixo (rst_n).
//  - Modo manual: se en_auto = 0, força IDLE imediatamente.
//  - Compatibilidade com sensores ativos em nível baixo: INVERT_LEVEL_CODE
// ----------------------------------------------------------------------------
// Data: 28/10/2025
// Autores: Yasmin / ChatGPT
// Nota sobre sensores:
//   Em bancada, os sensores (transistores) são ativos em nível baixo (coletor ~0V = molhado).
//   Para manter a semântica 0=0% ... 4=100%, este módulo oferece o parâmetro
//   INVERT_LEVEL_CODE que aplica internamente a transformação: lvl_eff = 4 - lvl_in.
// ============================================================================

`timescale 1ns/1ps

module pump_controller_simple_sem_Display #(
  parameter int unsigned CLK_HZ           = 25_000_000,
  // Parâmetros de thresholds (0..4 => 0,25,50,75,100%)
  parameter logic [2:0] LVL_SUP_START     = 3'd1, // 25% no superior para poder iniciar
  parameter logic [2:0] LVL_INF_START     = 3'd3, // 75% no inferior para poder iniciar
  parameter logic [2:0] LVL_INF_STOP      = 3'd1, // <=25% no inferior => parar
  parameter logic [2:0] LVL_SUP_STOP      = 3'd3, // >=75% no superior => parar
  parameter logic [2:0] LVL_INF_REFILL    = 3'd4, // válvula fecha quando atingir 100%
  // Compatibilidade com sensores ativos-baixo
  parameter bit         INVERT_LEVEL_CODE = 1'b0
  // Futuro (Prompt_v2): FILTER_MS, FAULT_RECOVERY_MS (não implementados neste arquivo simples)
)(
  input  logic        clk,
  input  logic        rst_n,      // reset síncrono, ativo baixo
  input  logic        en_auto,

  // Entradas de nível codificadas (0..4)
  input  logic [2:0]  lvl_inf,
  input  logic [2:0]  lvl_sup,

  // Saídas
  output logic        pump_on,
  output logic        solenoid_open,
  output logic        led_green,
  output logic        led_red,
  output logic        fault
);


  // ------------------------- Normalização de nível ---------------------------
  // Se INVERT_LEVEL_CODE=1, fazemos lvl_eff = 4 - lvl
  logic [2:0] lvl_inf_eff, lvl_sup_eff;
  always_comb begin
    if (INVERT_LEVEL_CODE) begin
      lvl_inf_eff = 3'd4 - lvl_inf;
      lvl_sup_eff = 3'd4 - lvl_sup;
    end else begin
      lvl_inf_eff = lvl_inf;
      lvl_sup_eff = lvl_sup;
    end
  end

  // ----------------------------- FSM Simples --------------------------------
  typedef enum logic [0:0] { IDLE=1'b0, PUMPING=1'b1 } state_t;
  state_t state = IDLE, state_n; // inicializa FSM em IDLE no power-up

  // Próximo estado
  always_comb begin
    // Modo manual força IDLE
    if (!en_auto) begin
      state_n = IDLE;
    end else begin
      state_n = state;
      unique case (state)
        IDLE: begin
          // Início somente quando níveis atendem às condições
          if ((lvl_sup_eff == LVL_SUP_START) &&
              (lvl_inf_eff == LVL_INF_START)) begin
            state_n = PUMPING;
          end
        end

        PUMPING: begin
          // Parada por inferior baixo OU superior alto
          if ((lvl_inf_eff <= LVL_INF_STOP) ||
              (lvl_sup_eff >= LVL_SUP_STOP)) begin
            state_n = IDLE;
          end
        end
      endcase
    end
  end

  // Estado (RESET SÍNCRONO, ativo baixo)
  always_ff @(posedge clk) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= state_n;
  end

  // ---- Saídas ---------------------------------------------------------------
  always_comb begin
    pump_on       = (state == PUMPING);
    solenoid_open = (lvl_inf_eff < LVL_INF_REFILL); // aberta até atingir o nível-alvo
    led_green     = pump_on;
    led_red       = ~pump_on;

    // Versão simples: sem tratamento de falha
    fault         = 1'b0;
  end

endmodule
