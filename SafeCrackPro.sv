// ============================================================================
//  SafeCrack Pro
//  CIN0130 - Sistemas Digitais  |  DE2-115 (Cyclone IV E)
// ----------------------------------------------------------------------------
//  Top-level da FSM. O usuário compõe uma senha de 4 dígitos (0-9) navegando
//  com os push-buttons. Cada dígito é confirmado individualmente; ao confirmar
//  o quarto dígito o sistema verifica a senha e dá feedback pelos LEDs.
//
//  Mapeamento dos displays:
//    HEX3 = 1o digito   HEX2 = 2o digito   HEX1 = 3o digito   HEX0 = 4o digito
//    HEX4 = indice do digito ativo (1 a 4)
//
//  Push-buttons (ativos em nivel BAIXO, ja com debounce em hardware na placa):
//    KEY[3] -> seta esquerda  : decrementa o digito ativo (wrap 0 -> 9)
//    KEY[2] -> seta direita   : incrementa o digito ativo (wrap 9 -> 0)
//    KEY[1] -> confirma       : fixa o digito e avanca; no 4o, verifica a senha
//    KEY[0] -> reset          : volta ao estado inicial
//
//  Feedback:
//    Senha correta   -> todos os LEDs VERDES acesos por 5 s, depois reseta
//    Senha incorreta -> todos os LEDs VERMELHOS acesos por 3 s, depois reseta
// ============================================================================

