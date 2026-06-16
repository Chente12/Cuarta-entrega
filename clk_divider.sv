module clk_divider #(parameter DIV_VALUE = 25000) (
    input  logic clk_in,
    input  logic reset,
    output logic clk_out
);

    logic [31:0] counter;

    always_ff @(posedge clk_in or posedge reset) begin
        if (reset) begin
            counter <= 0;
            clk_out <= 0;
        end
        else if (counter == DIV_VALUE - 1) begin
            counter <= 0;
            clk_out <= ~clk_out;
        end
        else begin
            counter <= counter + 1;
        end
    end

endmodule
