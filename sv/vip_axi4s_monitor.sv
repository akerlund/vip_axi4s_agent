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

class vip_axi4s_monitor #(
  vip_axi4s_cfg_t CFG_P = '{default: '0}
  ) extends uvm_monitor;

  localparam int TDATA_WIDTH_C = 8 * CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TSTRB_WIDTH_C = CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TKEEP_WIDTH_C = CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TID_WIDTH_C   = (CFG_P.VIP_AXI4S_TID_WIDTH_P   > 0) ? CFG_P.VIP_AXI4S_TID_WIDTH_P   : 1;
  localparam int TDEST_WIDTH_C = (CFG_P.VIP_AXI4S_TDEST_WIDTH_P > 0) ? CFG_P.VIP_AXI4S_TDEST_WIDTH_P : 1;
  localparam int TUSER_WIDTH_C = (CFG_P.VIP_AXI4S_TUSER_WIDTH_P > 0) ? CFG_P.VIP_AXI4S_TUSER_WIDTH_P : 1;

  // Analysis ports
  uvm_analysis_port #(vip_axi4s_item #(CFG_P)) tdata_port;

  // Class variables
  protected virtual vip_axi4s_if #(CFG_P) _vif;
  protected int                           _id;

  // Ingress data is saved in dynamic list
  protected logic [TDATA_WIDTH_C-1 : 0] _tdata_beats [$];
  protected logic [TSTRB_WIDTH_C-1 : 0] _tstrb_beats [$];
  protected logic [TKEEP_WIDTH_C-1 : 0] _tkeep_beats [$];
  protected logic [TUSER_WIDTH_C-1 : 0] _tuser_beats [$];

  `uvm_component_param_utils_begin(vip_axi4s_monitor #(CFG_P))
    `uvm_field_int(_id, UVM_DEFAULT)
  `uvm_component_utils_end

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function new(string name, uvm_component parent);

    super.new(name, parent);

    tdata_port = new("tdata_port", this);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db #(virtual vip_axi4s_if #(CFG_P))::get(this, "", "vif", _vif)) begin

      `uvm_fatal(get_name(), $sformatf(
      "FATAL [%s] Virtual interface must be set for: %s.vif",
      get_name(), get_full_name()))
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);

    forever begin

      fork

        begin

          @(posedge _vif.rst_n);
          this.monitor_start();
        end
      join_none

      @(negedge _vif.rst_n);
      disable fork;
      this.handle_reset();
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task monitor_start();

    fork

      this.collect_transfers();
      this.check_protocol();
    join
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void handle_reset();
    _tdata_beats.delete();
    _tstrb_beats.delete();
    _tkeep_beats.delete();
    _tuser_beats.delete();
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task collect_transfers();

    vip_axi4s_item #(CFG_P) axi4s_item;

    forever begin

      @(posedge _vif.clk);

      if (_vif.tvalid === '1 && _vif.tready === '1) begin
        _tdata_beats.push_back(_vif.tdata);
        _tstrb_beats.push_back(_vif.tstrb);
        _tkeep_beats.push_back(_vif.tkeep);
        _tuser_beats.push_back(_vif.tuser);
      end

      if (_vif.tvalid === '1 && _vif.tready === '1 && _vif.tlast === '1) begin

        axi4s_item       = new();
        axi4s_item.tid   = _vif.tid;
        axi4s_item.tdest = _vif.tdest;
        axi4s_item.tdata = new[_tdata_beats.size()];
        axi4s_item.tstrb = new[_tstrb_beats.size()];
        axi4s_item.tkeep = new[_tkeep_beats.size()];
        axi4s_item.tuser = new[_tuser_beats.size()];
        foreach (_tdata_beats[i]) begin axi4s_item.tdata[i] = _tdata_beats[i]; end
        foreach (_tstrb_beats[i]) begin axi4s_item.tstrb[i] = _tstrb_beats[i]; end
        foreach (_tkeep_beats[i]) begin axi4s_item.tkeep[i] = _tkeep_beats[i]; end
        foreach (_tuser_beats[i]) begin axi4s_item.tuser[i] = _tuser_beats[i]; end
        _tdata_beats.delete();
        _tstrb_beats.delete();
        _tkeep_beats.delete();
        _tuser_beats.delete();

        `uvm_info(get_type_name(), $sformatf("Collected transfer:\n%s", axi4s_item.sprint()), UVM_HIGH)
        tdata_port.write(axi4s_item);
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task check_protocol();

    bit                          prev_stalled;
    logic [TDATA_WIDTH_C-1 : 0]  prev_tdata;
    logic [TSTRB_WIDTH_C-1 : 0]  prev_tstrb;
    logic [TKEEP_WIDTH_C-1 : 0]  prev_tkeep;
    logic                       prev_tlast;
    logic   [TID_WIDTH_C-1 : 0]  prev_tid;
    logic [TDEST_WIDTH_C-1 : 0]  prev_tdest;
    logic [TUSER_WIDTH_C-1 : 0]  prev_tuser;

    prev_stalled = 0;

    forever begin

      @(posedge _vif.clk);

      if (prev_stalled) begin

        if (_vif.tvalid !== 1'b1) begin

          `uvm_error(get_name(), "TVALID deasserted before a handshake completed")
        end else begin

          if (_vif.tdata !== prev_tdata) begin
            `uvm_error(get_name(), "TDATA changed while TVALID was asserted and TREADY was low")
          end

          if (_vif.tstrb !== prev_tstrb) begin
            `uvm_error(get_name(), "TSTRB changed while TVALID was asserted and TREADY was low")
          end

          if (_vif.tkeep !== prev_tkeep) begin
            `uvm_error(get_name(), "TKEEP changed while TVALID was asserted and TREADY was low")
          end

          if (_vif.tlast !== prev_tlast) begin
            `uvm_error(get_name(), "TLAST changed while TVALID was asserted and TREADY was low")
          end

          if (_vif.tid !== prev_tid) begin
            `uvm_error(get_name(), "TID changed while TVALID was asserted and TREADY was low")
          end

          if (_vif.tdest !== prev_tdest) begin
            `uvm_error(get_name(), "TDEST changed while TVALID was asserted and TREADY was low")
          end

          if (_vif.tuser !== prev_tuser) begin
            `uvm_error(get_name(), "TUSER changed while TVALID was asserted and TREADY was low")
          end
        end
      end

      if (_vif.tvalid === 1'b1) begin

        if (CFG_P.VIP_AXI4S_TID_WIDTH_P == 0 && _vif.tid !== '0) begin
          `uvm_error(get_name(), "TID must be zero when VIP_AXI4S_TID_WIDTH_P is 0")
        end

        if (CFG_P.VIP_AXI4S_TDEST_WIDTH_P == 0 && _vif.tdest !== '0) begin
          `uvm_error(get_name(), "TDEST must be zero when VIP_AXI4S_TDEST_WIDTH_P is 0")
        end

        if (CFG_P.VIP_AXI4S_TUSER_WIDTH_P == 0 && _vif.tuser !== '0) begin
          `uvm_error(get_name(), "TUSER must be zero when VIP_AXI4S_TUSER_WIDTH_P is 0")
        end
      end

      prev_stalled = (_vif.tvalid === 1'b1 && _vif.tready !== 1'b1);
      prev_tdata   = _vif.tdata;
      prev_tstrb   = _vif.tstrb;
      prev_tkeep   = _vif.tkeep;
      prev_tlast   = _vif.tlast;
      prev_tid     = _vif.tid;
      prev_tdest   = _vif.tdest;
      prev_tuser   = _vif.tuser;
    end
  endtask
endclass
