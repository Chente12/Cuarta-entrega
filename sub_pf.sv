// =============================================================================
// sub_pf — Resta de punto flotante: C = A - B
// (Invierte el signo de B y reutiliza add_pf)
// =============================================================================
module sub_pf (
    input  logic [31:0] A,
    input  logic [31:0] B,
    output logic [31:0] C
);
    logic [31:0] B_neg; //para almacenar el valor de B con el signo cambiado.
    assign B_neg = {~B[31], B[30:0]};  // invertir signo de B
 
    //reutilización del Sumador (Instanciación)
    add_pf sub_via_add ( //nombre instancia del sumador
        .A(A),
        .B(B_neg),
        .C(C)
    );
endmodule
