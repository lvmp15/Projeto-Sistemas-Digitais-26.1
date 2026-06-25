// ============================================================================
//  Testbench do SafeCrack Pro
//  - Reduz os tempos de feedback (OPEN_CYCLES/WRONG_CYCLES) para a simulacao
//    rodar rapido (no FPGA continuam sendo 5 s e 3 s).
//  - Cenario 1: digita a senha CORRETA (1 2 3 4) -> espera UNLOCKED / LEDG.
//  - Cenario 2: digita uma senha ERRADA (1 2 3 5) -> espera WRONG / LEDR.
//  - Tambem exercita wrap-around (decremento a partir do 0) e o reset.
// ============================================================================
`timescale 1ns/1ps

module SafeCrackPro_tb;

    // -------- Sinais ligados ao DUT --------
    logic        CLOCK_50;
    logic [3:0]  KEY;
    logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4;
    logic [8:0]  LEDG;
    logic [17:0] LEDR;

    // -------- Instancia do DUT com tempos curtos para simulacao --------
    SafeCrackPro #(
        .PASS0(4'd1), .PASS1(4'd2), .PASS2(4'd3), .PASS3(4'd4),
        .OPEN_CYCLES (20),   // "5 s" -> 20 ciclos na simulacao
        .WRONG_CYCLES(12)    // "3 s" -> 12 ciclos na simulacao
    ) dut (
        .CLOCK_50(CLOCK_50), .KEY(KEY),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4),
        .LEDG(LEDG), .LEDR(LEDR)
    );

    // -------- Clock de 50 MHz (periodo de 20 ns) --------
    initial CLOCK_50 = 1'b0;
    always #10 CLOCK_50 = ~CLOCK_50;

    // -------- Tarefa: simula UM clique no botao KEY[k] --------
    //  Botoes ativos em nivel baixo: pressionar = 0, soltar = 1.
    task automatic press(input int k);
        @(negedge CLOCK_50);  KEY[k] = 1'b0;   // pressiona
        repeat (3) @(negedge CLOCK_50);
        KEY[k] = 1'b1;                          // solta
        repeat (3) @(negedge CLOCK_50);
    endtask

    // -------- Estimulos --------
    initial begin
        // Dump de ondas para o ModelSim (alem do .wlf padrao)
        $dumpfile("safecrack.vcd");
        $dumpvars(0, SafeCrackPro_tb);

        KEY = 4'b1111;                 // todos soltos
        repeat (4) @(negedge CLOCK_50);

        // ---- Reset inicial (KEY[0]) ----
        press(0);

        // ================= CENARIO 1: SENHA CORRETA (1 2 3 4) =================
        // Digito 1 -> 1 : incrementa 1x e confirma
        press(2);            // 0 -> 1
        press(1);            // confirma, vai para o 2o digito

        // Digito 2 -> 2 : incrementa 2x e confirma
        press(2); press(2);  // 0 -> 2
        press(1);

        // Digito 3 -> 3 : incrementa 3x e confirma
        press(2); press(2); press(2);  // 0 -> 3
        press(1);

        // Digito 4 -> 4 : incrementa 4x e confirma (dispara a verificacao)
        press(2); press(2); press(2); press(2);  // 0 -> 4
        press(1);            // VERIFY -> UNLOCKED

        // Espera o feedback de sucesso terminar e o sistema voltar ao inicio
        repeat (40) @(negedge CLOCK_50);

        // ================= CENARIO 2: SENHA ERRADA (1 2 3 5) =================
        press(2);            press(1);                       // d1 = 1
        press(2); press(2);  press(1);                       // d2 = 2
        press(2); press(2); press(2); press(1);              // d3 = 3
        press(2); press(2); press(2); press(2); press(2);    // d4 = 5
        press(1);            // VERIFY -> WRONG

        repeat (30) @(negedge CLOCK_50);

        // ================= TESTE EXTRA: wrap-around e reset =================
        // Em EDIT0, decrementar a partir de 0 deve ir para 9 (wrap)
        press(3);            // 0 -> 9
        press(3);            // 9 -> 8
        press(0);            // reset -> tudo volta a 0, digito ativo = 1

        repeat (10) @(negedge CLOCK_50);
        $display("Simulacao concluida com sucesso.");
        $finish;
    end

endmodule
