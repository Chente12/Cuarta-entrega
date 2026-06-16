/*
 * Banco de registros de punto flotante VFP (S0 a S31)
 * Almacena 32 registros de precisión sencilla (32 bits cada uno).
 */
module vregfile(
    input logic clk,
    input logic we,                // Habilitador de escritura
    input logic [4:0] ra1, ra2,    // Direcciones de lectura (Sn y Sm)
    input logic [4:0] wa,          // Dirección de escritura (Sd)
    input logic [31:0] wd,         // Datos a escribir
    output logic [31:0] rd1, rd2   // Datos leídos de forma combinacional
);
    logic [31:0] rf[31:0];

    // Escritura síncrona en el flanco de subida
    always_ff @(posedge clk) begin
        if (we) begin
            rf[wa] <= wd;
        end
    end

    // Lectura combinacional / asíncrona
    assign rd1 = rf[ra1];
    assign rd2 = rf[ra2];
endmodule
