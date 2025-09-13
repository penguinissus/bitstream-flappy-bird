/*
 * Copyright (c) 2025 Jocelyn Lau
 */

`default_nettype none
module flappy_bird_top (
    input  wire [7:0] ui_in,   //Dedicated inputs
    output wire [7:0] uo_out,  //Dedicated outputs
    input  wire [7:0] uio_in,  //IOs: Input path
    output wire [7:0] uio_out, //IOs: Output path
    output wire [7:0] uio_oe,  //IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,     //always 1 when design is powered
    input  wire       clk,     //clock
    input  wire       rst_n    //reset: low to reset
);
  //unused outputs assigned to 0
  assign uio_out = 0;
  assign uio_oe = 0;
  //suppress unused signals warning
  wire _unused_ok = &{ena, ui_in[7], ui_in[4:0], uio_in};
  //VGA signals
  wire hsync;
  wire vsync;
  reg [1:0] R;
  reg [1:0] G;
  reg [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;
  //Tiny VGA Pmod
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );
  //Gamepad Pmod
  wire inp_b, inp_y, inp_select, inp_start, inp_up, inp_down, inp_left, inp_right, inp_a, inp_x, inp_l, inp_r;
  gamepad_pmod_single driver (
      //Inputs:
      .rst_n(rst_n),
      .clk(clk),
      .pmod_data(ui_in[6]),
      .pmod_clk(ui_in[5]),
      .pmod_latch(ui_in[4]),
      //Outputs:
      .b(inp_b),
      .y(inp_y),
      .select(inp_select),
      .start(inp_start),
      .up(inp_up),
      .down(inp_down),
      .left(inp_left),
      .right(inp_right),
      .a(inp_a),
      .x(inp_x),
      .l(inp_l),
      .r(inp_r)
  );
  //Game control signals
  wire [8:0] bird_pos;
  wire [8:0] hole_pos;
  wire [9:0] pipe_pos;
  wire [7:0] score;
  gameControl game_ctrl (
      .clock(clk),
      .reset(rst_n),
      .v_sync(vsync),
      .button(inp_up), //Use UP button for flapping
      .bird_pos(bird_pos),
      .hole_pos(hole_pos),
      .pipe_pos(pipe_pos),
      .score(score)
  );
  //Colours
  localparam [5:0] BLACK = {2'b00, 2'b00, 2'b00};
  localparam [5:0] GREEN = {2'b00, 2'b11, 2'b00};
  localparam [5:0] WHITE = {2'b11, 2'b11, 2'b11};
  localparam [5:0] YELLOW = {2'b11, 2'b11, 2'b00};
  localparam [5:0] BLUE = {2'b00, 2'b00, 2'b11};
  //Game object detection
  wire bird_active;
  wire pipe_active;
  wire hole_active;
  //bird rendering (simple 8x8 square at bird position)
  assign bird_active = (pix_x >= 100) && (pix_x < 100) && (pix_y >= bird_pos[8:0]) && (pix_y < bird_pos[8:0]+8);
  //pipe rendering
  wire pipe_visible = (pipe_pos < 640) && (pipe_pos > 0);
  wire in_pipe_x = pipe_visible && (pix_x >= pipe_pos[9:0]) && (pix_x < pipe_pos[9:0]+40);
  //top pipe (from 0 to hole_pos)
  wire top_pipe = in_pipe_x && (pix_y < hole_pos);
  //Bottom pipe (from hole_pos+100 to bottom of screen)
  wire bottom_pipe = in_pipe_x && (pix_y > hole_pos+100);
  assign pipe_active = top_pipe || bottom_pipe;
  assign hole_active = in_pipe_x && (pix_y >= hole_pos) && (pix_y <= hole_pos+100);
  //RGB output logic
  always@(posedge clk) begin
    if (~rst_n) begin
      R <= 0;
      G <= 0;
      B <= 0;
    end else begin
      if (video_active) begin
        if (bird_active) begin
          {R, G, B} <= YELLOW; //Yellow bird
        end else if (pipe_active) begin
          {R, G, B} <= GREEN; //Green pipes
        end else if (hole_active) begin
          {R, G, B} <= BLUE; //Blue hole area
        end else begin
          {R, G, B} <= BLACK; //Black background
        end
      end else begin
        {R, G, B} <= 0;
      end
    end
  end
endmodule
//Game Control Module
module gameControl (
    input wire clock, reset, v_sync, button,
    output reg [8:0] bird_pos, hole_pos,
    output reg [9:0] pipe_pos,
    output reg [7:0] score
);
    reg [8:0] bird_vert_velocity;
    reg [7:0] next_hole_pos;
    reg has_flapped;
    reg game_over;
    reg restart_game;
    reg has_updated_during_current_v_sync;
    reg update_pulse;
    always @(posedge clock)
    begin
        if(!reset || v_sync)
        begin
            has_updated_during_current_v_sync <= 1'b0;
            update_pulse <= 1'b0;
        end
        else if (has_updated_during_current_v_sync == 1'b0)
        begin
            has_updated_during_current_v_sync <= 1'b1;
            update_pulse <= 1'b1;
        end
        else
        begin
            has_updated_during_current_v_sync <= 1'b1;
            update_pulse <= 1'b0;
        end
    end
    always @(posedge clock)
    begin
        if(!reset || restart_game)
        begin
            bird_pos <= 9'd265;
            hole_pos <= 9'd165;
            pipe_pos <= 10'd600;
            next_hole_pos <= 8'd0;
            score <= 8'd0;
            bird_vert_velocity <= 9'd0;
            has_flapped <= 1'b0;
            game_over <= 1'b0;
            restart_game <= 1'b0;
        end
        else if(update_pulse) begin
            if(!game_over)
            begin
                if(!button && !has_flapped)
                begin
                    bird_vert_velocity <= 9'd501;
                    has_flapped <= 1'b1;
                end
                else
                begin
                    if(button)
                        has_flapped <= 1'b0;
                    bird_vert_velocity <= bird_vert_velocity + 9'd1;
                end
                bird_pos <= bird_pos + bird_vert_velocity;
                next_hole_pos <= next_hole_pos + bird_pos[7:0];
                if(pipe_pos == 10'd0)
                begin
                    pipe_pos <= 10'd740;
                    hole_pos <= {1'b0, next_hole_pos} + 9'd37;
                    score <= score + 8'd1;
                end
                else
                begin
                    pipe_pos <= pipe_pos - 10'd4;
                end
                //Collision detection: bird hits ground OR bird hits pipe
                //Bird is at x=100, so check when pipe is at bird's x position (100-140 range for 40px wide pipe)
                if(bird_pos > 9'd472 || bird_pos < 9'd8 || (pipe_pos <= 10'd140 && pipe_pos >= 10'd60 && !(bird_pos >= hole_pos && bird_pos <= hole_pos + 9'd92)))
                game_over <= 1'b1;
            end
            else
            begin
                if(button)
                    has_flapped <= 1'b0;
                bird_pos <= 9'd265;
                pipe_pos <= 10'd600;
                hole_pos <= 9'd165;
            end
        end
    end
endmodule
