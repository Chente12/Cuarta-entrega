// =============================================================================
// lcd_controller.sv — HD44780 modo 4 bits, arquitectura simplificada
// Cada estado dura exactamente un número fijo de ciclos de 50MHz
// usando un único contador de retardo. El pulso E se genera en la
// primera mitad del tiempo asignado a cada nibble.
// =============================================================================

module lcd_controller #(
    parameter CLK_FREQ = 50_000_000
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       send_i,
    input  logic [7:0] data_i,
    input  logic       rs_i,
    output logic       busy_o,
    output logic       init_done_o,
    output logic       lcd_rs, //Le dice al LCD si lo que llega es un comando o un carácter
    output logic       lcd_rw, //Fijado en 0 porque siempre le escribimos al LCD, nunca leemos
    output logic       lcd_e, //Pulso que le avisa al LCD "ya puedes leer los datos del bus"
    output logic [3:0] lcd_data //Los 4 cables por donde viajan los datos hacia el LCD
);

// -------------------------------------------------------------------------
// Tiempos en ciclos de 50 MHz
// -------------------------------------------------------------------------
/*localparam T_ENCENDIDO  = 750_000;  // 15 ms  arranque
localparam T_4MS        = 200_000;  // 4 ms
localparam T_100US      =   5_000;  // 100 us
localparam T_50US       =   2_500;  // 50 us
localparam T_2MS        = 100_000;  // 2 ms  (limpiar pantalla)
localparam T_NIBBLE     =   2_500;  // 50 us por nibble (E alto primeras 25 ciclos)
localparam T_E_ALTO     =      25;  // 500 ns pulso E alto*/
// -------------------------------------------------------------------------
// Tiempos DINÁMICOS basados en la frecuencia (CLK_FREQ)
// -------------------------------------------------------------------------
localparam int T_ENCENDIDO  = (CLK_FREQ / 1000) * 15;  // 15 ms arranque
localparam int T_4MS        = (CLK_FREQ / 1000) * 4;   // 4 ms
localparam int T_100US      = (CLK_FREQ / 10000);      // 100 us
localparam int T_50US       = (CLK_FREQ / 20000);      // 50 us
localparam int T_2MS        = (CLK_FREQ / 500);        // 2 ms limpiar pantalla
localparam int T_NIBBLE     = (CLK_FREQ / 20000);      // 50 us por nibble
localparam int T_E_ALTO     = (CLK_FREQ / 2000000) > 0 ? (CLK_FREQ / 2000000) : 2;

// -------------------------------------------------------------------------
// Estados
// -------------------------------------------------------------------------
typedef enum logic [5:0] {
    S_ENCENDIDO,                        // esperar arranque
    S_I1, S_I1E,                        // 1er 0x3 (modo 8 bits)
    S_I2, S_I2E,                        // 2do 0x3
    S_I3, S_I3E,                        // 3er 0x3
    S_I4, S_I4E,                        // cambio a 4 bits (0x2)
    S_FUNC_H,  S_FUNC_HE,               // Function Set nibble alto (0x2)
    S_FUNC_L,  S_FUNC_LE,               // Function Set nibble bajo (0x8)
    S_APAG_H,  S_APAG_HE,              // Pantalla OFF nibble alto (0x0)
    S_APAG_L,  S_APAG_LE,              // Pantalla OFF nibble bajo (0x8)
    S_LIMP_H,  S_LIMP_HE,              // Limpiar pantalla nibble alto (0x0)
    S_LIMP_L,  S_LIMP_LE,              // Limpiar pantalla nibble bajo (0x1)
    S_ENTRADA_H, S_ENTRADA_HE,          // Modo entrada nibble alto (0x0)
    S_ENTRADA_L, S_ENTRADA_LE,          // Modo entrada nibble bajo (0x6)
    S_PANT_H,  S_PANT_HE,              // Pantalla ON nibble alto (0x0)
    S_PANT_L,  S_PANT_LE,              // Pantalla ON nibble bajo (0xC)
    S_LISTO,                            // listo para recibir bytes
    S_TX_H,    S_TX_HE,                 // enviar nibble alto del byte
    S_TX_L,    S_TX_LE,                 // enviar nibble bajo del byte
    S_TX_FIN                            // espera post-envío
} estado_t;

estado_t     estado;
logic [19:0] contador;      // contador de retardo
logic [7:0]  tx_dato;       // byte a transmitir
logic        tx_rs;         // rs del byte actual

