/* Convierte el código hexadecimal de la tecla presionada al valor
   ASCII correspondiente para su visualización en el LCD HD44780.
   El LCD no interpreta números binarios directamente, sino códigos
   ASCII, por lo que esta traducción es necesaria antes de enviar
   cualquier carácter a la pantalla.
   También señaliza si la tecla es un operador matemático (is_op_o)
   o la tecla de borrado (is_del_o). Módulo puramente combinacional. */

/*module key_to_ascii (
    input  logic [3:0] key_code, //código de la tecla detectada por el módulo keypad.
    output logic [7:0] ascii_o, //valor ASCII del carácter que corresponde a la tecla
    output logic       is_del_o, //Señal de borrar (is_del_o = 1)
    output logic       is_op_o //indica si la tecla es un operador matemático (1)
);
    always_comb begin
        is_del_o = 0; is_op_o = 0;
        case (key_code)
            4'h0: ascii_o = 8'h30;
            4'h1: ascii_o = 8'h31;
            4'h2: ascii_o = 8'h32;
            4'h3: ascii_o = 8'h33;
            4'h4: ascii_o = 8'h34;
            4'h5: ascii_o = 8'h35;
            4'h6: ascii_o = 8'h36;
            4'h7: ascii_o = 8'h37;
            4'h8: ascii_o = 8'h38;
            4'h9: ascii_o = 8'h39;
            4'hA: begin ascii_o = 8'h2F; is_op_o  = 1; end // '/' division
            4'hB: begin ascii_o = 8'h2A; is_op_o  = 1; end // '*' multiplicacion
            4'hC: begin ascii_o = 8'h2D; is_op_o  = 1; end // '-' resta
            4'hD: begin ascii_o = 8'h2B; is_op_o  = 1; end // '+' suma
            4'hE: begin ascii_o = 8'h20; is_del_o = 1; end // BORRAR
            4'hF: ascii_o = 8'h2E;                         // '.' punto decimal
            default: ascii_o = 8'h20;
        endcase
    end
endmodule*/



/* Convierte el código hexadecimal de la tecla presionada al valor
   ASCII correspondiente para su visualización.
   Ahora incluye la tecla '=' (antes era '.') para ejecutar operaciones. */

module key_to_ascii (
    input  logic [3:0] key_code, // código de la tecla detectada por el módulo keypad.
    output logic [7:0] ascii_o,  // valor ASCII del carácter que corresponde a la tecla
    output logic       is_del_o, // Señal de borrar (is_del_o = 1)
    output logic       is_op_o   // indica si la tecla es un operador matemático (1)
);
    always_comb begin
        is_del_o = 0; is_op_o = 0;
        case (key_code)
            4'h0: ascii_o = 8'h30;
            4'h1: ascii_o = 8'h31;
            4'h2: ascii_o = 8'h32;
            4'h3: ascii_o = 8'h33;
            4'h4: ascii_o = 8'h34;
            4'h5: ascii_o = 8'h35;
            4'h6: ascii_o = 8'h36;
            4'h7: ascii_o = 8'h37;
            4'h8: ascii_o = 8'h38;
            4'h9: ascii_o = 8'h39;
            4'hA: begin ascii_o = 8'h2F; is_op_o  = 1; end // '/' division
            4'hB: begin ascii_o = 8'h2A; is_op_o  = 1; end // '*' multiplicacion
            4'hC: begin ascii_o = 8'h2D; is_op_o  = 1; end // '-' resta
            4'hD: begin ascii_o = 8'h2B; is_op_o  = 1; end // '+' suma
            4'hE: begin ascii_o = 8'h20; is_del_o = 1; end // BORRAR
            4'hF: begin ascii_o = 8'h3D; is_op_o  = 1; end // '=' IGUAL (modificado)
            default: ascii_o = 8'h20;
        endcase
    end
endmodule
