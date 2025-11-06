/*
 * Módulo: controlador_caixa_dagua
 * Unidade de controle principal AUTOMÁTICA com LÓGICA DE SENSOR INVERTIDA.

 */
module controlador_caixa_dagua(
input wire clk,
input wire reset,
input wire [4:0] sensores_inf, // Agora, 0 = Água Presente, 1 = Sem Água
input wire [4:0] sensores_sup, // Agora, 0 = Água Presente, 1 = Sem Água

output wire bomba,
output reg valvula,
output wire led_vermelho,
output wire led_verde,
output wire [6:0] display_inf,
output wire [6:0] display_sup
);

// Definição dos Estados da FSM (sem alterações)
localparam [1:0] S_VAZIA = 2'b00;
localparam [1:0] S_CHEIA = 2'b01;
localparam [1:0] S_ESVAZIANDO = 2'b10;

// Sinais Internos (sem alterações)
reg [1:0] estado_atual, proximo_estado;
reg bomba_internal;

// Instanciação dos Decodificadores (sem alterações)
decodificador_nivel DECODER_INF (
.sensores_in(sensores_inf),
.display_out(display_inf)
);
decodificador_nivel DECODER_SUP (
.sensores_in(sensores_sup),
.display_out(display_sup)
);

// === Lógica da FSM ===

// Bloco 1: Registrador de Estado (Sequencial) - Sem alterações
always @(posedge clk or posedge reset) begin
    estado_atual <= proximo_estado;
end

// Bloco 2: Lógica de Próximo Estado (Combinacional) - LÓGICA INVERTIDA
always @(*) begin
    proximo_estado = estado_atual; // Padrão: permanecer no estado

    case (estado_atual)
        S_VAZIA:
        // Transição SE sensor Inf 100% está em '0' (com água)
        if ((!sensores_inf[3] && !sensores_inf[2] && !sensores_inf[1] && !sensores_inf[0]) && (sensores_inf[4] || !sensores_inf[4]))
        proximo_estado = S_CHEIA;
            S_CHEIA:
            // Transição SE sensor Inf 100% está em '0' (com água)
            // E SE sensor Sup 25% está em '1' (SEM água)
            if (!sensores_sup[0] && sensores_sup[1] && !sensores_inf[3])
            proximo_estado = S_ESVAZIANDO;
            S_ESVAZIANDO:
            // Transição SE sensor Sup 100% está em '0' (com água)
            // OU SE sensor Inf 25% está em '1' (SEM água)
            if (!sensores_sup[3] || (!sensores_inf[0] && sensores_inf[1] && sensores_inf[2] && sensores_inf[3] && sensores_inf[4]))
                proximo_estado = S_VAZIA;
            // default:
            // proximo_estado = S_VAZIA;
    endcase
end

 // Bloco 3: Lógica de Saída da FSM (Combinacional - Moore) - CORRIGIDO
always @(*) begin
    // --- DEFINA OS PADRÕES AQUI ---
    // Isso garante que nunca haverá um latch
    // bomba_internal = 1'b0; 
    // valvula = 1'b0; // Bomba e válvula desligadas por padrão
    case (estado_atual)
        S_VAZIA: begin
        // (Já é 1'b0, mas pode ser explícito se quiser)
            bomba_internal = 1'b0; 
            valvula = 1'b0;
        end
        S_CHEIA: begin
            // bomba_internal = 1'b0; // (Já é o padrão)
            valvula = 1'b1; // Ligar válvula
        end
        S_ESVAZIANDO: begin
            bomba_internal = 1'b1; // Ligar bomba
        // valvula = 1'b0; // (Já é o padrão)
        end
        // O 'default' (para 2'b11) agora usa os padrões definidos acima
    endcase
end

 // Atribuições contínuas para as saídas físicas - Sem alterações
 assign bomba = bomba_internal;
 assign led_verde = bomba_internal;
 assign led_vermelho = !bomba_internal;

endmodule
