// transistor_sensor_test_tb.sv
`timescale 1ns/1ps
`default_nettype none

module transistor_sensor_test_tb;

    logic sensor0_n, sensor1_n, sensor2_n, sensor3_n, sensor4_n;
    wire  led0,     led1,     led2,     led3,     led4;

    // DUT
    transistor_sensor_test dut (
        .sensor0_n(sensor0_n),
        .sensor1_n(sensor1_n),
        .sensor2_n(sensor2_n),
        .sensor3_n(sensor3_n),
        .sensor4_n(sensor4_n),
        .led0(led0), .led1(led1), .led2(led2), .led3(led3), .led4(led4)
    );

    // Aplicador + checagem
    task automatic apply_and_check(input logic [4:0] s_n);
        begin
            {sensor4_n, sensor3_n, sensor2_n, sensor1_n, sensor0_n} = s_n;
            #10;
            // Esperado: leds = ~s_n
            assert ({led4,led3,led2,led1,led0} == ~s_n)
                else $fatal(1, "Mismatch: sensors_n=%b leds=%b (esperado=%b)",
                            s_n, {led4,led3,led2,led1,led0}, ~s_n);
            $display("[%0t] OK  sensors_n=%b  leds=%b",
                     $time, s_n, {led4,led3,led2,led1,led0});
        end
    endtask

    initial begin
        // 1 = seco (entrada alta); 0 = molhado (ativo-baixo)
        apply_and_check(5'b11111); // todos secos
        apply_and_check(5'b01111); // sensor0 molhado
        apply_and_check(5'b10111); // sensor1 molhado
        apply_and_check(5'b11011); // sensor2 molhado
        apply_and_check(5'b11101); // sensor3 molhado
        apply_and_check(5'b11110); // sensor4 molhado
        apply_and_check(5'b00000); // todos molhados
        apply_and_check(5'b11001); // caso misto
        $display("Teste finalizado com sucesso.");
        #10 $finish;
    end

endmodule
