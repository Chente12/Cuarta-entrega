/*Es el procesador. Contiene el controlador y el datapath; 
ejecuta instrucciones ARM, opera la ALU y coordina lectura/escritura
 con la memoria.*/

module arm(input logic clk, reset,
			  output logic [31:0] PCNext,
			  input logic [31:0] Instr,
			  output logic MemWrite,
			  output logic [31:0] ALUResult, WriteData,
			  input logic [31:0] ReadData);

	logic [3:0] ALUFlags;
	logic RegWrite, ALUSrc, MemtoReg, PCSrc;
	logic [1:0] RegSrc, ImmSrc;
	logic [2:0] ALUControl;
	logic BL_sig, BX_sig, VFP_we, VMOV_to_ARM;
	logic [2:0] VFP_op;

	controller c(clk, reset, Instr, ALUFlags,
						RegSrc, RegWrite, ImmSrc,
						ALUSrc, ALUControl,
						MemWrite, MemtoReg, PCSrc,
						BL_sig, BX_sig, VFP_we, VFP_op, VMOV_to_ARM);
						
	datapath dp(clk, reset,
						RegSrc, RegWrite, ImmSrc,
						ALUSrc, ALUControl,
						MemtoReg, PCSrc,
						ALUFlags, PCNext, Instr,
						ALUResult, WriteData, ReadData,
						BL_sig, BX_sig, VFP_we, VFP_op, VMOV_to_ARM);
endmodule
