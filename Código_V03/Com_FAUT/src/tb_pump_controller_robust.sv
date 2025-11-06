
// ============================================================================
// tb_pump_controller_robust.sv
// Simple scenarios verifying debounce, start/stop, and fault latch.
// Note: Short DEBOUNCE_MS for fast sim.
// ============================================================================
`timescale 1ns/1ps

module tb_pump_controller_robust;

  // Clock 100 MHz
  logic clk = 0;
  always #5 clk = ~clk;

  // DUT wires
  logic        rst_n;
  logic [2:0]  lvl_inf_raw, lvl_sup_raw;
  logic        en_auto_raw;
  logic        pump_on, solenoid_open, led_green, led_red, fault_latched;

  localparam int CLK_HZ_SIM = 100_000_000;

  pump_controller_robust #(
    .CLK_HZ(CLK_HZ_SIM),
    .DEBOUNCE_MS(1),      // fast for sim
    .MAX_STEP(3)          // allow larger jumps here to demo faults when >3
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .lvl_inf_raw(lvl_inf_raw),
    .lvl_sup_raw(lvl_sup_raw),
    .en_auto_raw(en_auto_raw),
    .pump_on(pump_on),
    .solenoid_open(solenoid_open),
    .led_green(led_green),
    .led_red(led_red),
    .fault_latched(fault_latched)
  );

  task step(input int n=1); repeat(n) @(posedge clk); endtask
  task set_levels(input int li, input int ls);
    lvl_inf_raw = li[2:0];
    lvl_sup_raw = ls[2:0];
  endtask

  initial begin
    // Reset
    rst_n = 0; en_auto_raw = 0; lvl_inf_raw = 0; lvl_sup_raw = 0;
    step(5); rst_n = 1; step(5);

    // Enable automatic
    en_auto_raw = 1; step(2);

    // Debounce behavior: toggle raw quickly around target; should require stability
    // Bounce around 75%/25%
    set_levels(3, 1); // exact (75,25)
    step(2);
    // After debounce time, pump should start
    step(200);
    assert(pump_on) else $fatal("Pump should be ON after debounced start condition");

    // Stop due to sup >= 75
    set_levels(3, 3); step(200);
    assert(!pump_on) else $fatal("Pump should have stopped on sup>=75");

    // Start again
    set_levels(3, 1); step(200);
    assert(pump_on) else $fatal("Pump should start again");

    // Fault: dry-run (inf==0 while pumping)
    set_levels(0, 1); step(200);
    assert(fault_latched) else $fatal("Fault should latch on dry-run");
    assert(!pump_on) else $fatal("Pump must be OFF in FAULT");

    // Reset to clear fault
    rst_n = 0; step(5); rst_n = 1; step(10);

    // Fault: overflow (sup==100 while pumping)
    en_auto_raw = 1; set_levels(3,1); step(200); // start
    assert(pump_on);
    set_levels(3,4); step(200);                  // overflow
    assert(fault_latched);

    $display("Robust TB finished.");
    $finish;
  end

endmodule
