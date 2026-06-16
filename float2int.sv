// =============================================================================
// float2int — Conversión IEEE 754 float a entero con signo (32 bits)
// Equivalente a vcvt.s32.f32 — trunca hacia cero
// =============================================================================
module float2int (
    input  logic [31:0] A,   // float IEEE 754
    output logic [31:0] C    // entero con signo (complemento a 2)
);
    logic        s_A;
    logic [7:0]  e_A;
    logic [22:0] f_A;           //exponente sin bias
    logic [8:0]  exp_unbiased; //9 bits para poder representar el resultado negativo
    logic [31:0] mag;  //guardar la magnitud del número reconstruido
	 
	 /*
	 0 → número positivo
    1 → número negativo
	 */
 
    always_comb begin
        s_A = A[31];
        e_A = A[30:23];
        f_A = A[22:0];
 
        // Número desnormalizado → números extremadamente pequeños cercanos a cero
        if (e_A == 8'b0) begin
            C           = 32'b0;
            exp_unbiased = 9'b0;
            mag          = 32'b0;
        end
		  
        // Infinito o NaN (exp = 0xFF)
        else if (e_A == 8'hFF) begin
//si s_A es 1, entonces C vale 100000..., si no, C vale 0x7FFFFFFF		  
            C           = s_A ? 32'h80000000 : 32'h7FFFFFFF; // saturar
            exp_unbiased = 9'b0;
            mag          = 32'b0;
        end
        else begin
            // exp_unbiased = e_A - 127
            exp_unbiased = {1'b0, e_A} - 9'd127;
 
            // Si exponente < 0: valor < 1, resultado = 0
            if (exp_unbiased[8]) begin  
                C   = 32'b0;
                mag = 32'b0;
            end
            // Si exponente >= 31: overflow
            else if (exp_unbiased >= 9'd31) begin
                C   = s_A ? 32'h80000000 : 32'h7FFFFFFF;
                mag = 32'b0;
            end
            else begin
				
                // Reconstruir magnitud: {1, frac} desplazado según exponente
                if (exp_unbiased >= 9'd23)
					     // SÍ → desplazar izquierda para agrandar el número
                    mag = {9'b0, 1'b1, f_A} << (exp_unbiased - 9'd23);
                else
					     // NO → desplazar derecha para achicar el número (trunca fracción)
                    mag = {9'b0, 1'b1, f_A} >> (9'd23 - exp_unbiased);
 
                // Aplicar signo (complemento a 2)
                C = s_A ? (~mag + 1'b1) : mag;
					           //(negativo) ✓
            end
        end
    end
endmodule
