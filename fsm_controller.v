module fsm_controller (
    input clk, reset, key_valid, tamper, cancel,
    input [3:0] key_value,
    output reg lock, alarm,
    output reg [6:0] seg,
    output reg [3:0] an
);
    localparam IDLE = 4'd0;
    localparam ENTERING = 4'd1;
    localparam VERIFY = 4'd2;
    localparam UNLOCK = 4'd3;
    localparam WRONG = 4'd4;
    localparam ALARM_STATE = 4'd5;
    localparam SETUP_MODE = 4'd6;
    localparam NEW_PIN_ENTRY = 4'd7;
    localparam CONFIRM_PIN = 4'd8;
    localparam SAVE_PIN = 4'd9;
    localparam PIN_CHANGED = 4'd10;

    parameter PIN_LEN = 4;
    parameter MAX_WRONG = 3;
    parameter [15:0] ADMIN_PIN = 16'd7219;

    reg [3:0] state, next_state;
    reg [15:0] entered_pin;
    reg [15:0] stored_pin;
    reg [15:0] new_pin_temp;
    reg [2:0] wrong_count;
    reg [2:0] digit_count;
    integer fd;
    reg [15:0] memarr [0:0];

    initial begin
        stored_pin = 16'h1234;
        wrong_count = 0;
        digit_count = 0;
        entered_pin = 16'd0;
        $readmemh("pin_data.mem", memarr);
        stored_pin = memarr[0];
        state = IDLE;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        next_state = state;
        lock = 1'b1;
        alarm = 1'b0;
        seg = 7'b1111111;
        an = 4'b1111;
        case (state)
            IDLE: begin
                if (key_valid) next_state = ENTERING;
                if (tamper) next_state = ALARM_STATE;
            end
            ENTERING: begin
                if (digit_count >= PIN_LEN) next_state = VERIFY;
                else if (cancel) next_state = IDLE;
                else if (tamper) next_state = ALARM_STATE;
            end
            VERIFY: begin
                if (entered_pin == ADMIN_PIN) next_state = SETUP_MODE;
                else if (entered_pin == stored_pin) next_state = UNLOCK;
                else next_state = WRONG;
            end
            UNLOCK: begin
                lock = 1'b0;
                seg = 7'b0000110;
                if (cancel) next_state = IDLE;
                if (tamper) next_state = ALARM_STATE;
            end
            WRONG: begin
                seg = 7'b1111001;
            end
            ALARM_STATE: begin
                alarm = 1'b1;
                seg = 7'b0001000;
                if (reset) next_state = IDLE;
            end
            SETUP_MODE: begin
                seg = 7'b0111000;
                if (key_valid) next_state = NEW_PIN_ENTRY;
            end
            NEW_PIN_ENTRY: begin
                seg = 7'b0111111;
                if (digit_count >= PIN_LEN) next_state = CONFIRM_PIN;
            end
            CONFIRM_PIN: begin
                seg = 7'b0000110;
                if (digit_count >= PIN_LEN) next_state = SAVE_PIN;
            end
            SAVE_PIN: begin
                seg = 7'b1000000;
                next_state = PIN_CHANGED;
            end
            PIN_CHANGED: begin
                seg = 7'b0001000;
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            entered_pin <= 16'd0;
            new_pin_temp <= 16'd0;
            digit_count <= 0;
            wrong_count <= 0;
            memarr[0] <= stored_pin;
        end else begin
            if (key_valid) begin
                if (state == ENTERING || state == NEW_PIN_ENTRY || state == CONFIRM_PIN) begin
                    entered_pin <= {entered_pin[11:0], key_value};
                    digit_count <= digit_count + 1;
                end
            end
            if (state != ENTERING && next_state == ENTERING) begin
                entered_pin <= 16'd0;
                digit_count <= 0;
            end
            if (state == VERIFY && next_state == WRONG) wrong_count <= wrong_count + 1;
            if (wrong_count >= MAX_WRONG) alarm <= 1'b1;
            if (state == SAVE_PIN && next_state == PIN_CHANGED) begin
                new_pin_temp <= entered_pin;
                memarr[0] <= entered_pin;
                $writememh("pin_data.mem", memarr);
                stored_pin <= entered_pin;
            end
            if (next_state == IDLE) begin
                entered_pin <= 16'd0;
                digit_count <= 0;
            end
        end
    end
endmodule
