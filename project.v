/*
 * Copyright (c) 2025 Jocelyn Lau
 */

default_nettype none
module flappy_bird_top (
    input  wire [7:0] ui_in,   //Dedicated inputs
    output wire [7:0] uo_out,  //Dedicated outputs
    input  wire [7:0] uio_in,  //IOs: Input path
    output wire [7:0] uio_out, //IOs: Output path
    output wire [7:0] uio_ou,  //IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,     //always 1 when design is powered
    input  wire       clk,     //clock
    input  wire       rst_n    //reset: low to reset
);
