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

class vip_axi4s_driver_callback #(
  vip_axi4s_cfg_t CFG_P = '{default: '0}
  ) extends uvm_object;

  `uvm_object_param_utils(vip_axi4s_driver_callback #(CFG_P))

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "vip_axi4s_driver_callback");

    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  // Called before the first beat of a packet is driven
  // ---------------------------------------------------------------------------
  virtual function void pre_packet(
    input uvm_component              driver,
    input vip_axi4s_item #(CFG_P)    item
  );
  endfunction

  // ---------------------------------------------------------------------------
  // Called after the last beat of a packet was handshaken
  // ---------------------------------------------------------------------------
  virtual function void post_packet(
    input uvm_component              driver,
    input vip_axi4s_item #(CFG_P)    item
  );
  endfunction

  // ---------------------------------------------------------------------------
  // Called before a beat is driven
  // ---------------------------------------------------------------------------
  virtual function void pre_beat(
    input uvm_component              driver,
    input vip_axi4s_item #(CFG_P)    item,
    input int unsigned               beat_index
  );
  endfunction

  // ---------------------------------------------------------------------------
  // Called after a beat was handshaken
  // ---------------------------------------------------------------------------
  virtual function void post_beat(
    input uvm_component              driver,
    input vip_axi4s_item #(CFG_P)    item,
    input int unsigned               beat_index
  );
  endfunction

  // ---------------------------------------------------------------------------
  // Called before the driver parks the bus at reset
  // ---------------------------------------------------------------------------
  virtual function void pre_reset(input uvm_component driver);
  endfunction

  // ---------------------------------------------------------------------------
  // Called after the driver parked the bus at reset
  // ---------------------------------------------------------------------------
  virtual function void post_reset(input uvm_component driver);
  endfunction
endclass

class vip_axi4s_monitor_callback #(
  vip_axi4s_cfg_t CFG_P = '{default: '0}
  ) extends uvm_object;

  `uvm_object_param_utils(vip_axi4s_monitor_callback #(CFG_P))

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "vip_axi4s_monitor_callback");

    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  // Called for every beat the monitor samples
  // ---------------------------------------------------------------------------
  virtual function void beat_sampled(
    input uvm_component              monitor,
    input vip_axi4s_item #(CFG_P)    beat
  );
  endfunction

  // ---------------------------------------------------------------------------
  // Called for every packet the monitor completes
  // ---------------------------------------------------------------------------
  virtual function void packet_completed(
    input uvm_component              monitor,
    input vip_axi4s_item #(CFG_P)    packet
  );
  endfunction

  // ---------------------------------------------------------------------------
  // Called for every check the monitor reports
  // ---------------------------------------------------------------------------
  virtual function void checker_violation(
    input uvm_component              monitor,
    input vip_axi4s_check_t          check,
    input string                     message
  );
  endfunction
endclass
