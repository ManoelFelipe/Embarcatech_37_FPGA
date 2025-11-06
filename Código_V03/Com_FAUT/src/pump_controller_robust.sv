
// ============================================================================
// pump_controller_robust.sv
// Pump controller with input synchronization/debounce and basic fault handling.
// - Debounce for lvl_inf/lvl_sup (3-bit codes) and en_auto (1-bit)
// - FSM with IDLE, PUMPING, FAULT (latched until reset)
// - Start: en_auto==1 && (lvl_sup==25%) && (lvl_inf==75%)
// - Stop:  (lvl_inf<=25%) || (lvl_sup>=75%) || (en_auto==0)
// - Faults (latched):
//   * Invalid code (>4) on any debounced level
//   * Overflow protection: pump_on && (lvl_sup==100%)
//   * Dry-run protection:  pump_on && (lvl_inf==0%)
//   * Unrealistic jump: abs(delta level) > MAX_STEP in one debounced update
// - Solenoid: open while lvl_inf<100% (close at 100%)
// Author: ChatGPT
// ============================================================================

`timescale 1ns/1ps

module pump_controller_robust #(
  parameter int unsigned CLK_HZ          = 25_000_000,
  parameter int unsigned DEBOUNCE_MS     = 20,          // typical push-button scale
  parameter int unsigned MAX_STEP        = 2,           // max allowed jump per update (0..4 scale)
  // Thresholds (encoded 0..4 => 0,25,50,75,100%)
  parameter logic [2:0]  LVL_SUP_START   = 3'd1, // 25%
  parameter logic [2:0]  LVL_INF_START   = 3'd3, // 75%
  parameter logic [2:0]  LVL_SUP_STOP    = 3'd3, // 75%
  parameter logic [2:0]  LVL_INF_STOP    = 3'd1, // 25%
  parameter logic [2:0]  LVL_INF_REFILL  = 3'd4  // 100%
)(
  input  logic        clk,
  input  logic        rst_n,       // synchronous, active-low

  // Raw (asynchronous) inputs from sensors/UI
  input  logic [2:0]  lvl_inf_raw, // 0..4 => 0,25,50,75,100%
  input  logic [2:0]  lvl_sup_raw, // 0..4 => 0,25,50,75,100%
  input  logic        en_auto_raw, // 1=automatic, 0=manual(off)

  // Outputs
  output logic        pump_on,
  output logic        solenoid_open,
  output logic        led_green,
  output logic        led_red,
  output logic        fault_latched
);

  // ---------------------------------------------------------------------------
  // Synchronizers (2FF) for async inputs
  // ---------------------------------------------------------------------------
  logic [2:0] lvl_inf_sync1, lvl_inf_sync2;
  logic [2:0] lvl_sup_sync1, lvl_sup_sync2;
  logic       en_auto_sync1, en_auto_sync2;

  always_ff @(posedge clk) begin
    {lvl_inf_sync1, lvl_sup_sync1, en_auto_sync1} <= {lvl_inf_raw, lvl_sup_raw, en_auto_raw};
    {lvl_inf_sync2, lvl_sup_sync2, en_auto_sync2} <= {lvl_inf_sync1, lvl_sup_sync1, en_auto_sync1};
  end

  // ---------------------------------------------------------------------------
  // Debounce for bus (lvl_inf/lvl_sup) and bit (en_auto)
  // Strategy: update stable value only if sampled value remains equal for
  //           DEBOUNCE_CYC consecutive cycles.
  // ---------------------------------------------------------------------------
  localparam int unsigned DEBOUNCE_CYC = (CLK_HZ/1000) * DEBOUNCE_MS;

  // Generic bus debouncer (3-bit)
  function automatic logic [2:0] bus_mux(input logic [2:0] a); bus_mux = a; endfunction

  logic [2:0] lvl_inf_db, lvl_sup_db;
  logic [2:0] lvl_inf_prev_db, lvl_sup_prev_db; // for step check
  logic [$clog2(DEBOUNCE_CYC+1)-1:0] cnt_inf, cnt_sup;
  logic [2:0] samp_inf, samp_sup;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      samp_inf <= '0; cnt_inf <= '0; lvl_inf_db <= '0; lvl_inf_prev_db <= '0;
    end else begin
      if (lvl_inf_sync2 == samp_inf) begin
        if (cnt_inf < DEBOUNCE_CYC) cnt_inf <= cnt_inf + 1'b1;
      end else begin
        samp_inf <= lvl_inf_sync2;
        cnt_inf  <= '0;
      end
      if (cnt_inf == DEBOUNCE_CYC) begin
        if (lvl_inf_db != samp_inf) lvl_inf_prev_db <= lvl_inf_db;
        lvl_inf_db <= samp_inf;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      samp_sup <= '0; cnt_sup <= '0; lvl_sup_db <= '0; lvl_sup_prev_db <= '0;
    end else begin
      if (lvl_sup_sync2 == samp_sup) begin
        if (cnt_sup < DEBOUNCE_CYC) cnt_sup <= cnt_sup + 1'b1;
      end else begin
        samp_sup <= lvl_sup_sync2;
        cnt_sup  <= '0;
      end
      if (cnt_sup == DEBOUNCE_CYC) begin
        if (lvl_sup_db != samp_sup) lvl_sup_prev_db <= lvl_sup_db;
        lvl_sup_db <= samp_sup;
      end
    end
  end

  // 1-bit debouncer for en_auto
  logic en_auto_db;
  logic [$clog2(DEBOUNCE_CYC+1)-1:0] cnt_auto;
  logic samp_auto;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      samp_auto <= 1'b0; cnt_auto <= '0; en_auto_db <= 1'b0;
    end else begin
      if (en_auto_sync2 == samp_auto) begin
        if (cnt_auto < DEBOUNCE_CYC) cnt_auto <= cnt_auto + 1'b1;
      end else begin
        samp_auto <= en_auto_sync2;
        cnt_auto  <= '0;
      end
      if (cnt_auto == DEBOUNCE_CYC) en_auto_db <= samp_auto;
    end
  end

  // ---------------------------------------------------------------------------
  // Start/stop conditions (on debounced values)
  // ---------------------------------------------------------------------------
  logic start_cond, stop_cond;
  assign start_cond = (lvl_sup_db == LVL_SUP_START) && (lvl_inf_db == LVL_INF_START);
  assign stop_cond  = (lvl_inf_db <= LVL_INF_STOP)  || (lvl_sup_db >= LVL_SUP_STOP);

  // ---------------------------------------------------------------------------
  // Fault logic (latched until reset)
  // ---------------------------------------------------------------------------
  logic fault_now;
  function automatic int abs3(input int a); abs3 = (a < 0) ? -a : a; endfunction

  // invalid codes
  logic invalid_inf = (lvl_inf_db > 3'd4);
  logic invalid_sup = (lvl_sup_db > 3'd4);

  // unrealistic jumps when debounced value updates
  int step_inf, step_sup;
  always_comb begin
    step_inf = abs3(int'(lvl_inf_db) - int'(lvl_inf_prev_db));
    step_sup = abs3(int'(lvl_sup_db) - int'(lvl_sup_prev_db));
  end
  logic jump_inf = (step_inf > MAX_STEP);
  logic jump_sup = (step_sup > MAX_STEP);

  // overflow / dry-run protection (only meaningful when pump_on)
  logic overflow_sup = pump_on && (lvl_sup_db == 3'd4);
  logic dry_inf      = pump_on && (lvl_inf_db == 3'd0);

  always_comb begin
    fault_now = invalid_inf || invalid_sup || jump_inf || jump_sup || overflow_sup || dry_inf;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) fault_latched <= 1'b0;
    else if (fault_now) fault_latched <= 1'b1;
  end

  // ---------------------------------------------------------------------------
  // FSM
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] { IDLE=2'b00, PUMPING=2'b01, FAULT=2'b10 } state_t;
  state_t state, state_n;

  always_comb begin
    state_n = state;
    unique case (state)
      IDLE: begin
        if (fault_latched)      state_n = FAULT;
        else if (en_auto_db && start_cond) state_n = PUMPING;
      end
      PUMPING: begin
        if (fault_latched)            state_n = FAULT;
        else if (!en_auto_db)         state_n = IDLE;
        else if (stop_cond)           state_n = IDLE;
      end
      FAULT: begin
        // latched until reset
        state_n = FAULT;
      end
      default: state_n = IDLE;
    endcase
  end

  always_ff @(posedge clk) begin
    if (!rst_n) state <= IDLE;
    else        state <= state_n;
  end

  // ---------------------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------------------
  always_comb begin
    pump_on        = (state == PUMPING);
    solenoid_open  = (lvl_inf_db < LVL_INF_REFILL); // refill until 100%
    led_green      = pump_on && !fault_latched;
    led_red        = ~pump_on || fault_latched;     // red ON if idle or fault
  end

endmodule