module SafeCrackPro #(
    // ----- Senha correta (cada digito de 0 a 9). HEX3 = PASS0 = primeiro digito.
    parameter logic [3:0] PASS0 = 4'd1,
    parameter logic [3:0] PASS1 = 4'd2,
    parameter logic [3:0] PASS2 = 4'd3,
    parameter logic [3:0] PASS3 = 4'd4,

    // ----- Duracao do feedback, em ciclos de clock (clock de 50 MHz).
    //       5 s = 250.000.000 ciclos ; 3 s = 150.000.000 ciclos.
    //       Sao parametros para que a simulacao possa usar valores pequenos.
    parameter int OPEN_CYCLES  = 250_000_000,  // 5 segundos
    parameter int WRONG_CYCLES = 150_000_000   // 3 segundos
)(
    input  logic        CLOCK_50,        // clock de 50 MHz da DE2-115
    input  logic [3:0]  KEY,             // push-buttons (ativos em nivel baixo)
    output logic [6:0]  HEX0,            // 4o digito
    output logic [6:0]  HEX1,            // 3o digito
    output logic [6:0]  HEX2,            // 2o digito
    output logic [6:0]  HEX3,            // 1o digito
    output logic [6:0]  HEX4,            // indice do digito ativo
    output logic [8:0]  LEDG,            // LEDs verdes  (sucesso)
    output logic [17:0] LEDR             // LEDs vermelhos (falha)
);

    // ------------------------------------------------------------------------
    //  Estados da FSM
    //    EDIT0..EDIT3 : editando o 1o, 2o, 3o e 4o digito respectivamente
    //    VERIFY       : compara a senha digitada com a correta
    //    UNLOCKED     : senha correta  -> LEDs verdes por OPEN_CYCLES
    //    WRONG        : senha incorreta -> LEDs vermelhos por WRONG_CYCLES
    // ------------------------------------------------------------------------
    typedef enum logic [2:0] {
        EDIT0, EDIT1, EDIT2, EDIT3, VERIFY, UNLOCKED, WRONG
    } state_t;

    state_t      state;          // estado atual
    logic [3:0]  dig [0:3];      // os quatro digitos (dig[0] = primeiro = HEX3)
    logic [31:0] timer;          // contador para os tempos de feedback

    // ------------------------------------------------------------------------
    //  Deteccao de borda dos botoes
    //  Os botoes sao ativos em nivel baixo: "solto" = 1, "pressionado" = 0.
    //  Um pressionamento e a borda de descida (1 -> 0). Guardamos o valor
    //  anterior (key_d) e geramos um pulso de 1 ciclo por pressionamento,
    //  garantindo UMA acao por clique mesmo que o botao fique segurado.
    // ------------------------------------------------------------------------
    logic [3:0] key_d; // detecção de borda
    wire  [3:0] key_press = key_d & ~KEY;   // 1 onde houve borda de descida

    // ------------------------------------------------------------------------
    //  Logica sincrona principal (estado + datapath)
    // ------------------------------------------------------------------------
    always_ff @(posedge CLOCK_50) begin
        key_d <= KEY;                       // registra o valor anterior dos botoes

        if (!KEY[0]) begin
            // -------- RESET (KEY[0]) : volta ao estado inicial -----------
            state <= EDIT0;
            dig[0] <= 4'd0; dig[1] <= 4'd0; dig[2] <= 4'd0; dig[3] <= 4'd0;
            timer  <= 32'd0;
        end
        else begin
            case (state)
                // ---- Edicao do 1o digito ----
                EDIT0: begin
                    if      (key_press[2]) dig[0] <= (dig[0]==4'd9) ? 4'd0 : dig[0] + 4'd1;
                    else if (key_press[3]) dig[0] <= (dig[0]==4'd0) ? 4'd9 : dig[0] - 4'd1;
                    if (key_press[1]) state <= EDIT1;       // confirma -> proximo
                end

                // ---- Edicao do 2o digito ----
                EDIT1: begin
                    if      (key_press[2]) dig[1] <= (dig[1]==4'd9) ? 4'd0 : dig[1] + 4'd1;
                    else if (key_press[3]) dig[1] <= (dig[1]==4'd0) ? 4'd9 : dig[1] - 4'd1;
                    if (key_press[1]) state <= EDIT2;
                end

                // ---- Edicao do 3o digito ----
                EDIT2: begin
                    if      (key_press[2]) dig[2] <= (dig[2]==4'd9) ? 4'd0 : dig[2] + 4'd1;
                    else if (key_press[3]) dig[2] <= (dig[2]==4'd0) ? 4'd9 : dig[2] - 4'd1;
                    if (key_press[1]) state <= EDIT3;
                end

                // ---- Edicao do 4o digito ----
                EDIT3: begin
                    if      (key_press[2]) dig[3] <= (dig[3]==4'd9) ? 4'd0 : dig[3] + 4'd1;
                    else if (key_press[3]) dig[3] <= (dig[3]==4'd0) ? 4'd9 : dig[3] - 4'd1;
                    if (key_press[1]) begin                 // confirma o ultimo -> verifica
                        state <= VERIFY;
                        timer <= 32'd0;
                    end
                end

                // ---- Verificacao da senha (1 ciclo) ----
                VERIFY: begin
                    if (dig[0]==PASS0 && dig[1]==PASS1 &&
                        dig[2]==PASS2 && dig[3]==PASS3)
                        state <= UNLOCKED;                  // acertou
                    else
                        state <= WRONG;                     // errou
                    timer <= 32'd0;
                end

                // ---- Cofre aberto: verdes por OPEN_CYCLES, depois reseta ----
                UNLOCKED: begin
                    if (timer >= OPEN_CYCLES - 1) begin
                        state  <= EDIT0;
                        dig[0] <= 4'd0; dig[1] <= 4'd0; dig[2] <= 4'd0; dig[3] <= 4'd0;
                        timer  <= 32'd0;
                    end
                    else timer <= timer + 32'd1;
                end

                // ---- Falha: vermelhos por WRONG_CYCLES, depois reseta ----
                WRONG: begin
                    if (timer >= WRONG_CYCLES - 1) begin
                        state  <= EDIT0;
                        dig[0] <= 4'd0; dig[1] <= 4'd0; dig[2] <= 4'd0; dig[3] <= 4'd0;
                        timer  <= 32'd0;
                    end
                    else timer <= timer + 32'd1;
                end

                default: state <= EDIT0;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    //  Indice do digito ativo (1 a 4), derivado do estado. HEX 4
    //  Nos estados de verificacao/feedback mantemos o 4 (ultimo digito).
    // ------------------------------------------------------------------------
    logic [3:0] active_idx;
    always_comb begin
        case (state)
            EDIT0:   active_idx = 4'd1;
            EDIT1:   active_idx = 4'd2;
            EDIT2:   active_idx = 4'd3;
            EDIT3:   active_idx = 4'd4;
            default: active_idx = 4'd4;
        endcase
    end

    // ------------------------------------------------------------------------
    //  Decodificador BCD -> 7 segmentos (display de anodo comum: 0 acende)
    //  Ordem dos bits: {g, f, e, d, c, b, a}
    // ------------------------------------------------------------------------
    function automatic logic [6:0] seg7(input logic [3:0] v);
        case (v)
            4'd0: seg7 = 7'b1000000;
            4'd1: seg7 = 7'b1111001;
            4'd2: seg7 = 7'b0100100;
            4'd3: seg7 = 7'b0110000;
            4'd4: seg7 = 7'b0011001;
            4'd5: seg7 = 7'b0010010;
            4'd6: seg7 = 7'b0000010;
            4'd7: seg7 = 7'b1111000;
            4'd8: seg7 = 7'b0000000;
            4'd9: seg7 = 7'b0010000;
            default: seg7 = 7'b1111111;   // apagado
        endcase
    endfunction

    // ------------------------------------------------------------------------
    //  Saidas: displays e LEDs
    // ------------------------------------------------------------------------
    always_comb begin
        // HEX3 = 1o digito ... HEX0 = 4o digito
        HEX3 = seg7(dig[0]);
        HEX2 = seg7(dig[1]);
        HEX1 = seg7(dig[2]);
        HEX0 = seg7(dig[3]);
        HEX4 = seg7(active_idx);          // indice do digito ativo (1..4)

        // LEDs: verdes no sucesso, vermelhos na falha
        LEDG = (state == UNLOCKED) ? 9'h1FF   : 9'h000;
        LEDR = (state == WRONG)    ? 18'h3FFFF : 18'h00000;
    end

endmodule
