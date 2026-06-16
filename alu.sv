module alu #(parameter N = 32) (A, B, ALUControl, Result, ALUFlags);
    input logic  [2:0] ALUControl; // Ampliado a 3 bits
    input logic  [N-1:0] A, B;
    output logic [N-1:0] Result;
    output logic [3:0] ALUFlags;

    logic Cout;

    always_comb begin
        Cout = 1'b0;
        case (ALUControl)
            3'b011: begin // ORR
                Result = A | B;
            end
            3'b010: begin // AND
                Result = A & B;
            end
            3'b100: begin // MOV (pasa el operando B directamente)
                Result = B;
            end
            default: begin // ADD (3'b000) o SUB (3'b001)
                {Cout, Result} = {1'b0, A} + {1'b0, (ALUControl[0] == 1'b0 ? B : ~B)} + ALUControl[0];
            end
        endcase	
    end
    
    // Negative
    assign ALUFlags[3] = Result[N-1];
    // Zero
    assign ALUFlags[2] = (Result == 0);
    // Carry
    assign ALUFlags[1] = (~ALUControl[1]) & Cout;
    // Overflow
    assign ALUFlags[0] = (~(ALUControl[0] ^ A[N-1] ^ B[N-1])) & (A[N-1] ^ Result[N-1]) & (~ALUControl[1]);
endmodule
