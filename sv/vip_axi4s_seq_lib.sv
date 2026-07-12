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

// -----------------------------------------------------------------------------
// Base Sequence
// -----------------------------------------------------------------------------
class vip_axi4s_base_seq #(vip_axi4s_cfg_t CFG_P = '{default: '0})
  extends uvm_sequence #(vip_axi4s_item #(CFG_P));

  `uvm_object_param_utils(vip_axi4s_base_seq #(CFG_P))

  localparam int TDATA_WIDTH_C = 8 * CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TID_WIDTH_C   = (CFG_P.VIP_AXI4S_TID_WIDTH_P   > 0) ? CFG_P.VIP_AXI4S_TID_WIDTH_P   : 1;
  localparam int TDEST_WIDTH_C = (CFG_P.VIP_AXI4S_TDEST_WIDTH_P > 0) ? CFG_P.VIP_AXI4S_TDEST_WIDTH_P : 1;
  localparam int TUSER_WIDTH_C = (CFG_P.VIP_AXI4S_TUSER_WIDTH_P > 0) ? CFG_P.VIP_AXI4S_TUSER_WIDTH_P : 1;

  typedef logic [TDATA_WIDTH_C-1 : 0] tdata_t [$];
  typedef logic [TUSER_WIDTH_C-1 : 0] tuser_t [$];

  protected bool_t                _verbose         = TRUE;
  protected int                   _log_denominator = 100;
  protected vip_axi4s_item_config _cfg;
  protected int                   _nr_of_bursts    = 1;
  protected tdata_t               _tdata;
  protected tuser_t               _tuser;

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function new(string name = "vip_axi4s_base_seq");

    super.new(name);

    _cfg = new();
    _cfg.max_tid          = (CFG_P.VIP_AXI4S_TID_WIDTH_P   > 0) ? 2**CFG_P.VIP_AXI4S_TID_WIDTH_P   - 1 : 0;
    _cfg.max_tdest        = (CFG_P.VIP_AXI4S_TDEST_WIDTH_P > 0) ? 2**CFG_P.VIP_AXI4S_TDEST_WIDTH_P - 1 : 0;
    _cfg.max_burst_length = 256;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_verbose(input bool_t verbose);
    _verbose = verbose;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_log_denominator(input int log_denominator);
    _log_denominator = log_denominator;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_id_type(input vip_axi4s_tid_type_t axi4s_tid_type);
    _cfg.axi4s_tid_type = axi4s_tid_type;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tdata_type(input vip_axi4s_tdata_type_t axi4s_tdata_type);
    _cfg.axi4s_tdata_type = axi4s_tdata_type;
    if (_cfg.axi4s_tdata_type == VIP_AXI4S_TDATA_CUSTOM_E) begin
      _nr_of_bursts = 1;
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tdest_type(input vip_axi4s_tdest_type_t axi4s_tdest_type);

    _cfg.axi4s_tdest_type = axi4s_tdest_type;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tuser_type(input vip_axi4s_tuser_type_t axi4s_tuser_type);

    _cfg.axi4s_tuser_type = axi4s_tuser_type;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tdata(input tdata_t tdata);
    _tdata = tdata;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tuser(input tuser_t tuser);
    _tuser = tuser;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tuser_counter(input int counter);
    _cfg.tuser_counter = counter;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_nr_of_bursts(input int nr_of_bursts);
    _nr_of_bursts = nr_of_bursts;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tdata_counter(input int counter);
    _cfg.tdata_counter = counter;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function int get_tdata_counter();
    get_tdata_counter = _cfg.tdata_counter;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tid(
    input logic [TID_WIDTH_C-1 : 0] tid
  );
    _cfg.min_tid = tid;
    _cfg.max_tid = tid;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tdest(
    input logic [TDEST_WIDTH_C-1 : 0] tdest
  );
    _cfg.min_tdest = tdest;
    _cfg.max_tdest = tdest;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_burst_length(input int burst_length);
    _cfg.min_burst_length = burst_length;
    _cfg.max_burst_length = burst_length;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_tstrb_type(input vip_axi4s_tstrb_t axi4s_tstrb_type);
    _cfg.axi4s_tstrb_type = axi4s_tstrb_type;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_cfg_tid(
    input int max_tid,
    input int min_tid
  );
    _cfg.min_tid = min_tid;
    _cfg.max_tid = max_tid;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_cfg_tdest(
    input int max_tdest,
    input int min_tdest
  );
    _cfg.min_tdest = min_tdest;
    _cfg.max_tdest = max_tdest;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void set_cfg_burst_length(
    input int max_burst_length,
    input int min_burst_length
  );
    _cfg.min_burst_length = min_burst_length;
    _cfg.max_burst_length = max_burst_length;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  task body();

    // Iterate bursts
    for (int i = 0; i < _nr_of_bursts; i++) begin

      // New item for each transaction
      req = vip_axi4s_item #(CFG_P)::type_id::create($sformatf("vip_axi4s_item_%0d", i));

      // Status
      if ((_verbose == TRUE) && (((i % _log_denominator) == 0) || (i == (_nr_of_bursts - 1)))) begin

        `uvm_info(get_name(), $sformatf(
        "%s (%0d/%0d)", "Burst", i+1, _nr_of_bursts), UVM_LOW)
      end

      // Set any available TDATA
      if (_cfg.axi4s_tdata_type == VIP_AXI4S_TDATA_CUSTOM_E) begin

        req.set_tdata(_tdata);
        this.set_burst_length(_tdata.size());
      end

      // Set any available TUSER
      if (_cfg.axi4s_tuser_type == VIP_AXI4S_TUSER_CUSTOM_E) begin

        req.set_tuser(_tuser);
      end

      // Set configuration and randomize
      req.set_config(_cfg);
      if (!req.randomize()) begin

        `uvm_error(get_name(), $sformatf("randomize() failed"))
      end

      // Start
      super.start_item(req);
      super.finish_item(req);
    end
  endtask
endclass

// -----------------------------------------------------------------------------
// Blank sequence
// -----------------------------------------------------------------------------
class vip_axi4s_seq #(vip_axi4s_cfg_t CFG_P = '{default: '0})
  extends vip_axi4s_base_seq #(CFG_P);

  `uvm_object_param_utils(vip_axi4s_seq #(CFG_P))

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function new(string name = "vip_axi4s_seq");
    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  task body();
    super.body();
  endtask
endclass
