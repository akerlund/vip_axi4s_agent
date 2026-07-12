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

class vip_axi4s_item_config extends uvm_object;

  vip_axi4s_tdata_type_t axi4s_tdata_type = VIP_AXI4S_TDATA_COUNTER_E;
  vip_axi4s_tstrb_t      axi4s_tstrb_type = VIP_AXI4S_TSTRB_ALL_E;
  vip_axi4s_tid_type_t   axi4s_tid_type   = VIP_AXI4S_TID_COUNTER_E;
  vip_axi4s_tdest_type_t axi4s_tdest_type = VIP_AXI4S_TDEST_INCR_E;
  vip_axi4s_tuser_type_t axi4s_tuser_type = VIP_AXI4S_TUSER_ZEROS_E;
  longint                tdata_counter    = 0;
  longint                tid_counter      = 0;
  longint                tdest_counter    = 0;
  longint                tuser_counter    = 0;

  int min_tid          = 0;
  int max_tid          = 0;
  int min_tdest        = 0;
  int max_tdest        = 0;
  int min_burst_length = 1;
  int max_burst_length = 1;

  `uvm_object_utils_begin(vip_axi4s_item_config);
    `uvm_field_enum(vip_axi4s_tdata_type_t, axi4s_tdata_type, UVM_ALL_ON)
    `uvm_field_enum(vip_axi4s_tstrb_t,      axi4s_tstrb_type, UVM_ALL_ON)
    `uvm_field_enum(vip_axi4s_tid_type_t,   axi4s_tid_type,   UVM_ALL_ON)
    `uvm_field_enum(vip_axi4s_tdest_type_t, axi4s_tdest_type, UVM_ALL_ON)
    `uvm_field_enum(vip_axi4s_tuser_type_t, axi4s_tuser_type, UVM_ALL_ON)
    `uvm_field_int(tdata_counter,                             UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(tid_counter,                               UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(tdest_counter,                             UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(tuser_counter,                             UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(min_tid,                                   UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(max_tid,                                   UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(min_tdest,                                 UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(max_tdest,                                 UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(min_burst_length,                          UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(max_burst_length,                          UVM_ALL_ON | UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "vip_axi4s_item_config");
    super.new(name);
  endfunction
endclass
