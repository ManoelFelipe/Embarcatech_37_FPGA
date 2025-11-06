// transistor_sensor_test.sv
module transistor_sensor_test (
    // Vai a 0V quando o transistor satura (sensor molhado)
    input  logic sensor_col_n, //C1 no ipf

    // LED na placa (pino D1): 1 = aceso
    output logic led_d1 //D1 no ipf
);

    // Converte de ativo-baixo (0=molhado) para ativo-alto
    logic sensor_wet;
    assign sensor_wet = ~sensor_col_n;

    // Acende o LED quando estiver molhado
    assign led_d1 = sensor_wet;

    // Se quiser também expor um comando de bomba depois:
    // output logic pump_on
    // assign pump_on = sensor_wet;

endmodule

