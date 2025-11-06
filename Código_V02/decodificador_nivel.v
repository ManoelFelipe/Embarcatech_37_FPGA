/*
 * Módulo: decodificador_nivel
 * Converte o nível dos sensores (LÓGICA INVERTIDA: 0=água) em display ('0'-'4').
 * Implementa um codificador de prioridade para nível MAIS ALTO ativo (em '0').
 */
module decodificador_nivel(
    input  [4:0] sensores_in, // Agora, 0 = Água Presente, 1 = Sem Água
    output reg [6:0] display_out
);

    // Mapeamento dos segmentos (sem alterações)
    localparam DISP_0 = 7'b0111111; // "0"
    localparam DISP_1 = 7'b0000110; // "1"
    localparam DISP_2 = 7'b1011011; // "2"
    localparam DISP_3 = 7'b1001111; // "3"
    localparam DISP_4 = 7'b1100110; // "4"

    always @(*) begin
        // Verifica do nível mais alto para o mais baixo qual está ativo (em '0')
        if (!sensores_in[4])      // Se o sensor de 100% está em '0' (com água)
            display_out = DISP_4; // exibe "4"
        else if (!sensores_in[3]) // Se o sensor de 75% está em '0'
            display_out = DISP_3; // exibe "3"
        else if (!sensores_in[2]) // Se o sensor de 50% está em '0'
            display_out = DISP_2; // exibe "2"
        else if (!sensores_in[1]) // Se o sensor de 25% está em '0'
            display_out = DISP_1; // exibe "1"
        else if (!sensores_in[0])                     // Se nenhum sensor (exceto 0%) está em '0'
            display_out = DISP_0; // exibe "0" (Pode exibir 0 mesmo se 0% for 0, está correto)
    end

endmodule