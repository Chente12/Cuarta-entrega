// =============================================================================
// div_pf — División de punto flotante: C = A / B
// Implementación con aproximación por desplazamiento y división entera
// =============================================================================
module div_pf (
    input  logic [31:0] A,
    input  logic [31:0] B,
    output logic [31:0] C
);
    logic        sA, sB, s_res;
    logic [7:0]  eA, eB;
    logic [9:0]  exp_dif; //10 bits para evitar desbordamientos
    logic [7:0]  exp_res;
    logic [23:0] mA, mB;
    logic [49:0] mA_ext;    // extendido para precisión
    logic [49:0] cociente;  //Versión extendida de la mantisa A
    logic [22:0] frac_res;
 
    always_comb begin
        sA = A[31]; eA = A[30:23]; mA = {1'b1, A[22:0]};
        sB = B[31]; eB = B[30:23]; mB = {1'b1, B[22:0]};
 
        s_res = sA ^ sB;
		  /*
		  (0)(0)=0  Positivo * Positivo = Positivo
		  (0)(1)=1  Positivo * Negativo = Negativo
		  (1)(0)=1  Negativo * Positivo = Negativo
	     (1)(1)=0  Negativo * Negativo = Positivo	  
		  */
 
        // División por cero → infinito (representado como exp=0xFF, frac=0)
        if (B[30:0] == 31'b0) begin
            C        = {s_res, 8'hFF, 23'b0};
            //Para no dejar señales volando:
			   exp_dif  = 10'b0;  //0 a 255
            exp_res  = 8'hFF;
            mA_ext   = 50'b0;
            cociente = 50'b0;
            frac_res = 23'b0;
        end
        // A = 0 → resultado 0
        else if (A[30:0] == 31'b0) begin
            C        = 32'b0;
            exp_dif  = 10'b0;
            exp_res  = 8'b0;
            mA_ext   = 50'b0;
            cociente = 50'b0;
            frac_res = 23'b0;
        end
        else begin
            // Exponente: resta y ajustar bias
            exp_dif = {2'b00, eA} - {2'b00, eB} + 10'd127;
 
            // División de mantisas: ampliar mA para preservar precisión
            // mA desplazado 26 bits a la izquierda
            mA_ext   = {mA, 26'b0};
            cociente = mA_ext / {26'b0, mB};
 
            // Normalizar cociente (igual a 1)
            if (cociente[26]) begin
                // bit 26 activo: resultado ≥ 1.0 (normal)
                frac_res = cociente[25:3];
                exp_res  = exp_dif[7:0];
            end else begin
                // desplazar izquierda un lugar
                frac_res = cociente[24:2];
                if (exp_dif > 10'b0) //>0
                    exp_res = exp_dif[7:0] - 8'd1;
                else
                    exp_res = 8'b0;
            end
 
            C = {s_res, exp_res, frac_res};
        end
    end
endmodule
