// =============================================================================
// tb_keypad.sv — Testbench para el módulo keypad
// Verifica:
//   1. Detección correcta de teclas (entrada de datos)
//   2. Antirebote: pulsos cortos (<20 ms) NO generan key_valid
//   3. Antirebote: pulso largo (>=20 ms) SÍ genera key_valid
//   4. Liberación correcta de tecla (key_valid vuelve a 0 tras 200 ms)
//   5. Secuencia de varias teclas consecutivas
// Frecuencia simulada: 50 MHz → periodo = 20 ns
// =============================================================================
`timescale 1ns/1ps

module tb_keypad;

    // -------------------------------------------------------------------------
    // Parámetros
    // -------------------------------------------------------------------------
    localparam CLK_PERIOD  = 20;          // 20 ns → 50 MHz
    localparam CLK_FREQ    = 50_000_000;

    // Tiempos en ns para facilitar la escritura de estímulos
    localparam T_1MS       = 1_000_000;   // 1 ms en ns
    localparam T_5MS       =  5*T_1MS;    // 5 ms  — rebote corto (no debe activar)
    localparam T_25MS      = 25*T_1MS;    // 25 ms — pulso largo (debe activar)
    localparam T_210MS     = 210*T_1MS;   // 210 ms — suficiente para liberar tecla

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic        clk   = 0;
    logic        reset = 1;
    logic [3:0]  row_i = 4'b1111;   // sin tecla por defecto (pull-up → 1)
    logic [3:0]  col_o;
    logic [3:0]  key_code;
    logic        key_valid;

    // -------------------------------------------------------------------------
    // Instancia DUT
    // -------------------------------------------------------------------------
    keypad #(.CLK_FREQ(CLK_FREQ)) dut (
        .clk      (clk),
        .reset    (reset),
        .row_i    (row_i),
        .col_o    (col_o),
        .key_code (key_code),
        .key_valid(key_valid)
    );

    // -------------------------------------------------------------------------
    // Reloj
    // -------------------------------------------------------------------------
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Tarea: simular pulsación de una tecla durante 'dur_ns' nanosegundos
    //   row_val  → valor de row_i con la fila activa en 0
    //   col_scan → columna que debe estar activa cuando se muestrea
    //   dur_ns   → duración del pulso en ns
    // -------------------------------------------------------------------------
    task press_key(input logic [3:0] row_val, input integer dur_ns);
        // Aplicar fila activa (col_o ya cicla sola)
        row_i = row_val;
        #(dur_ns);
        // Soltar tecla
        row_i = 4'b1111;
    endtask

    // -------------------------------------------------------------------------
    // Tarea: verificar key_valid y key_code con mensaje de resultado
    // -------------------------------------------------------------------------
    task check(
        input string    test_name,
        input logic     expected_valid,
        input logic [3:0] expected_code
    );
        if (key_valid === expected_valid && (expected_valid === 0 || key_code === expected_code)) begin
            $display("  [PASS] %s — key_valid=%b key_code=%h", test_name, key_valid, key_code);
        end else begin
            $display("  [FAIL] %s — esperado valid=%b code=%h, obtenido valid=%b code=%h",
                     test_name, expected_valid, expected_code, key_valid, key_code);
        end
    endtask

    // -------------------------------------------------------------------------
    // Estímulos principales
    // -------------------------------------------------------------------------
    initial begin
        $display("====================================================");
        $display("  TESTBENCH TECLADO — Entrada de datos y antirebote ");
        $display("====================================================");

        // ── Reset inicial ──────────────────────────────────────────────────
        reset = 1;
        #(10 * CLK_PERIOD);
        reset = 0;
        #(T_1MS);   // esperar a que el scanner arranque

        // ==================================================================
        // TEST 1: Rebote corto — pulso de 5 ms NO debe activar key_valid
        // La fila 0 activa (row_i = 1110) → tecla '1' en col0
        // ==================================================================
        $display("\n[TEST 1] Rebote corto (5 ms) — key_valid debe permanecer en 0");
        press_key(4'b1110, T_5MS);
        #(T_1MS);   // tiempo de asentamiento
        check("Rebote corto no activa valid", 1'b0, 4'hX);

        // ==================================================================
        // TEST 2: Pulsación válida — pulso de 25 ms SÍ debe activar key_valid
        // Fila 0 activa → tecla '1' (col0) → key_code = 0x1
        // ==================================================================
        $display("\n[TEST 2] Pulsación válida (25 ms) — key_valid debe ponerse en 1");
        row_i = 4'b1110;         // mantener fila activa
        #(T_25MS);
        check("Pulso válido activa valid", 1'b1, 4'h1);

        // ==================================================================
        // TEST 3: Liberación — tras 210 ms sin tecla, key_valid vuelve a 0
        // ==================================================================
        $display("\n[TEST 3] Liberación de tecla — key_valid debe volver a 0");
        row_i = 4'b1111;         // soltar tecla
        #(T_210MS);
        check("Liberación desactiva valid", 1'b0, 4'hX);

        // ==================================================================
        // TEST 4: Tecla '5' — fila 1 (row=1101), col1 → key_code = 0x5
        // ==================================================================
        $display("\n[TEST 4] Tecla '5' (fila 1, col 1) — key_code debe ser 0x5");
        row_i = 4'b1101;
        #(T_25MS);
        check("Tecla 5 detectada", 1'b1, 4'h5);
        row_i = 4'b1111;
        #(T_210MS);

        // ==================================================================
        // TEST 5: Tecla '9' — fila 2 (row=1011), col2 → key_code = 0x9
        // ==================================================================
        $display("\n[TEST 5] Tecla '9' (fila 2, col 2) — key_code debe ser 0x9");
        row_i = 4'b1011;
        #(T_25MS);
        check("Tecla 9 detectada", 1'b1, 4'h9);
        row_i = 4'b1111;
        #(T_210MS);

        // ==================================================================
        // TEST 6: Tecla '+' (D) — fila 3 (row=0111), col3 → key_code = 0xD
        // ==================================================================
        $display("\n[TEST 6] Tecla '+' = 0xD (fila 3, col 3)");
        row_i = 4'b0111;
        #(T_25MS);
        check("Tecla '+' detectada", 1'b1, 4'hD);
        row_i = 4'b1111;
        #(T_210MS);

        // ==================================================================
        // TEST 7: Secuencia rápida de dos teclas (1 luego 2)
        // ==================================================================
        $display("\n[TEST 7] Secuencia: tecla '1' luego tecla '2'");
        // Tecla 1 — fila 0, col0
        row_i = 4'b1110;
        #(T_25MS);
        check("Secuencia: tecla '1'", 1'b1, 4'h1);
        row_i = 4'b1111;
        #(T_210MS);
        // Tecla 2 — fila 0, col1
        row_i = 4'b1110;
        #(T_25MS);
        check("Secuencia: tecla '2'", 1'b1, 4'h2);
        row_i = 4'b1111;
        #(T_210MS);

        // ==================================================================
        // TEST 8: Tecla DELETE (E) — fila 3 (row=0111), col0 → key_code=0xE
        // ==================================================================
        $display("\n[TEST 8] Tecla DELETE = 0xE (fila 3, col 0)");
        row_i = 4'b0111;
        #(T_25MS);
        check("Tecla DELETE detectada", 1'b1, 4'hE);
        row_i = 4'b1111;
        #(T_210MS);

        $display("\n====================================================");
        $display("  FIN DEL TESTBENCH TECLADO");
        $display("====================================================\n");
        $stop;
    end

    // -------------------------------------------------------------------------
    // Monitor continuo de señales relevantes (para waveform / log)
    // -------------------------------------------------------------------------
    initial begin
        $monitor("[%0t ns] col_o=%b row_i=%b | key_valid=%b key_code=%h",
                 $time, col_o, row_i, key_valid, key_code);
    end

    // -------------------------------------------------------------------------
    // Límite de tiempo máximo para evitar simulaciones infinitas
    // -------------------------------------------------------------------------
    initial begin
        #(2_000_000_000); // 2 segundos simulados máximo
        $display("TIMEOUT: simulación detenida por límite de tiempo.");
        $stop;
    end

endmodule
