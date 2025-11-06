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
//  - Versão "simple" com dois displays de 7 segmentos (um p/ cada tanque).
//  - Acrescenta duas saídas de 7 segmentos: seg_inf[6:0], seg_sup[6:0].
//  - Mostra 1..5 conforme o nível discreto (0%,25%,50%,75%,100%).
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

module pump_controller_simple
#(
    // ------------------------------ Parâmetros ------------------------------
    parameter int CLK_HZ           = 25_000_000,   // frequência de clock (não usada aqui)
    parameter      INVERT_LEVEL_CODE = 1'b0,       // 1 = inverte código 0..4 vindo do hardware
    parameter [2:0] LVL_SUP_START  = 3'd1,         // 25%
    parameter [2:0] LVL_INF_START  = 3'd3,         // 75%
    parameter [2:0] LVL_SUP_STOP   = 3'd3,         // 75%
    parameter [2:0] LVL_INF_STOP   = 3'd1,         // 25%
    parameter [2:0] LVL_INF_REFILL = 3'd4,         // 100%
    // Polaritidade dos segmentos (para o seu 5011AS, comum-cátodo => ativo-alto)
    parameter      SEG_ACTIVE_HIGH  = 1'b1         // 1 = '1' acende segmento; 0 = '0' acende
) (
    // ------------------------------ Entradas -------------------------------
    input  logic        clk,          // clock do sistema
    input  logic        rst_n,        // reset síncrono ativo-baixo
    input  logic [2:0]  lvl_inf,      // nível do tanque inferior: 0..4
    input  logic [2:0]  lvl_sup,      // nível do tanque superior: 0..4
    input  logic        en_auto,      // 1 = modo automático, 0 = manual (bomba OFF)

    // ------------------------------ Saídas ---------------------------------
    output logic        pump_on,      // 1 = liga relé/bomba
    output logic        solenoid_open,// 1 = abre válvula (reabastecer tanque inferior)
    output logic        led_green,    // espelha pump_on
    output logic        led_red,      // inverso de pump_on
    output logic        fault,        // sempre 0 nesta versão "simple"

    // Novas saídas: dois displays de 7 segmentos (a..g)
    output logic [6:0]  seg_inf,      // display do tanque inferior (1..5)
    output logic [6:0]  seg_sup       // display do tanque superior (1..5)
);

    // =========================================================================
    // Normalização de nível (compatibilidade com sensores ativos-baixo)
    // Se INVERT_LEVEL_CODE==1, espelha o código 0..4 (ex.: 0->4, 1->3, 2->2, 3->1, 4->0).
    // Isso mantém a semântica "0=0%" ... "4=100%" dentro do módulo.
    // =========================================================================
    function automatic logic [2:0] normalize_level(input logic [2:0] raw);
        if (INVERT_LEVEL_CODE) begin
            normalize_level = 3'd4 - raw;   // espelhamento simples no intervalo [0..4]
        end else begin
            normalize_level = raw;
        end
    endfunction

    // Valores normalizados para uso interno
    logic [2:0] lvl_inf_n;  // nível inferior normalizado
    logic [2:0] lvl_sup_n;  // nível superior normalizado

    always_comb begin
        lvl_inf_n = normalize_level(lvl_inf);  // aplica normalização conforme parâmetro
        lvl_sup_n = normalize_level(lvl_sup);  // idem
    end

    // =========================================================================
    // Máquina de Estados Finita (FSM) de 2 estados: IDLE / PUMPING
    // Sem debounce/FAULT conforme "simple".
    // =========================================================================
    typedef enum logic [0:0] {
        IDLE    = 1'b0,     // bomba desligada
        PUMPING = 1'b1      // bomba ligada
    } state_t;

    state_t state, state_n; // estado atual e próximo estado

    // Condições de partida e parada conforme Prompt
    logic start_cond;       // condição para ligar a bomba
    logic stop_cond;        // condição para desligar a bomba

    always_comb begin
        // Liga somente se: sup==LVL_SUP_START E inf==LVL_INF_START
        start_cond = (lvl_sup_n == LVL_SUP_START) && (lvl_inf_n == LVL_INF_START);

        // Desliga se: inf<=LVL_INF_STOP OU sup>=LVL_SUP_STOP
        stop_cond  = (lvl_inf_n <= LVL_INF_STOP) || (lvl_sup_n >= LVL_SUP_STOP);
    end

    // Próximo estado (com histerese inerente)
    always_comb begin
        state_n = state;                 // padrão: mantém
        unique case (state)
            IDLE: begin
                if (en_auto && start_cond) begin
                    state_n = PUMPING;   // entra bombeando
                end
            end
            PUMPING: begin
                if (!en_auto || stop_cond) begin
                    state_n = IDLE;      // força parada ou condição de parada
                end
            end
        endcase
    end

    // Registrador de estado (reset síncrono ativo-baixo)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;               // volta para repouso
        end else begin
            state <= state_n;            // avança
        end
    end

    // Saídas relacionadas à bomba/LEDs/válvula
    always_comb begin
        pump_on       = (state == PUMPING);          // liga quando em PUMPING
        led_green     = pump_on;                     // verde espelha
        led_red       = ~pump_on;                    // vermelho é o inverso
        fault         = 1'b0;                        // sem tratamento de falha aqui

        // Válvula aberta enquanto nível inferior < LVL_INF_REFILL
        solenoid_open = (lvl_inf_n < LVL_INF_REFILL);
    end

    // =========================================================================
    // Encoder de 7 segmentos (SEM multiplexação):
    // - Exibe dígitos 1..5 conforme tabela solicitada.
    // - Qualquer valor fora de 0..4 gera 'E' (Erro) para facilitar debug.
    //
    // Mapeamento pedido:
    //  lvl == 0  -> mostrar 1
    //  lvl == 1  -> mostrar 2
    //  lvl == 2  -> mostrar 3
    //  lvl == 3  -> mostrar 4
    //  lvl == 4  -> mostrar 5
    //
    // Convenção de bits: [6:0] = {a,b,c,d,e,f,g}
    // Padrões abaixo são para "ativo-alto". Se SEG_ACTIVE_HIGH==0, invertemos.
    // =========================================================================

    // Constantes de dígitos (ativo-alto): a,b,c,d,e,f,g
    localparam logic [6:0] SEG_0 = 7'b1111110; // 0 (não usado, referência)
    localparam logic [6:0] SEG_1 = 7'b0110000; // 1
    localparam logic [6:0] SEG_2 = 7'b1101101; // 2
    localparam logic [6:0] SEG_3 = 7'b1111001; // 3
    localparam logic [6:0] SEG_4 = 7'b0110011; // 4
    localparam logic [6:0] SEG_5 = 7'b1011011; // 5
    localparam logic [6:0] SEG_E = 7'b1101111; // 'E' (erro/fora da faixa)

    // Função: aplica polaridade ao padrão ativo-alto
    function automatic logic [6:0] seg_apply_polarity(input logic [6:0] pat_ah);
        seg_apply_polarity = (SEG_ACTIVE_HIGH) ? pat_ah : ~pat_ah;
    endfunction

    // Converte nível discreto (0..4) -> dígito 1..5 no 7-seg
    function automatic logic [6:0] seg_from_level(input logic [2:0] lvl_n);
        unique case (lvl_n)
            3'd0: seg_from_level = seg_apply_polarity(SEG_1); // 0% -> "1"
            3'd1: seg_from_level = seg_apply_polarity(SEG_2); // 25% -> "2"
            3'd2: seg_from_level = seg_apply_polarity(SEG_3); // 50% -> "3"
            3'd3: seg_from_level = seg_apply_polarity(SEG_4); // 75% -> "4"
            3'd4: seg_from_level = seg_apply_polarity(SEG_5); // 100%-> "5"
            default: seg_from_level = seg_apply_polarity(SEG_E); // segurança
        endcase
    endfunction

    // Atualiza os dois displays sempre que níveis mudarem
    always_comb begin
        seg_inf = seg_from_level(lvl_inf_n); // display do tanque inferior
        seg_sup = seg_from_level(lvl_sup_n); // display do tanque superior
    end

endmodule
