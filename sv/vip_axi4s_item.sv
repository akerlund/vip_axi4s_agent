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

class vip_axi4s_item #(
  vip_axi4s_cfg_t CFG_P = '{default: '0}
  ) extends uvm_sequence_item;

  localparam int TDATA_WIDTH_C = 8 * CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TSTRB_WIDTH_C = CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TKEEP_WIDTH_C = CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TID_WIDTH_C   = (CFG_P.VIP_AXI4S_TID_WIDTH_P   > 0) ? CFG_P.VIP_AXI4S_TID_WIDTH_P   : 1;
  localparam int TDEST_WIDTH_C = (CFG_P.VIP_AXI4S_TDEST_WIDTH_P > 0) ? CFG_P.VIP_AXI4S_TDEST_WIDTH_P : 1;
  localparam int TUSER_WIDTH_C = (CFG_P.VIP_AXI4S_TUSER_WIDTH_P > 0) ? CFG_P.VIP_AXI4S_TUSER_WIDTH_P : 1;

  // ---------------------------------------------------------------------------
  // AXI4-S signals
  // ---------------------------------------------------------------------------

  rand logic [TDATA_WIDTH_C-1 : 0] tdata [];
  rand logic [TSTRB_WIDTH_C-1 : 0] tstrb [];
  rand logic [TKEEP_WIDTH_C-1 : 0] tkeep [];
  rand logic   [TID_WIDTH_C-1 : 0] tid       = '0;
  rand logic [TDEST_WIDTH_C-1 : 0] tdest     = '0;
  rand logic [TUSER_WIDTH_C-1 : 0] tuser [];
  rand int                         burst_length;


  `uvm_object_param_utils_begin(vip_axi4s_item #(CFG_P))
    `uvm_field_int(tid,          UVM_DEFAULT)
    `uvm_field_int(tdest,        UVM_DEFAULT)
    `uvm_field_sarray_int(tdata, UVM_DEFAULT)
    `uvm_field_sarray_int(tstrb, UVM_DEFAULT)
    `uvm_field_sarray_int(tkeep, UVM_DEFAULT)
    `uvm_field_sarray_int(tuser, UVM_DEFAULT)
    `uvm_field_int(burst_length, UVM_DEFAULT)
  `uvm_object_utils_end

  protected vip_axi4s_item_config       _cfg;
  protected logic [TDATA_WIDTH_C-1 : 0] _tdata [$];
  protected logic [TUSER_WIDTH_C-1 : 0] _tuser [$];

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function new(string name = "vip_axi4s_item");
    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void print_config();

    `uvm_info(get_name(), {"VIP AXI4 item config:\n", _cfg.sprint()}, UVM_LOW)
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_config(ref vip_axi4s_item_config cfg);
    _cfg = cfg;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tdata_counter(
    input logic [TDATA_WIDTH_C-1 : 0] tdata_counter
  );
    _cfg.tdata_counter = tdata_counter;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tuser_counter(
    input logic [TUSER_WIDTH_C-1 : 0] tuser_counter
  );
    _cfg.tuser_counter = tuser_counter;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tdata(
    input logic [TDATA_WIDTH_C-1 : 0] tdata [$]
  );
    _tdata = tdata;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tuser(
    input logic [TUSER_WIDTH_C-1 : 0] tuser [$]
  );
    _tuser = tuser;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void pre_randomize();

    if (_cfg.min_burst_length < 1) begin

      `uvm_fatal(get_name(), $sformatf(
      "min_burst_length (%0d) must be at least 1",
      _cfg.min_burst_length))
    end

    if (_cfg.max_burst_length < _cfg.min_burst_length) begin

      `uvm_fatal(get_name(), $sformatf(
      "max_burst_length (%0d) must be >= min_burst_length (%0d)",
      _cfg.max_burst_length, _cfg.min_burst_length))
    end

    // Custom TDATA are always completely transferred
    if (_cfg.axi4s_tdata_type == VIP_AXI4S_TDATA_CUSTOM_E) begin

      // Fatal check
      if (_tdata.size() == 0) begin

        `uvm_fatal(get_name(), "tdata has size 0")
      end

      _cfg.min_burst_length = _tdata.size();
      _cfg.max_burst_length = _tdata.size();
    end

    if (_cfg.axi4s_tuser_type == VIP_AXI4S_TUSER_CUSTOM_E) begin

      if (_tuser.size() == 0) begin

        `uvm_fatal(get_name(), "tuser has size 0")
      end

      if (_tuser.size() < _cfg.max_burst_length) begin

        `uvm_fatal(get_name(), $sformatf(
        "tuser has size %0d but max burst length is %0d",
        _tuser.size(), _cfg.max_burst_length))
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void post_randomize();

    // Increase TDATA counter
    if (_cfg.axi4s_tdata_type == VIP_AXI4S_TDATA_COUNTER_E) begin

      _cfg.tdata_counter += burst_length;
    end

    // Increase TID counter
    if (_cfg.axi4s_tid_type == VIP_AXI4S_TID_COUNTER_E) begin

      _cfg.tid_counter++;
    end

    // Increase TDEST counter
    if (_cfg.axi4s_tdest_type == VIP_AXI4S_TDEST_INCR_E) begin

      _cfg.tdest_counter += (burst_length * CFG_P.VIP_AXI4S_TDATA_BYTES_P);
    end

    // Increase TUSER counter
    if (_cfg.axi4s_tuser_type == VIP_AXI4S_TUSER_COUNTER_E) begin

      _cfg.tuser_counter += burst_length;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Constraints
  // ---------------------------------------------------------------------------

  constraint con_burst_length {
    burst_length >= _cfg.min_burst_length;
    burst_length <= _cfg.max_burst_length;
  }

  constraint con_array_sizes {
    tdata.size == burst_length;
    tstrb.size == burst_length;
    tkeep.size == burst_length;
    tuser.size == burst_length;
  }

  constraint con_tdata_val {
    if (_cfg.axi4s_tdata_type == VIP_AXI4S_TDATA_COUNTER_E) {
      foreach (tdata[i]) {
        tdata[i] == _cfg.tdata_counter + i;
      }
    } else if (_cfg.axi4s_tdata_type == VIP_AXI4S_TDATA_CUSTOM_E) {
      foreach (tdata[i]) {
        tdata[i] == _tdata[i];
      }
    } else if (_cfg.axi4s_tdata_type == VIP_AXI4S_TDATA_ZEROS_E) {
      foreach (tdata[i]) {
        tdata[i] == '0;
      }
    } else if (_cfg.axi4s_tdata_type == VIP_AXI4S_TDATA_ONES_E) {
      foreach (tdata[i]) {
        tdata[i] == '1;
      }
    }
  }

  constraint con_tstrb_val {
    if (_cfg.axi4s_tstrb_type == VIP_AXI4S_TSTRB_ALL_E) {
      foreach (tstrb[i]) {
        tstrb[i] == '1;
      }
    } else {
      foreach (tstrb[i]) {
        tstrb[i] != 0;
      }
    }
  }

  constraint con_tkeep_val {
    foreach (tkeep[i]) {
      tkeep[i] == '1;
    }
  }

  constraint con_tid {
    if (CFG_P.VIP_AXI4S_TID_WIDTH_P == 0) {
      tid == '0;
    } else if (_cfg.axi4s_tid_type == VIP_AXI4S_TID_COUNTER_E) {
      tid == _cfg.tid_counter;
    } else {
      tid >= _cfg.min_tid;
      tid <= _cfg.max_tid;
    }
  }

  constraint con_tdest {
    if (CFG_P.VIP_AXI4S_TDEST_WIDTH_P == 0) {
      tdest == '0;
    } else if (_cfg.axi4s_tdest_type == VIP_AXI4S_TDEST_INCR_E) {
      tdest == _cfg.tdest_counter;
    } else {
      tdest >= _cfg.min_tdest;
      tdest <= _cfg.max_tdest;
    }
  }

  constraint con_tuser_val {
    if (CFG_P.VIP_AXI4S_TUSER_WIDTH_P == 0) {
      foreach (tuser[i]) {
        tuser[i] == '0;
      }
    } else if (_cfg.axi4s_tuser_type == VIP_AXI4S_TUSER_COUNTER_E) {
      foreach (tuser[i]) {
        tuser[i] == _cfg.tuser_counter + i;
      }
    } else if (_cfg.axi4s_tuser_type == VIP_AXI4S_TUSER_CUSTOM_E) {
      foreach (tuser[i]) {
        tuser[i] == _tuser[i];
      }
    } else if (_cfg.axi4s_tuser_type == VIP_AXI4S_TUSER_ZEROS_E) {
      foreach (tuser[i]) {
        tuser[i] == '0;
      }
    } else if (_cfg.axi4s_tuser_type == VIP_AXI4S_TUSER_ONES_E) {
      foreach (tuser[i]) {
        tuser[i] == '1;
      }
    }
  }
endclass
