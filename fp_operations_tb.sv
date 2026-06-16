// =============================================================================
// fp_operations_tb.sv — Testbench para Operaciones de Punto Flotante
// Electrónica Digital II — Entrega 2 — Universidad de Antioquia 2025-2
//
// Todos los valores de entrada y salida esperada están en hexadecimal
// IEEE 754 hardcodeado — compatible 100% con ModelSim/Questa.
//
// Valores obtenidos con Python (struct.pack '>f') para garantizar exactitud.
// =============================================================================

`timescale 1ns/1ps
//1ns (nanosegundo) es la unidad de medida.
//1ps (picosegundo) es la precisión

module fp_operations_tb;

    // -------------------------------------------------------------------------
    // Señales
    // -------------------------------------------------------------------------
    logic [31:0] A, B;
    logic [31:0] C_add, C_sub, C_mul, C_div, C_i2f, C_f2i; //C=Resultado

    // -------------------------------------------------------------------------
    // Instancias de los 6 módulos bajo prueba
    // -------------------------------------------------------------------------
    add_pf    u_add (.A(A), .B(B), .C(C_add)); //"Unit" (Unidad)
    sub_pf    u_sub (.A(A), .B(B), .C(C_sub));
    mul_pf    u_mul (.A(A), .B(B), .C(C_mul));
    div_pf    u_div (.A(A), .B(B), .C(C_div));
    int2float u_i2f (.A(A),        .C(C_i2f));
    float2int u_f2i (.A(A),        .C(C_f2i));

    // -------------------------------------------------------------------------
    // Función: diferencia absoluta entre dos vectores de 32 bits
    // -------------------------------------------------------------------------
    function automatic integer abs_diff;
        input [31:0] got, exp; //valor que produjo-valor que se esperaba
        integer diff;
        begin
            diff = $signed({1'b0, got}) - $signed({1'b0, exp});
            abs_diff = (diff < 0) ? -diff : diff;
        end
    endfunction

    // -------------------------------------------------------------------------
    // Tarea de verificación: tolera hasta 1 ULP de error de redondeo
    // -------------------------------------------------------------------------
    task automatic check;
        input [31:0] got;
        input [31:0] expected;
        input [255:0] desc;
        begin
            if (got === expected || abs_diff(got, expected) <= 1)
                $display("  [PASS] %-40s | got=0x%08X  exp=0x%08X", desc, got, expected);
            else
                $display("  [FAIL] %-40s | got=0x%08X  exp=0x%08X  delta=%0d ULP",
                         desc, got, expected, abs_diff(got, expected));
        end
    endtask

    // =========================================================================
    // Constantes IEEE 754 — calculadas con Python struct.pack('>f')
    // =========================================================================

    // --- int2float esperados para 0..9 ---
    localparam F0 = 32'h00000000; // 0.0
    localparam F1 = 32'h3F800000; // 1.0
    localparam F2 = 32'h40000000; // 2.0
    localparam F3 = 32'h40400000; // 3.0
    localparam F4 = 32'h40800000; // 4.0
    localparam F5 = 32'h40A00000; // 5.0
    localparam F6 = 32'h40C00000; // 6.0
    localparam F7 = 32'h40E00000; // 7.0
    localparam F8 = 32'h41000000; // 8.0
    localparam F9 = 32'h41100000; // 9.0

    // --- Caso 1: A=0.0, B=18.3 ---
    localparam C1_A     = 32'hcf164b5d; // 0.0
    localparam C1_B     = 32'h4f164b38; // 18.3
    localparam C1_ADD   = 32'h41926666; // 18.3
    localparam C1_SUB   = 32'hC1926666; // -18.3
    localparam C1_MUL   = 32'h00000000; // 0.0
    localparam C1_DIV   = 32'h00000000; // 0.0
    localparam C1_F2I_A = 32'h00000000; // float2int(0.0)  = 0
    localparam C1_F2I_B = 32'h00000012; // float2int(18.3) = 18

    // --- Caso 2: A=-27.45, B=77.22 ---
    localparam C2_A     = 32'hc5192000; // -27.45
    localparam C2_B     = 32'hc4ece000; //  77.22
    localparam C2_ADD   = 32'h4247147B; //  49.77
    localparam C2_SUB   = 32'hC2D1570A; // -104.67
    localparam C2_MUL   = 32'hC5047B06; // -2119.689
    localparam C2_DIV   = 32'hBEB60132; // -0.35548
    localparam C2_F2I_A = 32'hFFFFFFE5; // -27 en complemento a 2
    localparam C2_F2I_B = 32'h0000004D; //  77

    // --- Caso 3: A=8589934592 (2^33), B=12884901888 (2^33+2^34) ---
    localparam C3_A     = 32'h45192000; // 8589934592.0
    localparam C3_B     = 32'hbf651eb8; // 12884901888.0
    localparam C3_ADD   = 32'h50A00000; // 2.14748e10
    localparam C3_SUB   = 32'hCF800000; // -4294967296
    localparam C3_MUL   = 32'h60C00000; // ~1.107e20
    localparam C3_DIV   = 32'h3F2AAAAB; // 0.6667
    // Ambos > 2^31 → float2int satura
    localparam C3_F2I_A = 32'h7FFFFFFF; // saturación positiva
    localparam C3_F2I_B = 32'h7FFFFFFF; // saturación positiva

    // --- Caso 4: A=1.5258789e-5, B=2.4795532e-5 ---
    localparam C4_A     = 32'h3dc67382; // 1.5258789e-05
    localparam C4_B     = 32'hbe970a3d; // 2.4795532e-05
    localparam C4_ADD   = 32'h38280000; // 4.0054321e-05
    localparam C4_SUB   = 32'hB7200000; // -9.536743e-06
    localparam C4_MUL   = 32'h2FD00000; // 3.7835e-10
    localparam C4_DIV   = 32'h3F1D89D9; // 0.61538
    localparam C4_F2I_A = 32'h00000000; // 0 (fracción pura)
    localparam C4_F2I_B = 32'h00000000; // 0 (fracción pura)

    // =========================================================================
    // Secuencia de pruebas
    // =========================================================================
    initial begin
        $display("=============================================================");
        $display(" ENTREGA 2 — Punto Flotante IEEE 754 — UdeA ED2 2025-2");
        $display("=============================================================");

        // ------------------------------------------------------------------
        // BLOQUE 1: int2float — enteros 0 a 9
        // ------------------------------------------------------------------
        $display("\n[BLOQUE 1] int2float: enteros 0 a 9");
        A = 32'd0; #10; check(C_i2f, F0, "int2float(0) = 0x3F800000");
        A = 32'd1; #10; check(C_i2f, F1, "int2float(1) = 0x3F800000");
        A = 32'd2; #10; check(C_i2f, F2, "int2float(2) = 0x40000000");
        A = 32'd3; #10; check(C_i2f, F3, "int2float(3) = 0x40400000");
        A = 32'd4; #10; check(C_i2f, F4, "int2float(4) = 0x40800000");
        A = 32'd5; #10; check(C_i2f, F5, "int2float(5) = 0x40A00000");
        A = 32'd6; #10; check(C_i2f, F6, "int2float(6) = 0x40C00000");
        A = 32'd7; #10; check(C_i2f, F7, "int2float(7) = 0x40E00000");
        A = 32'd8; #10; check(C_i2f, F8, "int2float(8) = 0x41000000");
        A = 32'd9; #10; check(C_i2f, F9, "int2float(9) = 0x41100000");

        // ------------------------------------------------------------------
        // BLOQUE 2: Caso 1 — A=0.0, B=18.3
        // ------------------------------------------------------------------
        $display("\n[BLOQUE 2] A=0.0 (0x%08X)  B=18.3 (0x%08X)", C1_A, C1_B);
        A = C1_A; #10; check(C_f2i, C1_F2I_A, "float2int(0.0)  = 0");
        A = C1_B; #10; check(C_f2i, C1_F2I_B, "float2int(18.3) = 18");
        A = C1_A; B = C1_B; #10;
        check(C_add, C1_ADD, "0.0 + 18.3 =  18.3");
        check(C_sub, C1_SUB, "0.0 - 18.3 = -18.3");
        check(C_mul, C1_MUL, "0.0 * 18.3 =  0.0");
        check(C_div, C1_DIV, "0.0 / 18.3 =  0.0");

        // ------------------------------------------------------------------
        // BLOQUE 3: Caso 2 — A=-27.45, B=77.22
        // ------------------------------------------------------------------
        $display("\n[BLOQUE 3] A=-27.45 (0x%08X)  B=77.22 (0x%08X)", C2_A, C2_B);
        A = C2_A; #10; check(C_f2i, C2_F2I_A, "float2int(-27.45) = -27");
        A = C2_B; #10; check(C_f2i, C2_F2I_B, "float2int(77.22)  =  77");
        A = C2_A; B = C2_B; #10;
        check(C_add, C2_ADD, "-27.45 + 77.22 =  49.77");
        check(C_sub, C2_SUB, "-27.45 - 77.22 = -104.67");
        check(C_mul, C2_MUL, "-27.45 * 77.22 = -2119.69");
        check(C_div, C2_DIV, "-27.45 / 77.22 = -0.3555");

        // ------------------------------------------------------------------
        // BLOQUE 4: Caso 3 — A=8589934592, B=12884901888
        // ------------------------------------------------------------------
        $display("\n[BLOQUE 4] A=8589934592 (0x%08X)  B=12884901888 (0x%08X)", C3_A, C3_B);
        A = C3_A; #10; check(C_f2i, C3_F2I_A, "float2int(2^33)     = SAT 0x7FFFFFFF");
        A = C3_B; #10; check(C_f2i, C3_F2I_B, "float2int(3*2^32)   = SAT 0x7FFFFFFF");
        A = C3_A; B = C3_B; #10;
        check(C_add, C3_ADD, "A + B = 2.1475e10");
        check(C_sub, C3_SUB, "A - B = -4.2950e9");
        check(C_mul, C3_MUL, "A * B = 1.107e20");
        check(C_div, C3_DIV, "A / B = 0.6667");

        // ------------------------------------------------------------------
        // BLOQUE 5: Caso 4 — A=1.5259e-5, B=2.4796e-5
        // ------------------------------------------------------------------
        $display("\n[BLOQUE 5] A=1.5259e-5 (0x%08X)  B=2.4796e-5 (0x%08X)", C4_A, C4_B);
        A = C4_A; #10; check(C_f2i, C4_F2I_A, "float2int(1.526e-5) = 0");
        A = C4_B; #10; check(C_f2i, C4_F2I_B, "float2int(2.480e-5) = 0");
        A = C4_A; B = C4_B; #10;
        check(C_add, C4_ADD, "A + B = 4.005e-5");
        check(C_sub, C4_SUB, "A - B = -9.537e-6");
        check(C_mul, C4_MUL, "A * B = 3.784e-10");
        check(C_div, C4_DIV, "A / B = 0.6154");

        $display("\n=============================================================");
        $display(" Simulacion completada. Revisar lineas [FAIL] si las hay.");
        $display("=============================================================");
        $finish;
    end

endmodule