assign lcd_rw = 1'b0;  // siempre escritura

// -------------------------------------------------------------------------
// FSM principal
// -------------------------------------------------------------------------
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        estado      <= S_ENCENDIDO;
        contador    <= 0;
        tx_dato     <= 0;
        tx_rs       <= 0;
        lcd_rs      <= 0;
        lcd_e       <= 0;
        lcd_data    <= 4'h0;
        busy_o      <= 1;
        init_done_o <= 0;
    end else begin
        contador <= contador + 1;

        case (estado)

		      // Paso 1: esperar 15ms después de encender
            // ----- Retardo de encendido 15ms ---------------------------------
            S_ENCENDIDO: begin
                busy_o <= 1; init_done_o <= 0;
                lcd_e <= 0; lcd_data <= 4'h0;
                if (contador >= T_ENCENDIDO) begin estado <= S_I1; contador <= 0; end
            end

				// manda 0x3 → le dice al LCD "trabaja en modo 8 bits"
            // ----- Primer nibble 0x3 (modo 8 bits) ---------------------------
            S_I1: begin
                lcd_data <= 4'h3;
                lcd_rs   <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_I1E; contador <= 0; end
            end
            S_I1E: begin
                lcd_e <= 0;
                if (contador >= T_4MS) begin estado <= S_I2; contador <= 0; end
            end
				
            // manda 0x3 → se repite para asegurarse que lo recibió
            // ----- Segundo nibble 0x3 ----------------------------------------
            S_I2: begin
                lcd_data <= 4'h3;
                lcd_rs   <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_I2E; contador <= 0; end
            end
            S_I2E: begin
                lcd_e <= 0;
                if (contador >= T_100US) begin estado <= S_I3; contador <= 0; end
            end
           
			   // manda 0x3 → se repite una vez más por si acaso
            // ----- Tercer nibble 0x3 -----------------------------------------
            S_I3: begin
                lcd_data <= 4'h3;
                lcd_rs   <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_I3E; contador <= 0; end
            end
            S_I3E: begin
                lcd_e <= 0;
                if (contador >= T_50US) begin estado <= S_I4; contador <= 0; end
            end

				// manda 0x2 → ahora le dice "cambia a modo 4 bits"
            // ----- Cambio a 4 bits: nibble 0x2 --------------------------------
            S_I4: begin
                lcd_data <= 4'h2;
                lcd_rs   <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_I4E; contador <= 0; end
            end
            S_I4E: begin
                lcd_e <= 0;
                if (contador >= T_50US) begin estado <= S_FUNC_H; contador <= 0; end
            end

				
				//Configura el LCD en modo 4 bits, 2 líneas.
				
            // ----- Function Set 0x28: nibble alto 0x2 ------------------------
            S_FUNC_H: begin
                lcd_data <= 4'h2; lcd_rs <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_FUNC_HE; contador <= 0; end
            end
            S_FUNC_HE: begin lcd_e <= 0; if (contador >= T_50US) begin estado <= S_FUNC_L; contador <= 0; end end

            // ----- Function Set 0x28: nibble bajo 0x8 ------------------------
            S_FUNC_L: begin
                lcd_data <= 4'h8; lcd_rs <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_FUNC_LE; contador <= 0; end
            end
            S_FUNC_LE: begin lcd_e <= 0; if (contador >= T_50US) begin estado <= S_APAG_H; contador <= 0; end end

				
				//Apaga la pantalla temporalmente. Paso obligatorio del protocolo.
				
            // ----- Pantalla OFF 0x08: nibble alto 0x0 ------------------------
            S_APAG_H: begin
                lcd_data <= 4'h0; lcd_rs <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_APAG_HE; contador <= 0; end
            end
            S_APAG_HE: begin lcd_e <= 0; if (contador >= T_50US) begin estado <= S_APAG_L; contador <= 0; end end

            // ----- Pantalla OFF 0x08: nibble bajo 0x8 ------------------------
            S_APAG_L: begin
                lcd_data <= 4'h8; lcd_rs <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_APAG_LE; contador <= 0; end
            end
            S_APAG_LE: begin lcd_e <= 0; if (contador >= T_50US) begin estado <= S_LIMP_H; contador <= 0; end end

				
				
				//Borra todo el contenido del LCD y regresa el cursor al inicio.
				// códigos fijos que el LCD entiende
            // ----- Limpiar pantalla 0x01: nibble alto 0x0 --------------------
            S_LIMP_H: begin
                lcd_data <= 4'h0; lcd_rs <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_LIMP_HE; contador <= 0; end
            end
            S_LIMP_HE: begin lcd_e <= 0; if (contador >= T_50US) begin estado <= S_LIMP_L; contador <= 0; end end

            // ----- Limpiar pantalla 0x01: nibble bajo 0x1 --------------------
            S_LIMP_L: begin
                lcd_data <= 4'h1; lcd_rs <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_LIMP_LE; contador <= 0; end
            end
            S_LIMP_LE: begin lcd_e <= 0; if (contador >= T_2MS) begin estado <= S_ENTRADA_H; contador <= 0; end end

				
				
				//Le dice al LCD que el cursor avance solo hacia la derecha al escribir.
				
            // ----- Modo entrada 0x06: nibble alto 0x0 ------------------------
            S_ENTRADA_H: begin
                lcd_data <= 4'h0; lcd_rs <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_ENTRADA_HE; contador <= 0; end
            end
            S_ENTRADA_HE: begin lcd_e <= 0; if (contador >= T_50US) begin estado <= S_ENTRADA_L; contador <= 0; end end

            // ----- Modo entrada 0x06: nibble bajo 0x6 ------------------------
            S_ENTRADA_L: begin
                lcd_data <= 4'h6; lcd_rs <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_ENTRADA_LE; contador <= 0; end
            end
            S_ENTRADA_LE: begin lcd_e <= 0; if (contador >= T_50US) begin estado <= S_PANT_H; contador <= 0; end end

				
				
				
				//Enciende la pantalla. Al terminar este paso la inicialización está completa.
				
            // ----- Pantalla ON 0x0C: nibble alto 0x0 -------------------------
            S_PANT_H: begin
                lcd_data <= 4'h0; lcd_rs <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_PANT_HE; contador <= 0; end
            end
            S_PANT_HE: begin lcd_e <= 0; if (contador >= T_50US) begin estado <= S_PANT_L; contador <= 0; end end

            // ----- Pantalla ON 0x0C: nibble bajo 0xC -------------------------
            S_PANT_L: begin
                lcd_data <= 4'hC; lcd_rs <= 0;
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_PANT_LE; contador <= 0; end
            end
            S_PANT_LE: begin
                lcd_e <= 0;
                if (contador >= T_50US) begin
                    estado      <= S_LISTO;
                    contador    <= 0;
                    init_done_o <= 1;
                    busy_o      <= 0;
                end
            end

            // ----- LISTO: esperar nuevo byte ----------------------------------
				// lcd_controller recibe eso y lo manda físicamente al LCD
            S_LISTO: begin
                lcd_e       <= 0;
                busy_o      <= 0;
                init_done_o <= 1;
                if (send_i) begin
                    tx_dato <= data_i;
                    tx_rs   <= rs_i;
                    busy_o  <= 1;
                    estado  <= S_TX_H; //empieza a enviar nibble por nibble
                    contador <= 0;
                end
            end

				
				
				
				
				
