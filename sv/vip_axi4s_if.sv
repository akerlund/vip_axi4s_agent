////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2026 Fredrik Åkerlund
// https://github.com/akerlund/VIP
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////

`ifndef VIP_AXI4S_IF
`define VIP_AXI4S_IF

import vip_axi4s_types_pkg::*;

interface vip_axi4s_if #(
  parameter vip_axi4s_cfg_t CFG_P = '{default: '0}
  )(
    input clk,
    input rst_n
  );

  localparam int TDATA_WIDTH_C = 8 * CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TSTRB_WIDTH_C = CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TKEEP_WIDTH_C = CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TID_WIDTH_C   = (CFG_P.VIP_AXI4S_TID_WIDTH_P   > 0) ? CFG_P.VIP_AXI4S_TID_WIDTH_P   : 1;
  localparam int TDEST_WIDTH_C = (CFG_P.VIP_AXI4S_TDEST_WIDTH_P > 0) ? CFG_P.VIP_AXI4S_TDEST_WIDTH_P : 1;
  localparam int TUSER_WIDTH_C = (CFG_P.VIP_AXI4S_TUSER_WIDTH_P > 0) ? CFG_P.VIP_AXI4S_TUSER_WIDTH_P : 1;

  logic                      tvalid;
  logic                      tready;
  logic [TDATA_WIDTH_C-1 : 0] tdata;
  logic [TSTRB_WIDTH_C-1 : 0] tstrb;
  logic [TKEEP_WIDTH_C-1 : 0] tkeep;
  logic                      tlast;
  logic   [TID_WIDTH_C-1 : 0] tid;
  logic [TDEST_WIDTH_C-1 : 0] tdest;
  logic [TUSER_WIDTH_C-1 : 0] tuser;

endinterface

`endif
