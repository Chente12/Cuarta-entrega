// =============================================================================
// mul_pf — Multiplicación de punto flotante: C = A * B
// CORRECCIÓN: protección contra overflow y underflow del exponente
// =============================================================================
module mul_pf (
    input  logic [31:0] A,
    input  logic [31:0] B,
    output logic [31:0] C
);
    logic        sA, sB, s_res; //resultado del signo
    logic [7:0]  eA, eB;
    logic [9:0]  exp_sum; //bit 8 overflow, bit 9 underflow (resultado es negativo)
    logic [7:0]  exp_res;
    logic [23:0] mA, mB;
    logic [47:0] mProd; //24 bits x 24 bits = 48 bits
    logic [22:0] frac_res;

    always_comb begin //bit: 32(1) --- 8 --- bit implícito y 23
        sA = A[31]; eA = A[30:23]; mA = {1'b1, A[22:0]};
        sB = B[31]; eB = B[30:23]; mB = {1'b1, B[22:0]};

        s_res = sA ^ sB; //ejemplo 0 ^ 0 = 0 (Positivo). XOR(*)
		  
		   /*
		  (0)(0)=0  Positivo * Positivo = Positivo
		  (0)(1)=1  Positivo * Negativo = Negativo
		  (1)(0)=1  Negativo * Positivo = Negativo
	     (1)(1)=0  Negativo * Negativo = Positivo	  
		  */

        if (A[30:0] == 31'b0 || B[30:0] == 31'b0) begin //OR(ó)
            C        = 32'b0;
            exp_sum  = 10'b0;
            exp_res  = 8'b0;
            mProd    = 48'b0;
            frac_res = 23'b0;
        end else begin
		  
            // Exponente: suma de exponentes menos bias		
            exp_sum = {2'b00, eA} + {2'b00, eB} - 10'd127;

            // Multiplicar mantisas
            mProd = mA * mB;

            // Normalizar y calcular exponente resultado (Iz)
            if (mProd[47]) begin //bit48
                frac_res = mProd[46:24];
					 
                // exp_sum + 1: verificar overflow
                if (exp_sum >= 10'd254)
                    exp_res = 8'hFF;        // overflow → infinito
                else
                    exp_res = exp_sum[7:0] + 8'd1;
            end else begin
                frac_res = mProd[45:23];
					 
                // Verificar overflow o underflow
                if (exp_sum[9])             // underflow (negativo en signed)
                    exp_res = 8'h00;
                else if (exp_sum > 10'd254)
                    exp_res = 8'hFF;        // overflow → infinito
                else
                    exp_res = exp_sum[7:0];
            end

            C = {s_res, exp_res, frac_res};
        end
    end
endmodule

/*module mul_pf (input logic [31:0] A, input logic [31:0] B, output logic [31:0] C);
    logic        sA, sB, s_res; 
    logic [7:0]  eA, eB;
    logic [9:0]  exp_sum; 
    logic [7:0]  exp_res;
    logic [23:0] mA, mB;
    logic [47:0] mProd; 
    logic [22:0] frac_res;

    always_comb begin 
        sA = A[31]; eA = A[30:23]; mA = {1'b1, A[22:0]};
        sB = B[31]; eB = B[30:23]; mB = {1'b1, B[22:0]};

        s_res = sA ^ sB; 
		  
        if (A[30:0] == 31'b0 || B[30:0] == 31'b0) begin 
            C        = 32'b0;
            exp_sum  = 10'b0;
            exp_res  = 8'b0;
            mProd    = 48'b0;
            frac_res = 23'b0;
        end else begin
            exp_sum = {2'b00, eA} + {2'b00, eB} - 10'd127;
            mProd = mA * mB;

            if (mProd[47]) begin 
                frac_res = mProd[46:24];
                if (exp_sum >= 10'd254)
                    exp_res = 8'hFF;        
                else
                    exp_res = exp_sum[7:0] + 8'd1;
            end else begin
                frac_res = mProd[45:23];
                if (exp_sum[9])             
                    exp_res = 8'h00;
                else if (exp_sum > 10'd254)
                    exp_res = 8'hFF;        
                else
                    exp_res = exp_sum[7:0];
            end
            C = {s_res, exp_res, frac_res};
        end
    end
endmodule*/
