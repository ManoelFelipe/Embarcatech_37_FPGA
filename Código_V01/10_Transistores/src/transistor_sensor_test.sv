// transistor_sensor5.sv
`default_nettype none
module transistor_sensor_test (
    // Entradas (coletores, ativo-baixo: 0 = molhado)
    input  logic sensor0_n,
    input  logic sensor1_n,
    input  logic sensor2_n,
    input  logic sensor3_n,
    input  logic sensor4_n,

    // Saídas (para LEDs / lógica de bomba, 1 = aceso/ativo)
    output logic led0,
    output logic led1,
    output logic led2,
    output logic led3,
    output logic led4
);

    // Versão compacta: cada LED = ~sensor*_n
    assign {led4,  led3,  led2,  led1,  led0} =
           ~{sensor4_n, sensor3_n, sensor2_n, sensor1_n, sensor0_n};

endmodule

