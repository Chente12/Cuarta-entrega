module controller(input logic clk, reset,
                        input logic [31:0] Instr,
                        input logic [3:0] ALUFlags,
                        output logic [1:0] RegSrc,
                        output logic RegWrite,
                        output logic [1:0] ImmSrc,
                        output logic ALUSrc,
                        output logic [2:0] ALUControl,
                        output logic MemWrite, MemtoReg,
                        output logic PCSrc,
                        output logic BL_sig, BX_sig,
                        output logic VFP_we,
                        output logic [2:0] VFP_op,
                        output logic VMOV_to_ARM);
    logic [1:0] FlagW;
    logic PCS, RegW, MemW;

    decoder dec(Instr,
                    FlagW, PCS, RegW, MemW,
                    MemtoReg, ALUSrc, ImmSrc, RegSrc, ALUControl,
                    BL_sig, BX_sig, VFP_we, VFP_op, VMOV_to_ARM);

    condlogic cl(clk, reset, Instr[31:28], ALUFlags,
                    FlagW, PCS, RegW, MemW,
                    PCSrc, RegWrite, MemWrite);
endmodule
