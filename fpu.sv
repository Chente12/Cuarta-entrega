/*
 * Unidad de Punto Flotante (FPU)
 * Integro los módulos diseñados en las entregas anteriores
 * para realizar operaciones de precisión sencilla (IEEE 754 de 32 bits).
 */
module fpu(
    input logic [31:0] A, B,      // Operandos de 32 bits del datapath
    input logic [2:0] op,         // Operación seleccionada por el decodificador
    output logic [31:0] Result    // Resultado que retorna al datapath
);
    // Señales intermedias para conectar cada módulo
    logic [31:0] res_add;
    logic [31:0] res_sub;
    logic [31:0] res_mul;
    logic [31:0] res_div;
    logic [31:0] res_i2f;
    logic [31:0] res_f2i;

    // Instanciación exacta de módulos combinacionales de punto flotante
    add_pf       inst_add(.A(A), .B(B), .C(res_add));
    sub_pf       inst_sub(.A(A), .B(B), .C(res_sub));
    mul_pf       inst_mul(.A(A), .B(B), .C(res_mul));
    div_pf       inst_div(.A(A), .B(B), .C(res_div));
    int2float    inst_i2f(.A(A),        .C(res_i2f));
    float2int    inst_f2i(.A(A),        .C(res_f2i));

    // Multiplexor de resultados según la operación VFP decodificada
    always_comb begin
        case (op)
            3'b000:  Result = res_add; // VADD.F32
            3'b001:  Result = res_sub; // VSUB.F32
            3'b010:  Result = res_mul; // VMUL.F32
            3'b011:  Result = res_div; // VDIV.F32
            3'b100:  Result = res_f2i; // Float a Entero (VCVT.S32.F32)
            3'b101:  Result = res_i2f; // Entero a Float (VCVT.F32.S32)
            3'b110:  Result = A;       // VMOV (Pasa el operando directo)
            default: Result = 32'b0;
        endcase
    end
endmodule
