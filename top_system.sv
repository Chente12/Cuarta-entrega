/*module top_system (
    input  logic        clk,
    input  logic        nreset,
    input  logic [3:0]  row_i,
    output logic [3:0]  col_o,
    output logic        lcd_rs,
    // lcd_rw fue eliminado físicamente porque va directo a GND
    output logic        lcd_e,
    output logic [3:0]  lcd_data,
    input  logic [9:0]  switches,
    output logic [9:0]  leds
);
    logic reset, nSyncReset, syncReset;
    logic slow_clk;
    
    // Señales del procesador
    logic MemWrite;
    logic [31:0] PCNext, Instr, ReadData, WriteData, DataAdr;    

    // Señales de Periféricos
    logic [3:0] key_code;
    logic key_valid;
    logic [7:0] key_ascii;
    logic lcd_busy, lcd_init_done;
    logic lcd_send_data, lcd_send_cmd;
    logic [7:0] lcd_out_byte;

    assign reset = ~nreset;
    assign syncReset = ~nSyncReset;

    // =========================================================================
    // DIVISOR DE RELOJ CORREGIDO (DIV_VALUE = 2500 -> 10 kHz)
    // Esto soluciona los errores de cálculo en la FPU y la sincronización con la LCD.
    // =========================================================================
    clk_divider #(.DIV_VALUE(2500)) mi_divisor (
        .clk_in(clk), 
        .reset(syncReset), 
        .clk_out(slow_clk)
    );
    
    flopr #(1) resetReg(clk, ~nreset, 1'b1, nSyncReset);

    // Teclado
    keypad #(.CLK_FREQ(50_000_000)) key0 (
        .clk(clk), .reset(syncReset), .row_i(row_i), .col_o(col_o),
        .key_code(key_code), .key_valid(key_valid)
    );
    
    // Dejamos los nuevos pines vacíos usando () para que Quartus no de Warnings
    key_to_ascii k2a (
        .key_code(key_code), 
        .ascii_o(key_ascii),
        .is_del_o(), 
        .is_op_o()
    );

    // Controlador LCD (El procesador le envía comandos directo)
    lcd_controller #(.CLK_FREQ(50_000_000)) lcd0 (
        .clk(clk), .reset(syncReset),
        .send_i(lcd_send_data | lcd_send_cmd), // Enviar si es dato o comando
        .data_i(lcd_out_byte),
        .rs_i(lcd_send_data),                  // rs=1 (Dato), rs=0 (Comando)
        .busy_o(lcd_busy), .init_done_o(lcd_init_done),
        .lcd_rs(lcd_rs), 
        .lcd_rw(),                             // Vacío porque está desconectado físicamente
        .lcd_e(lcd_e), 
        .lcd_data(lcd_data)
    );

    // Memoria Mapeada (Interconecta todo)
    // Agregamos explícitamente DEPTH=1024 para evitar errores de memoria
    mem_mapped_io #(.DEPTH(1024)) memory_unit (
        .fast_clk(clk), // <--- CONECTAMOS EL RELOJ RÁPIDO NATIVO DE 50 MHz AQUÍ
        .clk(slow_clk), .reset(syncReset), .we2(MemWrite),
        .a1(PCNext), .a2(DataAdr), .wd(WriteData),
        .rd1(Instr), .rd2(ReadData),
        .switches(switches), .leds(leds),
        .key_ascii(key_ascii), .key_valid(key_valid),
        .lcd_busy(lcd_busy), .lcd_init_done(lcd_init_done),
        .lcd_send_data(lcd_send_data), .lcd_send_cmd(lcd_send_cmd), .lcd_out_byte(lcd_out_byte)
    );

    // Procesador ARM
    arm arm_cpu(
        .clk(slow_clk), .reset(syncReset),
        .PCNext(PCNext), .Instr(Instr), .MemWrite(MemWrite),
        .ALUResult(DataAdr), .WriteData(WriteData), .ReadData(ReadData)
    );

endmodule*/

module top(input logic clk, nreset,
           input logic [9:0] switches,
           output logic [9:0] leds);
    
    // Internal signals
    logic MemWrite, nSyncReset, syncReset;
    logic [31:0] PCNext, Instr, ReadData;
    logic [31:0] WriteData, DataAdr;    
    
    // ----------------------------------------------------
    // NUEVO: Reloj lento
    // ----------------------------------------------------
    logic slow_clk;
    
    assign syncReset = ~nSyncReset;
    
    // Instanciar el divisor de frecuencia
    // El reset de la DE10-Lite (botón) normalmente es activo en bajo, 
    // pero nuestro syncReset es activo en alto. Usaremos syncReset.
    clk_divider #(.DIV_VALUE(2)) mi_divisor (
        .clk_in(clk), 
        .reset(syncReset), // Reset para reiniciar el contador interno.
        .clk_out(slow_clk)
    );

    // ----------------------------------------------------
    // CUIDADO AQUÍ: Cambiamos 'clk' por 'slow_clk'
    // ----------------------------------------------------
    
    // Instancie Memory (AHORA USA SLOW_CLK)
    mem mem(slow_clk, syncReset, MemWrite, PCNext, DataAdr, WriteData, Instr, ReadData, switches, leds);
    
    // Instancie processor (AHORA USA SLOW_CLK)
    arm arm(slow_clk, syncReset, PCNext, Instr, MemWrite, DataAdr, WriteData, ReadData);
    
    // Create a synchronous reset, required by memory (Este sí usa el reloj rápido de 50MHz)
    flopr #(1) resetReg(clk, ~nreset, 1'b1, nSyncReset);

endmodule
