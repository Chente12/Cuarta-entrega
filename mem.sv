module mem #(parameter WIDTH=32, DEPTH=64)(input logic clk, reset, we2, input logic [WIDTH-1:0] a1, a2, wd, output logic [WIDTH-1:0] rd1, rd2, input logic [9:0] switches, output logic [9:0] leds);

//WIDTH = 32 → Cada posición de memoria almacena 32 bits (4 bytes).
//DEPTH = 64 → La memoria tiene 64 posiciones (64 palabras).
	
	localparam addr_bits = $clog2(DEPTH); 
	
	logic [WIDTH-1:0] rd, q_a;
	logic [addr_bits-1:0] addr_A, addr_B;
	logic we, led_in, switches_in;
	
	
	altsyncram #(
		.OPERATION_MODE("BIDIR_DUAL_PORT"),
		.INIT_FILE("mem.mif"),
		
		.WIDTH_A(WIDTH),
		.WIDTHAD_A(addr_bits),
		
		.WIDTH_B(WIDTH),
		.WIDTHAD_B(addr_bits)
	) 
	u_mem(
		.clock0(clk),
		.address_a(addr_A),
		.q_a(q_a),
	
		.clock1(~clk),
		.address_b(addr_B),
		.wren_b(we),
		.data_b(wd),
		.q_b(rd)
	);
	

	always_comb begin
		
		if(reset) begin
			addr_A = '0;
			addr_B = '0;
			we = 1'b0;
			rd1 = '0;
		end
		else  begin
			addr_B = a2[addr_bits+1:2];
			addr_A = a1[addr_bits+1:2];
			we = (led_in) ? '0 : we2; //Si led_in está activo, entonces we = 0 
			rd1 = q_a;                //(no escribir en la memoria). Si no, we = we2.
		end
	end
	
	
/*Activa la señal led_in únicamente cuando el procesador intenta ESCRIBIR
 en la dirección de los LEDs.*/
	                                    //Write Enable=el procesador quiere escribir
	assign led_in = (a2 == 32'hFF20_0000) && we2;
	assign switches_in = (a2 == 32'hFF20_0040);

	
	//a2 es la dirección que llega desde el procesador para acceso de datos.
	
	
	always_comb //¿El procesador está intentando leer la dirección de los switches?
		if (switches_in)
			rd2 = {22'b0, switches}; //se construye una palabra de 32 bit
		else                                               //Read Data 2 (Dato leído 2)
			rd2 = rd; 
			 
	always_ff @(posedge clk)
		if (led_in)
			leds <= wd[9:0];
endmodule

/*module mem_mapped_io #(parameter WIDTH=32, DEPTH=4096)(
    input logic clk,       // Reloj normal (c0)
    input logic clk_b,     // Reloj desfasado 180° (c1)
    input logic reset, we2,
    input logic [WIDTH-1:0] a1, a2, wd,
    output logic [WIDTH-1:0] rd1, rd2,
    input logic [9:0] switches, output logic [9:0] leds,
    input logic [7:0] key_ascii, input logic key_valid,
    input logic lcd_busy, input logic lcd_init_done,
    output logic lcd_send_data, output logic lcd_send_cmd, output logic [7:0] lcd_out_byte
);
    localparam addr_bits = $clog2(DEPTH); 
    logic [WIDTH-1:0] rd, q_a;
    logic [addr_bits-1:0] addr_A, addr_B;
    logic we_ram;
    
    altsyncram #(.OPERATION_MODE("BIDIR_DUAL_PORT"), .INIT_FILE("mem.mif"),
        .WIDTH_A(WIDTH), .WIDTHAD_A(addr_bits), .WIDTH_B(WIDTH), .WIDTHAD_B(addr_bits)
    ) u_mem (
        .clock0(clk),   .address_a(addr_A), .q_a(q_a),
        .clock1(clk_b), .address_b(addr_B), .wren_b(we_ram), .data_b(wd), .q_b(rd)
    );
    
    logic led_in, data_in, cmd_in;
    assign led_in  = (a2 == 32'hFF20_0000) && we2;
    assign data_in = (a2 == 32'hFF20_0060) && we2;
    assign cmd_in  = (a2 == 32'hFF20_0064) && we2;

    assign lcd_send_data = data_in;
    assign lcd_send_cmd  = cmd_in;
    assign lcd_out_byte  = wd[7:0];

    always_comb begin
        if(reset) begin
            addr_A = '0; addr_B = '0; we_ram = 1'b0; rd1 = '0;
        end else begin
            addr_B = a2[addr_bits+1:2];
            addr_A = a1[addr_bits+1:2];
            we_ram = (led_in | data_in | cmd_in) ? 1'b0 : we2; 
            rd1 = q_a;                
        end
    end

    // TU mapeo exacto de direcciones
    always_comb begin
        if      (a2 == 32'hFF20_0040) rd2 = {22'b0, switches};
        else if (a2 == 32'hFF20_0050) rd2 = {23'b0, key_valid, key_ascii}; // Teclado
        else if (a2 == 32'hFF20_0068) rd2 = {30'b0, lcd_init_done, lcd_busy}; // LCD status
        else                          rd2 = rd; 
    end
             
    always_ff @(posedge clk)
        if (led_in) leds <= wd[9:0];
endmodule*/
