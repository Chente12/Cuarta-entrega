module add_pf (
    input  logic [31:0] A,
    input  logic [31:0] B,
    output logic [31:0] C
);
    logic        sA, sB;
    logic [7:0]  eA, eB;
    logic [23:0] mA, mB;
    logic [7:0]  exp_grande, exp_chico, exp_dif, exp_res;
    logic [23:0] mGrande, mChico, mChico_alin;
    logic [24:0] mSuma;
    logic        sGrande, sChico, s_res;
    logic [4:0]  lzero;

    always_comb begin

        // Valores por defecto — evita latches en ModelSim
        sA          = 1'b0;
        sB          = 1'b0;
        eA          = 8'b0;
        eB          = 8'b0;
        mA          = 24'b0;
        mB          = 24'b0;
        exp_grande  = 8'b0;
        exp_chico   = 8'b0;
        exp_dif     = 8'b0;
        exp_res     = 8'b0;
        mGrande     = 24'b0;
        mChico      = 24'b0;
        mChico_alin = 24'b0;
        mSuma       = 25'b0;
        sGrande     = 1'b0;
        sChico      = 1'b0;
        s_res       = 1'b0;
        lzero       = 5'b0;
        C           = 32'b0;

        sA = A[31]; eA = A[30:23]; mA = {1'b1, A[22:0]};
        sB = B[31]; eB = B[30:23]; mB = {1'b1, B[22:0]};

        if (A[30:0] == 31'b0) begin
            C = B;
        end
        else if (B[30:0] == 31'b0) begin
            C = A;
        end
        else begin

            // 1. Alinear por exponente
            if (eA >= eB) begin
                exp_grande = eA; sGrande = sA; mGrande = mA;
                exp_chico  = eB; sChico  = sB; mChico  = mB;
            end else begin
                exp_grande = eB; sGrande = sB; mGrande = mB;
                exp_chico  = eA; sChico  = sA; mChico  = mA;
            end

            exp_dif = exp_grande - exp_chico;

            if (exp_dif >= 8'd24)
                mChico_alin = 24'b0;
            else
                mChico_alin = mChico >> exp_dif;

            // 2. Sumar o restar mantisas
            if (sGrande == sChico) begin
                mSuma = {1'b0, mGrande} + {1'b0, mChico_alin};
                s_res = sGrande;
            end else begin
                if (mGrande >= mChico_alin) begin
                    mSuma = {1'b0, mGrande} - {1'b0, mChico_alin};
                    s_res = sGrande;
                end else begin
                    mSuma = {1'b0, mChico_alin} - {1'b0, mGrande};
                    s_res = sChico;
                end
            end

            // 3. Normalizar
            if (mSuma == 25'b0) begin
                C       = 32'b0;
                exp_res = 8'b0;
                lzero   = 5'b0;
            end
            else if (mSuma[24]) begin
                exp_res = exp_grande + 8'd1;
                C       = {s_res, exp_res, mSuma[23:1]};
                lzero   = 5'b0;
            end
            else begin
                if      (mSuma[23]) lzero = 5'd0;
                else if (mSuma[22]) lzero = 5'd1;
                else if (mSuma[21]) lzero = 5'd2;
                else if (mSuma[20]) lzero = 5'd3;
                else if (mSuma[19]) lzero = 5'd4;
                else if (mSuma[18]) lzero = 5'd5;
                else if (mSuma[17]) lzero = 5'd6;
                else if (mSuma[16]) lzero = 5'd7;
                else if (mSuma[15]) lzero = 5'd8;
                else if (mSuma[14]) lzero = 5'd9;
                else if (mSuma[13]) lzero = 5'd10;
                else if (mSuma[12]) lzero = 5'd11;
                else if (mSuma[11]) lzero = 5'd12;
                else if (mSuma[10]) lzero = 5'd13;
                else if (mSuma[9])  lzero = 5'd14;
                else if (mSuma[8])  lzero = 5'd15;
                else if (mSuma[7])  lzero = 5'd16;
                else if (mSuma[6])  lzero = 5'd17;
                else if (mSuma[5])  lzero = 5'd18;
                else if (mSuma[4])  lzero = 5'd19;
                else if (mSuma[3])  lzero = 5'd20;
                else if (mSuma[2])  lzero = 5'd21;
                else if (mSuma[1])  lzero = 5'd22;
                else                lzero = 5'd23;

                if (exp_grande >= lzero) begin
                    exp_res = exp_grande - lzero;
                    C       = {s_res, exp_res, (mSuma[22:0] << lzero)};
                end else begin
                    C       = 32'b0;
                    exp_res = 8'b0;
                end
            end
        end
    end
endmodule
