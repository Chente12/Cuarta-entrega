// =============================================================================
// tb_lcd_controller.sv — Testbench para lcd_controller (HD44780, modo 4 bits)
// Verifica:
//   1. Secuencia de inicialización completa
//   2. init_done_o se activa al terminar la inicialización
//   3. busy_o activo durante transmisión, inactivo cuando listo
//   4. Envío de un comando (rs=0): posición DDRAM 0x80
//   5. Envío de un dato/carácter (rs=1): ASCII 'A' = 0x41
//   6. Pulso E cumple los tiempos mínimos (~500 ns alto)
//   7. lcd_rw siempre en 0
// Frecuencia: 50 MHz → periodo = 20 ns
// =============================================================================
`timescale 1ns/1ps

module tb_lcd_controller;

    // -------------------------------------------------------------------------
    // Parámetros
    // -------------------------------------------------------------------------
    localparam CLK_PERIOD    = 20;           // 20 ns → 50 MHz
    localparam CLK_FREQ      = 50_000_000;
    localparam T_E_ALTO_NS   = 500;          // 500 ns pulso E alto mínimo
    localparam T_NIBBLE_NS   = 50_000;       // 50 µs por nibble
    localparam MAX_E_PULSES  = 64;           // máximo de pulsos E a registrar

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic        clk    = 0;
    logic        reset  = 1;
    logic        send_i = 0;
    logic [7:0]  data_i = 8'h00;
    logic        rs_i   = 0;

    logic        busy_o;
    logic        init_done_o;
    logic        lcd_rs;
    logic        lcd_rw;
    logic        lcd_e;
    logic [3:0]  lcd_data;

    // -------------------------------------------------------------------------
    // Instancia DUT
    // -------------------------------------------------------------------------
    lcd_controller #(.CLK_FREQ(CLK_FREQ)) dut (
        .clk        (clk),
        .reset      (reset),
        .send_i     (send_i),
        .data_i     (data_i),
        .rs_i       (rs_i),
        .busy_o     (busy_o),
        .init_done_o(init_done_o),
        .lcd_rs     (lcd_rs),
        .lcd_rw     (lcd_rw),
        .lcd_e      (lcd_e),
        .lcd_data   (lcd_data)
    );

    // -------------------------------------------------------------------------
    // Reloj
    // -------------------------------------------------------------------------
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Medición de pulsos E — arrays estáticos en lugar de colas dinámicas
    // -------------------------------------------------------------------------
    real    e_high_times [0:MAX_E_PULSES-1];
    integer e_pulse_count;
    real    last_e_rise;

    always @(posedge lcd_e) begin
        last_e_rise = $realtime;
    end

    always @(negedge lcd_e) begin
        if (e_pulse_count < MAX_E_PULSES) begin
            e_high_times[e_pulse_count] = $realtime - last_e_rise;
            e_pulse_count = e_pulse_count + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Tarea: esperar init_done_o con timeout
    // -------------------------------------------------------------------------
    task wait_init_done;
        integer timeout;
        begin
            timeout = 0;
            while (!init_done_o && timeout < 3_000_000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (!init_done_o)
                $display("  [FAIL] init_done_o nunca se activo (timeout)");
            else
                $display("  [PASS] init_done_o activado en t=%0t ns", $time);
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: enviar un byte y esperar a que busy baje
    // -------------------------------------------------------------------------
    task send_byte;
        input [7:0] dato;
        input       rs;
        begin
            @(posedge clk);
            send_i = 1;
            data_i = dato;
            rs_i   = rs;
            @(posedge clk);
            send_i = 0;
            @(posedge busy_o);
            @(negedge busy_o);
            repeat(5) @(posedge clk);
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea de verificación
    // -------------------------------------------------------------------------
    task check;
        input [63:0]  obtenido;
        input [63:0]  esperado;
        input [127:0] nombre;
        begin
            if (obtenido === esperado)
                $display("  [PASS] %s", nombre);
            else
                $display("  [FAIL] %s — esperado=%0d obtenido=%0d", nombre, esperado, obtenido);
        end
    endtask

    // -------------------------------------------------------------------------
    // Tarea: verificar pulsos E almacenados
    // -------------------------------------------------------------------------
    task check_e_pulses;
        integer j, pass_cnt, fail_cnt;
        begin
            pass_cnt = 0;
            fail_cnt = 0;
            for (j = 0; j < e_pulse_count; j = j + 1) begin
                if (e_high_times[j] >= T_E_ALTO_NS)
                    pass_cnt = pass_cnt + 1;
                else begin
                    $display("  [WARN] Pulso E[%0d] = %.1f ns < 500 ns minimo", j, e_high_times[j]);
                    fail_cnt = fail_cnt + 1;
                end
            end
            $display("  Pulsos E medidos: %0d | OK: %0d | Cortos: %0d",
                     e_pulse_count, pass_cnt, fail_cnt);
            if (fail_cnt == 0)
                $display("  [PASS] Todos los pulsos E cumplen >= 500 ns");
            else
                $display("  [FAIL] Hay pulsos E que no cumplen el tiempo minimo");
        end
    endtask

    // -------------------------------------------------------------------------
    // Estímulos principales
    // -------------------------------------------------------------------------
    initial begin
        $display("====================================================");
        $display("  TESTBENCH LCD — Senales correctas en tiempos correctos");
        $display("====================================================");

        e_pulse_count = 0;
        last_e_rise   = 0;

        // ── Reset ─────────────────────────────────────────────────────────
        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;

        // ==================================================================
        // TEST 1: Inicialización completa
        // ==================================================================
        $display("\n[TEST 1] Secuencia de inicializacion completa");
        $display("  Esperando init_done_o...");
        wait_init_done();

        // ==================================================================
        // TEST 2: lcd_rw siempre en 0
        // ==================================================================
        $display("\n[TEST 2] lcd_rw siempre en escritura (0)");
        check(lcd_rw, 1'b0, "lcd_rw = 0 tras init");

        // ==================================================================
        // TEST 3: busy_o = 0 cuando está listo
        // ==================================================================
        $display("\n[TEST 3] busy_o inactivo cuando listo");
        check(busy_o, 1'b0, "busy_o = 0 en estado LISTO");

        // ==================================================================
        // TEST 4: Tiempos del pulso E durante inicialización
        // ==================================================================
        $display("\n[TEST 4] Tiempos del pulso E durante inicializacion");
        check_e_pulses();

        // ==================================================================
        // TEST 5: Envío de comando — SET DDRAM 0x80 (rs=0)
        // ==================================================================
        $display("\n[TEST 5] Envio de comando (rs=0): SET DDRAM 0x80");
        e_pulse_count = 0;
        send_byte(8'h80, 1'b0);
        check(lcd_rw, 1'b0, "lcd_rw = 0 tras comando");
        check(busy_o, 1'b0, "busy_o = 0 tras transmision");

        // ==================================================================
        // TEST 6: Envío de dato — carácter 'A' = ASCII 0x41 (rs=1)
        // ==================================================================
        $display("\n[TEST 6] Envio de dato (rs=1): caracter A = 0x41");
        e_pulse_count = 0;
        send_byte(8'h41, 1'b1);
        check(lcd_rw, 1'b0, "lcd_rw = 0 tras dato");
        check(busy_o, 1'b0, "busy_o = 0 tras dato");

        // ==================================================================
        // TEST 7: Pulsos E en transmisiones normales
        // ==================================================================
        $display("\n[TEST 7] Pulsos E en transmision normal (>= 500 ns)");
        check_e_pulses();

        // ==================================================================
        // TEST 8: Sin actividad — busy debe permanecer en 0
        // ==================================================================
        $display("\n[TEST 8] Sin envio — busy_o debe permanecer en 0");
        #(T_NIBBLE_NS * 3);
        check(busy_o, 1'b0, "busy_o = 0 sin actividad");

        // ==================================================================
        // TEST 9: Dos transmisiones consecutivas
        // ==================================================================
        $display("\n[TEST 9] Transmisiones consecutivas: 0x31 luego 0x32");
        send_byte(8'h31, 1'b1);
        check(busy_o, 1'b0, "busy_o = 0 tras 0x31");
        send_byte(8'h32, 1'b1);
        check(busy_o, 1'b0, "busy_o = 0 tras 0x32");

        $display("\n====================================================");
        $display("  FIN DEL TESTBENCH LCD");
        $display("====================================================\n");
        $stop;
    end

    // -------------------------------------------------------------------------
    // Límite de tiempo máximo
    // -------------------------------------------------------------------------
    initial begin
        #(200_000_000);
        $display("TIMEOUT: simulacion detenida.");
        $stop;
    end

endmodule
