// =============================================================================
// int2float — Conversión entero con signo (32 bits) a IEEE 754 float
// Equivalente a vcvt.f32.s32
// CORRECCIÓN: casez reemplazado por if-else para compatibilidad con ModelSim
// =============================================================================
module int2float (
    input  logic [31:0] A,   // entero con signo (complemento a 2)
    output logic [31:0] C    // float IEEE 754
);
    logic        s_res;
    logic [31:0] mag;  
    logic [7:0]  exp_res;
    logic [22:0] frac_res;
    logic [4:0]  msb_pos; //Posición del Bit Más Significativo

    always_comb begin
        if (A == 32'b0) begin
            C        = 32'b0;
            s_res    = 1'b0;
            mag      = 32'b0;
            exp_res  = 8'b0;
            frac_res = 23'b0;
            msb_pos  = 5'b0;
        end else begin
            s_res = A[31]; //(0)+ & (1)-
            mag   = A[31] ? (~A + 1'b1) : A; 
				//Si es - inivierte todos los bits y suma 1 al resultado

            // Encontrar posición del MSB con if-else (robusto en ModelSim/Quartus)
            if      (mag[31]) msb_pos = 5'd31;
            else if (mag[30]) msb_pos = 5'd30;
            else if (mag[29]) msb_pos = 5'd29;
            else if (mag[28]) msb_pos = 5'd28;
            else if (mag[27]) msb_pos = 5'd27;
            else if (mag[26]) msb_pos = 5'd26;
            else if (mag[25]) msb_pos = 5'd25;
            else if (mag[24]) msb_pos = 5'd24;
            else if (mag[23]) msb_pos = 5'd23;
            else if (mag[22]) msb_pos = 5'd22;
            else if (mag[21]) msb_pos = 5'd21;
            else if (mag[20]) msb_pos = 5'd20;
            else if (mag[19]) msb_pos = 5'd19;
            else if (mag[18]) msb_pos = 5'd18;
            else if (mag[17]) msb_pos = 5'd17;
            else if (mag[16]) msb_pos = 5'd16;
            else if (mag[15]) msb_pos = 5'd15;
            else if (mag[14]) msb_pos = 5'd14;
            else if (mag[13]) msb_pos = 5'd13;
            else if (mag[12]) msb_pos = 5'd12;
            else if (mag[11]) msb_pos = 5'd11;
            else if (mag[10]) msb_pos = 5'd10;
            else if (mag[9])  msb_pos = 5'd9;
            else if (mag[8])  msb_pos = 5'd8;
            else if (mag[7])  msb_pos = 5'd7;
            else if (mag[6])  msb_pos = 5'd6;
            else if (mag[5])  msb_pos = 5'd5;
            else if (mag[4])  msb_pos = 5'd4;
            else if (mag[3])  msb_pos = 5'd3;
            else if (mag[2])  msb_pos = 5'd2;
            else if (mag[1])  msb_pos = 5'd1;
            else              msb_pos = 5'd0;

            // Exponente = posición del MSB + bias 127
            exp_res = msb_pos + 8'd127;

            // Fracción: eliminar bit implícito y alinear a 23 bits
            if (msb_pos >= 5'd23)
				    //Párate en el bit 29 y agarra los 23 bits que siguen hacia abajo
                frac_res = mag[msb_pos-1 -: 23];
            else
                frac_res = mag[22:0] << (5'd23 - msb_pos);
					 //Saltos para llegar al bit más significativo 

            C = {s_res, exp_res, frac_res};
        end
    end
endmodule
