/*El datapath es la parte del procesador que mueve y procesa los datos.*/


module datapath(
    input  logic        clk,
    input  logic        reset,
    input  logic [1:0]  RegSrc,
    input  logic        RegWrite,
    input  logic [1:0]  ImmSrc,
    input  logic        ALUSrc,
    input  logic [2:0]  ALUControl,
    input  logic        MemtoReg,
    input  logic        PCSrc,
    output logic [3:0]  ALUFlags,
    output logic [31:0] PCNext,
    input  logic [31:0] Instr,
    output logic [31:0] ALUResult,
    output logic [31:0] WriteData,
    input  logic [31:0] ReadData,
    input  logic        BL_sig,
    input  logic        BX_sig,
    input  logic        VFP_we,
    input  logic [2:0]  VFP_op,
    input  logic        VMOV_to_ARM
);

    logic [31:0] PC, PCPlus4, PCPlus8;
    logic [31:0] ExtImm, SrcA, SrcB, Result;
    logic [3:0]  RA1, RA2;

    // -------------------------------------------------------------------------
    // Barrel Shifter (Desplazador de Barril)
    // -------------------------------------------------------------------------

    logic [31:0] ShiftedWriteData;

    always_comb begin
        if (ALUSrc == 1'b0) begin
            case (Instr[6:5])
                2'b00: ShiftedWriteData = WriteData << Instr[11:7]; // LSL (multiplica por 2ⁿ)
                2'b01: ShiftedWriteData = WriteData >> Instr[11:7]; // LSR divide entre 2ⁿ (sin signo)
                2'b10: ShiftedWriteData = $signed(WriteData) >>> Instr[11:7]; // ASR
                2'b11: ShiftedWriteData =
                        (WriteData >> Instr[11:7]) |
                        (WriteData << (32 - Instr[11:7])); // ROR
                default: ShiftedWriteData = WriteData;
            endcase
        end
        else begin
            ShiftedWriteData = WriteData;
        end
    end

    // -------------------------------------------------------------------------
    // Lógica de cálculo de PC y saltos (B, BL, BX)
    // -------------------------------------------------------------------------

    logic [31:0] PCBranchTarget;

    mux2 #(32) targetmux(
        Result,
        WriteData,
        BX_sig,
        PCBranchTarget
    );

    mux2 #(32) pcmux(
        PCPlus4,
        PCBranchTarget,
        PCSrc,
        PCNext
    );

    flopr #(32) pcreg(
        clk,
        reset,
        PCNext,
        PC
    );

    adder #(32) pcadd1(
        PC,
        32'b100,
        PCPlus4
    );

    adder #(32) pcadd2(
        PCPlus4,
        32'b100,
        PCPlus8
    );

    // -------------------------------------------------------------------------
    // Banco de registros e interfaz VFP
    // -------------------------------------------------------------------------

    logic [31:0] VFP_rd1, VFP_rd2;
    logic [31:0] VFP_Result;
    logic [31:0] FPU_SrcA;
    logic [31:0] FinalResult;
    logic [31:0] RegWriteData;
    logic [3:0]  WA3;
    logic [4:0]  VFP_wa;

    // CORRECCIÓN 1:
    // En VMOV Sn, Rt (ARM a FPU), la instrucción especifica
    // el destino en Sn (bits 19:16 y 7). En las demás instrucciones,
    // está en Sd.

    assign VFP_wa =
        (VFP_op == 3'b110) ?
        {Instr[19:16], Instr[7]} :
        {Instr[15:12], Instr[22]};

    vregfile vrf(
        .clk(clk),
        .we(VFP_we),
        .ra1({Instr[19:16], Instr[7]}), // Sn
        .ra2({Instr[3:0],  Instr[5]}),  // Sm
        .wa(VFP_wa),
        .wd(VFP_Result),
        .rd1(VFP_rd1),
        .rd2(VFP_rd2)
    );

    // Multiplexores para guardar PCPlus4 (BL)
    // o el valor de la FPU (VMOV Rt, Sn)

    assign WA3 = (BL_sig) ? 4'b1110 : Instr[15:12];

    mux2 #(32) resmux(
        ALUResult,
        ReadData,
        MemtoReg,
        Result
    );

    mux2 #(32) vfp_to_arm_mux(
        Result,
        VFP_rd1,
        VMOV_to_ARM,
        FinalResult
    );

    assign RegWriteData =
        (BL_sig) ? PCPlus4 : FinalResult;

    mux2 #(4) ra1mux(
        Instr[19:16],
        4'b1111,
        RegSrc[0],
        RA1
    );

    mux2 #(4) ra2mux(
        Instr[3:0],
        Instr[15:12],
        RegSrc[1],
        RA2
    );

    regfile rf(
        clk,
        RegWrite,
        RA1,
        RA2,
        WA3,
        RegWriteData,
        PCPlus8,
        SrcA,
        WriteData
    );

    // -------------------------------------------------------------------------
    // Unidad de Punto Flotante (FPU)
    // -------------------------------------------------------------------------
    // CORRECCIÓN 2:
    // Enrutamiento correcto de operando para VCVT.
    // VMOV_to_FPU (110) usa registro ARM general (WriteData).
    // VCVT (100 y 101) busca su único fuente en Sm (VFP_rd2).
    // Resto de operaciones (VADD, VSUB, etc.) usa Sn (VFP_rd1).

    assign FPU_SrcA =
        (VFP_op == 3'b110) ? WriteData :
        (VFP_op == 3'b100 || VFP_op == 3'b101) ? VFP_rd2 :
        VFP_rd1;

    fpu fpu_inst(
        .A(FPU_SrcA),
        .B(VFP_rd2),
        .op(VFP_op),
        .Result(VFP_Result)
    );

    // -------------------------------------------------------------------------
    // Extensión y ALU de enteros
    // -------------------------------------------------------------------------

    extend ext(
        Instr[23:0],
        ImmSrc,
        ExtImm
    );

    mux2 #(32) srcbmux(
        ShiftedWriteData,
        ExtImm,
        ALUSrc,
        SrcB
    );

    alu #(32) alu(
        SrcA,
        SrcB,
        ALUControl,
        ALUResult,
        ALUFlags
    );

endmodule
