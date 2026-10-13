//============================================================================
// Decodificador Morse -> 7 segmentos con un solo push-button
//  - Pulsación corta (< DOT_MAX_MS)  => punto
//  - Pulsación larga (>= DOT_MAX_MS) => guion
//  - Silencio >= GAP_MS              => fin de carácter, se decodifica y muestra
//  Soporta letras A-Z (1 a 4 símbolos) y dígitos 0-9 (5 símbolos).
//  Secuencia inválida o > 5 símbolos => se muestra "=" (error).
//============================================================================

//----------------------------------------------------------------------------
// 1) Sincronizador + antirrebote (din: 1 = presionado)
//----------------------------------------------------------------------------
module debounce #(
    parameter CLK_HZ = 50_000_000,
    parameter DB_MS  = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    output reg  dout
);
    localparam integer MAXC = (CLK_HZ/1000) * DB_MS;
    reg s0, s1;
    reg [$clog2(MAXC+1):0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0 <= 1'b0; s1 <= 1'b0; cnt <= 0; dout <= 1'b0;
        end else begin
            s0 <= din;
            s1 <= s0;
            if (s1 == dout)
                cnt <= 0;                       // sin cambio pendiente
            else if (cnt >= MAXC-1) begin       // cambio estable MAXC ciclos
                dout <= s1;
                cnt  <= 0;
            end else
                cnt <= cnt + 1'b1;
        end
    end
endmodule

//----------------------------------------------------------------------------
// 2) FSM: mide duración de la pulsación y arma el código Morse
//    code: 0 = punto, 1 = guion; el primer símbolo queda en el bit más alto
//    (ej. "A" = .-  -> len=2, code=5'b00001)
//----------------------------------------------------------------------------
module morse_fsm #(
    parameter CLK_HZ     = 50_000_000,
    parameter DOT_MAX_MS = 250,    // umbral punto/guion
    parameter GAP_MS     = 700     // silencio que cierra el carácter
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       btn,         // ya antirrebote, 1 = presionado
    output reg  [4:0] out_code,
    output reg  [2:0] out_len,
    output reg        out_err,
    output reg        valid,       // pulso de 1 ciclo: carácter listo
    output reg        led_dot,     // indica último símbolo clasificado
    output reg        led_dash
);
    localparam [1:0] IDLE = 2'd0, PRESS = 2'd1, GAP = 2'd2, EMIT = 2'd3;
    localparam integer TICK_DIV = CLK_HZ/1000;   // 1 tick = 1 ms

    reg [1:0]  state;
    reg [$clog2(TICK_DIV)+1:0] div;
    reg [15:0] t_ms;
    reg [4:0]  code;
    reg [2:0]  len;
    reg        ovf;

    wire tick = (div == TICK_DIV-1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) div <= 0;
        else        div <= tick ? 0 : div + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; t_ms <= 0; code <= 0; len <= 0; ovf <= 0;
            out_code <= 0; out_len <= 0; out_err <= 0; valid <= 0;
            led_dot <= 0; led_dash <= 0;
        end else begin
            valid <= 1'b0;

            case (state)
                //---------------------------------------------------------
                IDLE: if (btn) begin
                    t_ms <= 0;
                    led_dot <= 0; led_dash <= 0;
                    state <= PRESS;
                end

                //---------------------------------------------------------
                PRESS: begin
                    if (tick && t_ms != 16'hFFFF) t_ms <= t_ms + 1'b1;

                    if (!btn) begin                      // soltó: clasificar
                        if (len == 3'd5)
                            ovf <= 1'b1;                 // demasiados símbolos
                        else begin
                            code <= {code[3:0], (t_ms >= DOT_MAX_MS)};
                            len  <= len + 1'b1;
                        end
                        led_dot  <= (t_ms <  DOT_MAX_MS);
                        led_dash <= (t_ms >= DOT_MAX_MS);
                        t_ms  <= 0;
                        state <= GAP;
                    end
                end

                //---------------------------------------------------------
                GAP: begin
                    if (btn) begin                       // siguiente símbolo
                        t_ms <= 0;
                        led_dot <= 0; led_dash <= 0;
                        state <= PRESS;
                    end else if (tick) begin
                        if (t_ms >= GAP_MS-1) state <= EMIT;
                        else                  t_ms <= t_ms + 1'b1;
                    end
                end

                //---------------------------------------------------------
                EMIT: begin
                    out_code <= code;
                    out_len  <= len;
                    out_err  <= ovf;
                    valid    <= 1'b1;
                    code <= 0; len <= 0; ovf <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

//----------------------------------------------------------------------------
// 3) Decodificador combinacional {len, code} -> patrón 7 segmentos
//    Salida activa en alto, orden {g,f,e,d,c,b,a}
//    Algunas letras son aproximaciones (M, V, W, X) y hay ambigüedades
//    inevitables en 7 segmentos: S=5, Z=2.
//----------------------------------------------------------------------------
module morse_to_7seg (
    input  wire [2:0] len,
    input  wire [4:0] code,
    output reg  [6:0] seg      // activo en alto
);
    localparam [6:0] ERR = 7'h48;   // "="
    always @* begin
        case ({len, code})
            // ---- 1 símbolo
            {3'd1,5'b00000}: seg = 7'h79; // E  .
            {3'd1,5'b00001}: seg = 7'h78; // T  -
            // ---- 2 símbolos
            {3'd2,5'b00001}: seg = 7'h77; // A  .-
            {3'd2,5'b00000}: seg = 7'h30; // I  ..
            {3'd2,5'b00011}: seg = 7'h37; // M  --
            {3'd2,5'b00010}: seg = 7'h54; // N  -.
            // ---- 3 símbolos
            {3'd3,5'b00100}: seg = 7'h5E; // D  -..
            {3'd3,5'b00110}: seg = 7'h3D; // G  --.
            {3'd3,5'b00101}: seg = 7'h75; // K  -.-
            {3'd3,5'b00111}: seg = 7'h5C; // O  ---
            {3'd3,5'b00010}: seg = 7'h50; // R  .-.
            {3'd3,5'b00000}: seg = 7'h6D; // S  ...
            {3'd3,5'b00001}: seg = 7'h3E; // U  ..-
            {3'd3,5'b00011}: seg = 7'h2A; // W  .--
            // ---- 4 símbolos
            {3'd4,5'b01000}: seg = 7'h7C; // B  -...
            {3'd4,5'b01010}: seg = 7'h39; // C  -.-.
            {3'd4,5'b00010}: seg = 7'h71; // F  ..-.
            {3'd4,5'b00000}: seg = 7'h76; // H  ....
            {3'd4,5'b00111}: seg = 7'h1E; // J  .---
            {3'd4,5'b00100}: seg = 7'h38; // L  .-..
            {3'd4,5'b00110}: seg = 7'h73; // P  .--.
            {3'd4,5'b01101}: seg = 7'h67; // Q  --.-
            {3'd4,5'b00001}: seg = 7'h1C; // V  ...-
            {3'd4,5'b01001}: seg = 7'h49; // X  -..-
            {3'd4,5'b01011}: seg = 7'h6E; // Y  -.--
            {3'd4,5'b01100}: seg = 7'h5B; // Z  --..
            // ---- 5 símbolos: dígitos
            {3'd5,5'b11111}: seg = 7'h3F; // 0  -----
            {3'd5,5'b01111}: seg = 7'h06; // 1  .----
            {3'd5,5'b00111}: seg = 7'h5B; // 2  ..---
            {3'd5,5'b00011}: seg = 7'h4F; // 3  ...--
            {3'd5,5'b00001}: seg = 7'h66; // 4  ....-
            {3'd5,5'b00000}: seg = 7'h6D; // 5  .....
            {3'd5,5'b10000}: seg = 7'h7D; // 6  -....
            {3'd5,5'b11000}: seg = 7'h07; // 7  --...
            {3'd5,5'b11100}: seg = 7'h7F; // 8  ---..
            {3'd5,5'b11110}: seg = 7'h6F; // 9  ----.
            default:         seg = ERR;
        endcase
    end
endmodule

//----------------------------------------------------------------------------
// 4) Top
//----------------------------------------------------------------------------
module tt_um_morse_top #(
    parameter CLK_HZ         = 50_000_000,
    parameter DB_MS          = 20,
    parameter DOT_MAX_MS     = 250,
    parameter GAP_MS         = 700,
    parameter BTN_ACTIVE_LOW = 1,   // 1: botón da 0 al presionar
    parameter SEG_ACTIVE_LOW = 1    // 1: ánodo común (segmento enciende con 0)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       btn,
    output wire [6:0] hex,          // {g,f,e,d,c,b,a}
    output wire       led_dot,
    output wire       led_dash
);
    wire btn_pressed_raw = BTN_ACTIVE_LOW ? ~btn : btn;
    wire btn_clean;

    debounce #(.CLK_HZ(CLK_HZ), .DB_MS(DB_MS)) u_db (
        .clk(clk), .rst_n(rst_n), .din(btn_pressed_raw), .dout(btn_clean));

    wire [4:0] code;
    wire [2:0] len;
    wire       err, valid;

    morse_fsm #(.CLK_HZ(CLK_HZ), .DOT_MAX_MS(DOT_MAX_MS), .GAP_MS(GAP_MS)) u_fsm (
        .clk(clk), .rst_n(rst_n), .btn(btn_clean),
        .out_code(code), .out_len(len), .out_err(err), .valid(valid),
        .led_dot(led_dot), .led_dash(led_dash));

    wire [6:0] seg_dec;
    morse_to_7seg u_dec (.len(len), .code(code), .seg(seg_dec));

    reg [6:0] seg_reg;    // último carácter decodificado (apagado tras reset)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)      seg_reg <= 7'h00;
        else if (valid)  seg_reg <= err ? 7'h48 : seg_dec;
    end

    assign hex = SEG_ACTIVE_LOW ? ~seg_reg : seg_reg;
endmodule
