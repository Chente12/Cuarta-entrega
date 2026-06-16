/*Interpretar la instrucción que llega desde la memoria y generar las señales
de control necesarias para que el procesador haga la operación correcta.*/

module decoder(input logic [31:0] Instr, // Recibe la instrucción completa de 32 bits
               output logic [1:0] FlagW,
               output logic PCS, RegW, MemW,
               output logic MemtoReg, ALUSrc,
               output logic [1:0] ImmSrc, RegSrc,
               output logic [2:0] ALUControl,
               output logic BL_sig, BX_sig,
               output logic VFP_we,
               output logic [2:0] VFP_op,
               output logic VMOV_to_ARM);

    logic [1:0] Op; //Código de Operación - Tipo de instrucción
    logic [5:0] Funct; //función específica
    logic [3:0] Rd;  //registro destino
   
    assign Op = Instr[27:26];
    assign Funct = Instr[25:20];
    assign Rd = Instr[15:12];

    logic [9:0] controls;
    logic Branch, ALUOp;
    logic RegW_raw;
    logic [1:0] RegSrc_raw;

    // Decodificador Principal
    always_comb
        casex(Op)          //operaciones aritméticas/lógicas
            2'b00: if (Funct[5]) controls = 10'b0000101001; // DP inmediato
                   else controls = 10'b0000001001; // DP registro
            2'b01: if (Funct[0]) controls = 10'b0001111000; // LDR
                   else controls = 10'b1001110100; // STR
            2'b10: controls = 10'b0110100010; // B / BL
            default: controls = 10'b0000000000; // Por defecto
        endcase
       
    assign {RegSrc_raw, ImmSrc, ALUSrc, MemtoReg, RegW_raw, MemW, Branch, ALUOp} = controls;

    // Decodificador de la ALU de enteros
    always_comb
        if (ALUOp) begin
            case(Funct[4:1])
                4'b0100: ALUControl = 3'b000; // ADD
                4'b0010: ALUControl = 3'b001; // SUB
                4'b1010: ALUControl = 3'b001; // CMP (usa resta interna)
                4'b0000: ALUControl = 3'b010; // AND
                4'b1100: ALUControl = 3'b011; // ORR
                4'b1101: ALUControl = 3'b100; // MOV
                default: ALUControl = 3'bx;
            endcase

            FlagW[1] = Funct[0];
            FlagW[0] = Funct[0] & (ALUControl == 3'b000 | ALUControl == 3'b001);
        end
        else begin
            ALUControl = 3'b000;
            FlagW = 2'b00;
        end

    // Detección de subrutinas y saltos condicionales
    assign BL_sig = (Op == 2'b10) & Funct[4];
    // BX utiliza Funct = 6'b010010 en estándar ARM
    assign BX_sig = (Op == 2'b00) & (Funct == 6'b010010) & (Instr[19:4] == 16'hFFF1);
   
    // Decodificación de Punto Flotante (VFP)
    logic is_vfp;
//Identificar si es una instrucción de punto flotante mirando el OpCode	 
    assign is_vfp = (Op == 2'b11) & (Instr[11:8] == 4'b1010);
   
    always_comb begin
	 
	     //Inicializar estas señales a un estado por defecto
	 
        VFP_we = 1'b0; //para escribir en los registros S0-S31
        VFP_op = 3'b110; //le dice a la FPU qué operación hacer
        VMOV_to_ARM = 1'b0; //avisa si el dato debe devolverse a los registros enteros
       
        if (is_vfp) begin
            // 1. VMOV (Transferencia entre ARM y FPU) (Funct = 100000)
            if ({Instr[25:24], Instr[23:21]} == 5'b10000) begin
                if (Instr[20] == 1'b1) begin
                    VMOV_to_ARM = 1'b1; // VMOV Rt, Sn
                end else begin
                    VFP_we = 1'b1;       // VMOV Sn, Rt
                    VFP_op = 3'b110;
                end
            end
            else if (Instr[25:24] == 2'b10) begin
                // 2. VADD y VSUB
                if (Instr[23] == 1'b0 && Instr[21:20] == 2'b11) begin
                    VFP_we = 1'b1;
                    if (Instr[6] == 1'b0) VFP_op = 3'b000;      // VADD.F32
                    else                  VFP_op = 3'b001;      // VSUB.F32
                end
                // 3. VMUL
                else if (Instr[23] == 1'b0 && Instr[21:20] == 2'b10 && Instr[6] == 1'b0) begin
                    VFP_we = 1'b1;
                    VFP_op = 3'b010;                            // VMUL.F32
                end
                // 4. VDIV
                else if (Instr[23] == 1'b1 && Instr[21:20] == 2'b00 && Instr[6] == 1'b0) begin
                    VFP_we = 1'b1;
                    VFP_op = 3'b011;                            // VDIV.F32
                end
                // 5. VCVT
                else if (Instr[23] == 1'b1 && Instr[21:20] == 2'b11) begin
                    VFP_we = 1'b1;
                    if (Instr[19:16] == 4'b1000)
                        VFP_op = 3'b101; // VCVT.F32.S32 (int a float)
                    else if (Instr[19:16] == 4'b1101)
                        VFP_op = 3'b100; // VCVT.S32.F32 (float a int)
                end
            end
        end
    end
   
    // Lógica de PC, habilitación de registros y multiplexado de fuentes de lectura
    always_comb begin
        PCS = ((Rd == 4'b1111) & RegW_raw) | Branch | BX_sig;
        RegW = RegW_raw;
        RegSrc = RegSrc_raw;
       
        if (BL_sig) begin
            RegW = 1'b1; // Escribe dirección de retorno en R14 (LR)
        end
        else if (BX_sig) begin
            RegW = 1'b0;
        end
        else if (is_vfp) begin
            RegW = VMOV_to_ARM;
            RegSrc = 2'b00;
            if (VFP_we && (VFP_op == 3'b110)) begin
                RegSrc = 2'b10; // Fuerza RA2 a tomar Rt (Instr[15:12])
            end
        end
        else if (ALUOp && (Funct[4:1] == 4'b1010)) begin
            RegW = 1'b0; // CMP no escribe en registros
        end
    end
endmodule
