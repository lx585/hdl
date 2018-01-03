// ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2017 (c) Analog Devices, Inc. All rights reserved.
//
// Each core or library found in this collection may have its own licensing terms. 
// The user should keep this in in mind while exploring these cores. 
//
// Redistribution and use in source and binary forms,
// with or without modification of this file, are permitted under the terms of either
//  (at the option of the user):
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory, or at:
// https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html
//
// OR
//
//   2.  An ADI specific BSD license as noted in the top level directory, or on-line at:
// https://github.com/analogdevicesinc/hdl/blob/dev/LICENSE
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module axi_adc_jesd204_if #(
  parameter NUM_LANES = 1,
  parameter NUM_CHANNELS = 1,
  parameter CHANNEL_WIDTH = 16,
  parameter OCT_PER_SAMPLE = 2
) (
  // jesd interface
  // rx_clk is (line-rate/40)

  input                                       rx_clk,
  input       [3:0]                           rx_sof,
  input       [NUM_LANES*32-1:0]              rx_data,

   // adc data output

   output     [NUM_LANES*CHANNEL_WIDTH*(4/OCT_PER_SAMPLE)-1:0]  adc_data
 );

   localparam TAIL_BITS = (OCT_PER_SAMPLE > 1) ? (16 - CHANNEL_WIDTH) : (8 - CHANNEL_WIDTH);
   localparam DATA_PATH_WIDTH = (4/OCT_PER_SAMPLE) * NUM_LANES / NUM_CHANNELS;
   localparam H = NUM_LANES / NUM_CHANNELS / 2;
   localparam HD = NUM_LANES > NUM_CHANNELS ? 1 : 0;
   localparam OCT_OFFSET = HD ? 32 : 8;

  wire [NUM_LANES*32-1:0] rx_data_s;

  // data multiplex

  genvar i;
  genvar j;
  generate
  if (OCT_PER_SAMPLE == 2) begin
    for (i = 0; i < NUM_CHANNELS; i = i + 1) begin: g_deframer_outer
      for (j = 0; j < DATA_PATH_WIDTH; j = j + 1) begin: g_deframer_inner
        localparam k = j + i * DATA_PATH_WIDTH;
        localparam adc_lsb = k * CHANNEL_WIDTH;
        localparam oct0_lsb = HD ? ((i * H + j % H) * 64 + (j / H) * 8) : (k * 16);
        localparam oct1_lsb = oct0_lsb + OCT_OFFSET + TAIL_BITS;

        assign adc_data[adc_lsb+:CHANNEL_WIDTH] = {
            rx_data_s[oct0_lsb+:8],
            rx_data_s[oct1_lsb+:8-TAIL_BITS]
          };
      end
    end
  end else begin // OCT_PER_SAMPLE == 1
    for (i = 0; i < NUM_CHANNELS; i = i + 1) begin: g_deframer_outer
      for (j = 0; j < DATA_PATH_WIDTH; j = j + 1) begin: g_deframer_inner
        localparam k = j + i * DATA_PATH_WIDTH;
        localparam adc_lsb = k * CHANNEL_WIDTH;
        localparam oct_lsb = k * 8;

        assign adc_data[adc_lsb+:CHANNEL_WIDTH] = rx_data_s[oct_lsb+:8-TAIL_BITS];
      end
    end
  end
  endgenerate

  // frame-alignment

  generate
  genvar n;
  for (n = 0; n < NUM_LANES; n = n + 1) begin: g_xcvr_if
    ad_xcvr_rx_if  i_xcvr_if (
      .rx_clk (rx_clk),
      .rx_ip_sof (rx_sof),
      .rx_ip_data (rx_data[n*32+:32]),
      .rx_sof (),
      .rx_data (rx_data_s[n*32+:32])
    );
  end
  endgenerate

endmodule
