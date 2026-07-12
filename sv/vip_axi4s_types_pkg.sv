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

`ifndef VIP_AXI4S_TYPES_PKG
`define VIP_AXI4S_TYPES_PKG

package vip_axi4s_types_pkg;

  typedef enum bit {
    FALSE,
    TRUE
  } bool_t;

  typedef enum {
    VIP_AXI4S_MASTER_AGENT_E,
    VIP_AXI4S_SLAVE_AGENT_E
  } vip_axi4s_agent_type_t;

  typedef struct packed {
    int VIP_AXI4S_TDATA_BYTES_P;
    int VIP_AXI4S_TID_WIDTH_P;
    int VIP_AXI4S_TDEST_WIDTH_P;
    int VIP_AXI4S_TUSER_WIDTH_P;
  } vip_axi4s_cfg_t;

  typedef enum {
    VIP_AXI4S_TID_COUNTER_E,
    VIP_AXI4S_TID_RANDOM_E
  } vip_axi4s_tid_type_t;

  typedef enum {
    VIP_AXI4S_TDATA_COUNTER_E,
    VIP_AXI4S_TDATA_RANDOM_E,
    VIP_AXI4S_TDATA_ZEROS_E,
    VIP_AXI4S_TDATA_ONES_E,
    VIP_AXI4S_TDATA_CUSTOM_E
  } vip_axi4s_tdata_type_t;

  typedef enum {
    VIP_AXI4S_TUSER_COUNTER_E,
    VIP_AXI4S_TUSER_RANDOM_E,
    VIP_AXI4S_TUSER_ZEROS_E,
    VIP_AXI4S_TUSER_ONES_E,
    VIP_AXI4S_TUSER_CUSTOM_E
  } vip_axi4s_tuser_type_t;

  typedef enum {
    VIP_AXI4S_TDEST_INCR_E,
    VIP_AXI4S_TDEST_CUSTOM_E
  } vip_axi4s_tdest_type_t;

  typedef enum {
    VIP_AXI4S_TSTRB_ALL_E,
    VIP_AXI4S_TSTRB_RANDOM_E
  } vip_axi4s_tstrb_t;
endpackage

`endif