///////Envía el byte en dos partes de 4 bits cada una por los 4 cables físicos del LCD.
				
            // ----- Transmitir nibble alto -------------------------------------
            S_TX_H: begin
                lcd_rs   <= tx_rs;
                lcd_data <= tx_dato[7:4];
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_TX_HE; contador <= 0; end
            end
            S_TX_HE: begin
                lcd_e  <= 0;
                lcd_rs <= tx_rs;
                if (contador >= T_50US) begin estado <= S_TX_L; contador <= 0; end
            end

            // ----- Transmitir nibble bajo -------------------------------------
            S_TX_L: begin
                lcd_rs   <= tx_rs;
                lcd_data <= tx_dato[3:0];
                lcd_e    <= (contador < T_E_ALTO) ? 1 : 0;
                if (contador >= T_NIBBLE) begin estado <= S_TX_LE; contador <= 0; end
            end
            S_TX_LE: begin
                lcd_e  <= 0;
                lcd_rs <= tx_rs;
                if (contador >= T_50US) begin estado <= S_TX_FIN; contador <= 0; end
            end

            // ----- Espera post-transmisión ------------------------------------
            S_TX_FIN: begin
                lcd_e <= 0;
                if (contador >= T_50US) begin
                    estado   <= S_LISTO;
                    contador <= 0;
                    busy_o   <= 0;
                end
            end

            default: begin estado <= S_ENCENDIDO; contador <= 0; end
        endcase
    end
end

endmodule
