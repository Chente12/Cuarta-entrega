module init(input logic clk, reset, output logic state);
	always_ff @(posedge clk, posedge reset)
	if (reset)
		state <= 1'b0;
	else
		state <= 1'b1;
endmodule
