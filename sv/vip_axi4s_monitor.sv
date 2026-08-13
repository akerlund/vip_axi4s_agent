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

class vip_axi4s_monitor_packet_state #(
  vip_axi4s_cfg_t CFG_P = '{default: '0}
  ) extends uvm_object;

  localparam int TDATA_WIDTH_C = 8 * CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TSTRB_WIDTH_C = CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TKEEP_WIDTH_C = CFG_P.VIP_AXI4S_TDATA_BYTES_P;
  localparam int TID_WIDTH_C   = (CFG_P.VIP_AXI4S_TID_WIDTH_P   > 0) ? CFG_P.VIP_AXI4S_TID_WIDTH_P   : 1;
  localparam int TDEST_WIDTH_C = (CFG_P.VIP_AXI4S_TDEST_WIDTH_P > 0) ? CFG_P.VIP_AXI4S_TDEST_WIDTH_P : 1;
  localparam int TUSER_WIDTH_C = (CFG_P.VIP_AXI4S_TUSER_WIDTH_P > 0) ? CFG_P.VIP_AXI4S_TUSER_WIDTH_P : 1;

  logic [TDATA_WIDTH_C-1 : 0] tdata [$];
  logic [TSTRB_WIDTH_C-1 : 0] tstrb [$];
  logic [TKEEP_WIDTH_C-1 : 0] tkeep [$];
  logic [TUSER_WIDTH_C-1 : 0] tuser [$];
  logic   [TID_WIDTH_C-1 : 0] tid;
  logic [TDEST_WIDTH_C-1 : 0] tdest;
  int unsigned                stall_cycles;
  int unsigned                start_cycle;
  bit                         has_nonzero_tuser;

  `uvm_object_param_utils(vip_axi4s_monitor_packet_state #(CFG_P))

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "vip_axi4s_monitor_packet_state");

    super.new(name);
  endfunction
endclass

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
  uvm_analysis_port #(vip_axi4s_item #(CFG_P)) packet_start_port;
  uvm_analysis_port #(vip_axi4s_item #(CFG_P)) beat_port;
  uvm_analysis_port #(string)                   violation_port;
  uvm_analysis_port #(string)                   stats_port;

  vip_axi4s_config cfg;
  vip_axi4s_monitor_callback #(CFG_P) callbacks [$];

  covergroup _packet_cg with function sample(
    int unsigned length,
    int unsigned stream_type,
    int unsigned tid_nonzero,
    int unsigned tdest_nonzero,
    int unsigned backpressure_bin,
    int unsigned reset_bin
  );
    option.per_instance = 1;
    packet_length_cp: coverpoint length {
      bins one_len    = {1};
      bins short_len  = {[2:15]};
      bins medium_len = {[16:255]};
      bins large_len  = {[256:$]};
    }
    stream_type_cp: coverpoint stream_type {
      bins byte_stream                 = {int'(VIP_AXI4S_BYTE_STREAM_E)};
      bins continuous_aligned_stream   = {int'(VIP_AXI4S_CONTINUOUS_ALIGNED_STREAM_E)};
      bins continuous_unaligned_stream = {int'(VIP_AXI4S_CONTINUOUS_UNALIGNED_STREAM_E)};
      bins sparse_stream               = {int'(VIP_AXI4S_SPARSE_STREAM_E)};
      bins user_stream                 = {int'(VIP_AXI4S_USER_STREAM_E)};
    }
    tid_cp: coverpoint tid_nonzero {
      bins zero    = {0};
      bins nonzero = {1};
    }
    tdest_cp: coverpoint tdest_nonzero {
      bins zero    = {0};
      bins nonzero = {1};
    }
    backpressure_cp: coverpoint backpressure_bin {
      bins none  = {0};
      bins short = {1};
      bins long  = {2};
    }
    reset_cp: coverpoint reset_bin {
      bins no_reset = {0};
      bins reset    = {1};
    }
    stream_shape_by_tid_tdest: cross stream_type_cp, tid_cp, tdest_cp;
  endgroup

  covergroup _beat_cg with function sample(
    int unsigned tkeep_class,
    int unsigned tstrb_class,
    int unsigned tvalid_delay_bin,
    int unsigned tready_stall_bin
  );
    option.per_instance = 1;
    tkeep_cp: coverpoint tkeep_class {
      bins zero   = {0};
      bins all    = {1};
      bins sparse = {2};
    }
    tstrb_cp: coverpoint tstrb_class {
      bins zero          = {0};
      bins all_qualified = {1};
      bins subset        = {2};
    }
    tvalid_delay_cp: coverpoint tvalid_delay_bin {
      bins zero  = {0};
      bins short = {1};
      bins long  = {2};
    }
    tready_stall_cp: coverpoint tready_stall_bin {
      bins zero  = {0};
      bins short = {1};
      bins long  = {2};
    }
  endgroup

  // Class variables
  protected virtual vip_axi4s_if #(CFG_P) _vif;
  protected int                           _id;

  // Ingress data is saved per open {tid, tdest} stream in _open_packets
  protected bit                         _packet_open;
  protected bit                         _packet_start_open;
  protected logic   [TID_WIDTH_C-1 : 0] _packet_tid;
  protected logic [TDEST_WIDTH_C-1 : 0] _packet_tdest;
  protected vip_axi4s_monitor_packet_state #(CFG_P) _open_packets[string];
  protected int unsigned                _pending_stall_cycles;
  protected int unsigned                _tvalid_delay_cycles;
  protected bit                         _saw_tvalid;
  protected int unsigned                _cycle_count;
  protected int                         _trace_fd;

  `uvm_component_param_utils_begin(vip_axi4s_monitor #(CFG_P))
    `uvm_field_int(_id, UVM_DEFAULT)
  `uvm_component_utils_end

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function new(string name, uvm_component parent);

    super.new(name, parent);

    tdata_port = new("tdata_port", this);
    packet_start_port = new("packet_start_port", this);
    beat_port = new("beat_port", this);
    violation_port = new("violation_port", this);
    stats_port = new("stats_port", this);
    _packet_cg = new();
    _beat_cg = new();
  endfunction

  // ---------------------------------------------------------------------------
  // Register a callback object
  // ---------------------------------------------------------------------------
  function void add_callback(input vip_axi4s_monitor_callback #(CFG_P) cb);

    callbacks.push_back(cb);
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

    if (cfg == null && !uvm_config_db #(vip_axi4s_config)::get(this, "", "cfg", cfg)) begin

      `uvm_info(get_name(), "Monitor has no config, creating a default config", UVM_LOW)
      cfg = vip_axi4s_config::type_id::create({"default_config_", get_name()}, this);
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);

    fork
      this.monitor_active_periods();
      this.check_reset_protocol();
    join
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task monitor_active_periods();

    forever begin

      if (_vif.rst_n === 1'b1) begin

        fork
          this.monitor_start();
        join_none
      end else begin

        wait (_vif.rst_n === 1'b0);
        @(posedge _vif.rst_n);

        fork
          this.monitor_start();
        join_none
      end

      @(negedge _vif.rst_n);
      disable fork;
      this.handle_reset();
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task check_reset_protocol();

    forever begin

      @(posedge _vif.clk);

      if (_vif.rst_n !== 1'b1) begin
        this.check_assert(
          VIP_AXI4S_CHECK_TVALID_LOW_WHEN_RESET_IS_ACTIVE_E,
          _vif.tvalid !== 1'b1,
          "TVALID must be low while reset is active"
        );
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task monitor_start();

    fork

      this.collect_transfers();
      this.check_protocol();
      this.detect_packet_start();
    join
  endtask

  // ---------------------------------------------------------------------------
  // Announce the start of a packet to the sequencer, so that an active slave
  // can produce a targeted response for it
  // ---------------------------------------------------------------------------
  protected task detect_packet_start();

    vip_axi4s_item #(CFG_P) packet_start_item;

    forever begin

      // The negative clock edge is used instead of a TVALID rising edge so
      // that back-to-back packets, where TVALID never goes low across the
      // TLAST boundary, are detected too. It is still half a clock cycle
      // before the first beat can handshake, which is what the zero time
      // response contract needs
      @(negedge _vif.clk);

      if ((_vif.rst_n === 1'b1) && (_vif.tvalid === 1'b1) && !_packet_start_open) begin

        packet_start_item       = new("packet_start_item");
        packet_start_item.tid   = _vif.tid;
        packet_start_item.tdest = _vif.tdest;
        _packet_start_open      = 1'b1;
        packet_start_port.write(packet_start_item);
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void handle_reset();

    vip_axi4s_item #(CFG_P) truncated_item;

    foreach (_open_packets[key]) begin
      this.check_assert(
        VIP_AXI4S_CHECK_PACKET_TRUNCATED_BY_RESET_E,
        1'b0,
        $sformatf(
          "Packet truncated by reset after %0d beats (tid=0x%0h tdest=0x%0h)",
          _open_packets[key].tdata.size(),
          _open_packets[key].tid,
          _open_packets[key].tdest
        )
      );
      if (_open_packets[key].tdata.size() != 0 && cfg != null) begin
        truncated_item = this.build_packet_item(_open_packets[key]);
        this.sample_packet_coverage(truncated_item, _open_packets[key].stall_cycles, 1'b1);
        cfg.record_performance_reset_during_packet();
        this.trace_packet(
          truncated_item,
          _open_packets[key].stall_cycles,
          this.packet_latency_cycles(_open_packets[key]),
          1'b1
        );
        cfg.record_coverage_reset_during_packet();
      end
    end

    _open_packets.delete();
    _packet_open = 1'b0;
    _packet_start_open = 1'b0;
    _packet_tid  = '0;
    _packet_tdest = '0;
    _pending_stall_cycles = 0;
    _tvalid_delay_cycles  = 0;
    _saw_tvalid           = 1'b0;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task collect_transfers();

    vip_axi4s_item #(CFG_P) axi4s_item;
    vip_axi4s_item #(CFG_P) beat_item;
    vip_axi4s_monitor_packet_state #(CFG_P) state;
    string                  key;
    int unsigned            tvalid_delay;

    forever begin

      @(posedge _vif.clk);
      _cycle_count++;
      this.record_performance_cycle();
      this.update_stall_tracking();

      if (_vif.tvalid === '1 && _vif.tready === '1) begin
        key = this.stream_key(_vif.tid, _vif.tdest);
        if (!_open_packets.exists(key)) begin
          this.check_single_outstanding_per_tdest(_vif.tdest, key);
          state       = new();
          state.tid   = _vif.tid;
          state.tdest = _vif.tdest;
          state.start_cycle = _cycle_count;
          _open_packets[key] = state;
          this.check_stream_interleave_depth();
        end
        state = _open_packets[key];

        // A TID/TDEST change before TLAST is only a violation when interleaving
        // is not permitted. Once more than one stream may be open at a time,
        // switching between them mid packet is legal and the per stream
        // tracking in _open_packets is what keeps the packets apart
        if (!_packet_open) begin
          _packet_open  = 1'b1;
          _packet_tid   = _vif.tid;
          _packet_tdest = _vif.tdest;
        end else if (!this.interleaving_allowed()) begin
          this.check_assert(
            VIP_AXI4S_CHECK_TID_OR_TDEST_CHANGE_BEFORE_TLAST_E,
            _vif.tid === _packet_tid && _vif.tdest === _packet_tdest,
            $sformatf(
              "TID/TDEST changed before TLAST (first tid=0x%0h tdest=0x%0h, current tid=0x%0h tdest=0x%0h)",
              _packet_tid,
              _packet_tdest,
              _vif.tid,
              _vif.tdest
            )
          );
        end

        state.tdata.push_back(_vif.tdata);
        state.tstrb.push_back(_vif.tstrb);
        state.tkeep.push_back(_vif.tkeep);
        state.tuser.push_back(_vif.tuser);
        state.stall_cycles += _pending_stall_cycles;
        if (_vif.tuser != '0) begin
          state.has_nonzero_tuser = 1'b1;
        end

        tvalid_delay = this.current_tvalid_delay();
        beat_item = this.build_beat_item(
          _vif.tdata,
          _vif.tstrb,
          _vif.tkeep,
          _vif.tuser,
          _vif.tid,
          _vif.tdest
        );
        this.sample_beat_coverage(_vif.tkeep, _vif.tstrb, tvalid_delay, _pending_stall_cycles);
        this.record_performance_beat(_vif.tstrb, _vif.tkeep, _pending_stall_cycles);
        this.trace_beat(
          state.tdata.size() - 1,
          _vif.tdata,
          _vif.tstrb,
          _vif.tkeep,
          _vif.tuser,
          _vif.tid,
          _vif.tdest,
          _vif.tlast,
          _pending_stall_cycles
        );
        beat_port.write(beat_item);
        this.do_beat_sampled(beat_item);

        this.check_assert(
          VIP_AXI4S_CHECK_MAX_STREAM_BURST_LENGTH_EXCEEDED_E,
          state.tdata.size() <= cfg.max_stream_burst_length,
          $sformatf(
            "Packet length %0d exceeds max_stream_burst_length %0d",
            state.tdata.size(),
            cfg.max_stream_burst_length
          )
        );
        _pending_stall_cycles = 0;
      end

      if (_vif.tvalid === '1 && _vif.tready === '1 && _vif.tlast === '1) begin
        key = this.stream_key(_vif.tid, _vif.tdest);
        if (_open_packets.exists(key)) begin
          state = _open_packets[key];
          axi4s_item = this.build_packet_item(state);
          this.sample_packet_coverage(axi4s_item, state.stall_cycles, 1'b0);
          this.record_performance_packet(this.packet_latency_cycles(state));
          this.trace_packet(
            axi4s_item,
            state.stall_cycles,
            this.packet_latency_cycles(state),
            1'b0
          );
          _open_packets.delete(key);

          _packet_open = 1'b0;
          _packet_start_open = 1'b0;
          _packet_tid  = '0;
          _packet_tdest = '0;

          `uvm_info(get_type_name(), $sformatf("Collected transfer:\n%s", axi4s_item.sprint()), UVM_HIGH)
          tdata_port.write(axi4s_item);
          this.do_packet_completed(axi4s_item);
        end
      end
      this.update_tvalid_delay_tracking();
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Interleaving is permitted once more than one stream may be open at a time
  // ---------------------------------------------------------------------------
  protected function bit interleaving_allowed();

    return (cfg != null) && (cfg.stream_interleave_depth > 1);
  endfunction

  // ---------------------------------------------------------------------------
  // Key used to track one open packet per {tid, tdest} stream
  // ---------------------------------------------------------------------------
  protected function string stream_key(
    input logic   [TID_WIDTH_C-1 : 0] tid,
    input logic [TDEST_WIDTH_C-1 : 0] tdest
  );

    return $sformatf("%0h:%0h", tid, tdest);
  endfunction

  // ---------------------------------------------------------------------------
  // Report a second open packet for the same TDEST
  // ---------------------------------------------------------------------------
  protected function void check_single_outstanding_per_tdest(
    input logic [TDEST_WIDTH_C-1 : 0] tdest,
    input string                      new_key
  );

    bit allowed;

    allowed = 1'b1;
    if (cfg == null || !cfg.single_outstanding_per_tdest_enable) begin
      return;
    end

    foreach (_open_packets[key]) begin
      if ((key != new_key) && (_open_packets[key].tdest === tdest)) begin
        allowed = 1'b0;
      end
    end

    this.check_assert(
      VIP_AXI4S_CHECK_SINGLE_OUTSTANDING_PER_TDEST_E,
      allowed,
      $sformatf("Multiple open packets target TDEST 0x%0h", tdest)
    );
  endfunction

  // ---------------------------------------------------------------------------
  // Report more open streams than configured
  // ---------------------------------------------------------------------------
  protected function void check_stream_interleave_depth();

    if (cfg == null) begin
      return;
    end

    this.check_assert(
      VIP_AXI4S_CHECK_STREAM_INTERLEAVE_DEPTH_EXCEEDED_E,
      _open_packets.num() <= cfg.stream_interleave_depth,
      $sformatf(
        "Open stream count %0d exceeds stream_interleave_depth %0d",
        _open_packets.num(),
        cfg.stream_interleave_depth
      )
    );
  endfunction

  // ---------------------------------------------------------------------------
  // One item holding a single observed beat
  // ---------------------------------------------------------------------------
  protected function vip_axi4s_item #(CFG_P) build_beat_item(
    input logic [TDATA_WIDTH_C-1 : 0] tdata,
    input logic [TSTRB_WIDTH_C-1 : 0] tstrb,
    input logic [TKEEP_WIDTH_C-1 : 0] tkeep,
    input logic [TUSER_WIDTH_C-1 : 0] tuser,
    input logic   [TID_WIDTH_C-1 : 0] tid,
    input logic [TDEST_WIDTH_C-1 : 0] tdest
  );

    vip_axi4s_item #(CFG_P) item;

    item       = new("axi4s_beat");
    item.tid   = tid;
    item.tdest = tdest;
    item.tdata = new[1];
    item.tstrb = new[1];
    item.tkeep = new[1];
    item.tuser = new[1];
    item.tdata[0] = tdata;
    item.tstrb[0] = tstrb;
    item.tkeep[0] = tkeep;
    item.tuser[0] = tuser;
    item.burst_length = 1;
    item.infer_stream_xact_type();
    return item;
  endfunction

  // ---------------------------------------------------------------------------
  // One item holding a whole observed packet
  // ---------------------------------------------------------------------------
  protected function vip_axi4s_item #(CFG_P) build_packet_item(
    input vip_axi4s_monitor_packet_state #(CFG_P) state
  );

    vip_axi4s_item #(CFG_P) item;

    item       = new("axi4s_item");
    item.tid   = state.tid;
    item.tdest = state.tdest;
    item.tdata = new[state.tdata.size()];
    item.tstrb = new[state.tstrb.size()];
    item.tkeep = new[state.tkeep.size()];
    item.tuser = new[state.tuser.size()];
    item.burst_length = state.tdata.size();
    foreach (state.tdata[i]) begin item.tdata[i] = state.tdata[i]; end
    foreach (state.tstrb[i]) begin item.tstrb[i] = state.tstrb[i]; end
    foreach (state.tkeep[i]) begin item.tkeep[i] = state.tkeep[i]; end
    foreach (state.tuser[i]) begin item.tuser[i] = state.tuser[i]; end
    item.infer_stream_xact_type();
    return item;
  endfunction

  // ---------------------------------------------------------------------------
  // Cycles from the first beat of a packet until now
  // ---------------------------------------------------------------------------
  protected function int unsigned packet_latency_cycles(
    input vip_axi4s_monitor_packet_state #(CFG_P) state
  );

    if (_cycle_count < state.start_cycle) begin
      return 0;
    end
    return _cycle_count - state.start_cycle + 1;
  endfunction

  // ---------------------------------------------------------------------------
  // Count one observed clock cycle
  // ---------------------------------------------------------------------------
  protected function void record_performance_cycle();

    if (cfg != null) begin
      cfg.record_performance_cycle(_vif.tvalid === 1'b1, _vif.tready === 1'b1);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Count one observed beat and its stall cycles
  // ---------------------------------------------------------------------------
  protected function void record_performance_beat(
    input logic [TSTRB_WIDTH_C-1 : 0] tstrb,
    input logic [TKEEP_WIDTH_C-1 : 0] tkeep,
    input int unsigned                stall_cycles
  );

    if (cfg != null) begin
      cfg.record_performance_beat($countones(tstrb & tkeep), stall_cycles);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Count one observed packet and its latency
  // ---------------------------------------------------------------------------
  protected function void record_performance_packet(input int unsigned packet_latency);

    if (cfg != null) begin
      cfg.record_performance_packet(packet_latency);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Count the cycles TVALID waits for TREADY
  // ---------------------------------------------------------------------------
  protected function void update_stall_tracking();

    if ((_vif.tvalid === 1'b1) && (_vif.tready !== 1'b1)) begin
      _pending_stall_cycles++;
    end else if (_vif.tvalid !== 1'b1) begin
      _pending_stall_cycles = 0;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Cycles TVALID was low before the current beat
  // ---------------------------------------------------------------------------
  protected function int unsigned current_tvalid_delay();

    if (!_saw_tvalid) begin
      return 0;
    end
    return _tvalid_delay_cycles;
  endfunction

  // ---------------------------------------------------------------------------
  // Track how long TVALID stays low between beats
  // ---------------------------------------------------------------------------
  protected function void update_tvalid_delay_tracking();

    if (_vif.tvalid === 1'b1) begin
      _saw_tvalid = 1'b1;
      _tvalid_delay_cycles = 0;
    end else if (_saw_tvalid) begin
      _tvalid_delay_cycles++;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Bin a delay as none, short or long
  // ---------------------------------------------------------------------------
  protected function int unsigned delay_bin(input int unsigned delay);

    if (delay == 0) begin
      return 0;
    end else if (delay <= 3) begin
      return 1;
    end
    return 2;
  endfunction

  // ---------------------------------------------------------------------------
  // Classify TKEEP as none, all or sparse
  // ---------------------------------------------------------------------------
  protected function int unsigned tkeep_class(input logic [TKEEP_WIDTH_C-1 : 0] tkeep);

    if (tkeep == '0) begin
      return 0;
    end else if (tkeep == '1) begin
      return 1;
    end
    return 2;
  endfunction

  // ---------------------------------------------------------------------------
  // Classify TSTRB as none, all qualified or a subset
  // ---------------------------------------------------------------------------
  protected function int unsigned tstrb_class(
    input logic [TSTRB_WIDTH_C-1 : 0] tstrb,
    input logic [TKEEP_WIDTH_C-1 : 0] tkeep
  );

    if (tstrb == '0) begin
      return 0;
    end else if (tstrb == tkeep) begin
      return 1;
    end
    return 2;
  endfunction

  // ---------------------------------------------------------------------------
  // All ones for the TKEEP width
  // ---------------------------------------------------------------------------
  protected function int unsigned keep_mask_int();

    logic [TKEEP_WIDTH_C-1 : 0] keep_mask;

    keep_mask = '1;
    return keep_mask;
  endfunction

  // ---------------------------------------------------------------------------
  // Feed one beat into the counters and the covergroup
  // ---------------------------------------------------------------------------
  protected function void sample_beat_coverage(
    input logic [TKEEP_WIDTH_C-1 : 0] tkeep,
    input logic [TSTRB_WIDTH_C-1 : 0] tstrb,
    input int unsigned                tvalid_delay,
    input int unsigned                stall_cycles
  );

    if (cfg != null) begin
      cfg.record_coverage_beat(tkeep, tstrb, this.keep_mask_int(), tvalid_delay, stall_cycles);
      if (cfg.coverage_enable) begin
        _beat_cg.sample(
          this.tkeep_class(tkeep),
          this.tstrb_class(tstrb, tkeep),
          this.delay_bin(tvalid_delay),
          this.delay_bin(stall_cycles)
        );
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Feed one packet into the counters and the covergroup
  // ---------------------------------------------------------------------------
  protected function void sample_packet_coverage(
    input vip_axi4s_item #(CFG_P) item,
    input int unsigned            stall_cycles,
    input bit                     reset_seen
  );

    if (cfg != null) begin
      cfg.record_coverage_packet(
        item.burst_length,
        item.stream_xact_type,
        item.tid,
        item.tdest,
        this.item_has_nonzero_tuser(item),
        stall_cycles
      );
      if (cfg.coverage_enable) begin
        _packet_cg.sample(
          item.burst_length,
          int'(item.stream_xact_type),
          item.tid != 0,
          item.tdest != 0,
          this.delay_bin(stall_cycles),
          reset_seen
        );
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // True when any beat of the item carries TUSER
  // ---------------------------------------------------------------------------
  protected function bit item_has_nonzero_tuser(input vip_axi4s_item #(CFG_P) item);

    foreach (item.tuser[i]) begin
      if (item.tuser[i] != '0) begin
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction

  // ---------------------------------------------------------------------------
  // True when text trace export is turned on
  // ---------------------------------------------------------------------------
  protected function bit trace_enabled();

    return (cfg != null) && cfg.trace_enable;
  endfunction

  // ---------------------------------------------------------------------------
  // Quote a CSV field when it contains a separator, a quote or a line break
  // ---------------------------------------------------------------------------
  protected function string csv_field_s(input string text);

    string result;
    bit    needs_quotes;

    needs_quotes = 1'b0;

    for (int i = 0; i < text.len(); i++) begin
      if ((text[i] == ",") || (text[i] == "\"") || (text[i] == "\n") || (text[i] == "\r")) begin
        needs_quotes = 1'b1;
      end
    end

    if (!needs_quotes) begin

      return text;
    end

    result = "\"";

    for (int i = 0; i < text.len(); i++) begin
      if (text[i] == "\"") begin
        result = {result, "\"\""};
      end else begin
        result = {result, string'(text[i])};
      end
    end

    return {result, "\""};
  endfunction

  // ---------------------------------------------------------------------------
  // Escape a string so that it is valid inside a JSON string literal
  // ---------------------------------------------------------------------------
  protected function string json_string_s(input string text);

    string result;

    result = "";

    for (int i = 0; i < text.len(); i++) begin
      case (text[i])
        "\"":    result = {result, "\\\""};
        "\\":    result = {result, "\\\\"};
        "\n":    result = {result, "\\n"};
        "\r":    result = {result, "\\r"};
        "\t":    result = {result, "\\t"};
        default: begin
          if (text[i] < 8'h20) begin
            result = {result, $sformatf("\\u%04h", text[i])};
          end else begin
            result = {result, string'(text[i])};
          end
        end
      endcase
    end

    return result;
  endfunction

  // ---------------------------------------------------------------------------
  // True when the trace format is CSV rather than JSONL
  // ---------------------------------------------------------------------------
  protected function bit trace_is_csv();

    return this.trace_enabled() && (cfg.trace_format == "csv");
  endfunction

  // ---------------------------------------------------------------------------
  // Open the trace file and write the CSV header once
  // ---------------------------------------------------------------------------
  protected function void open_trace_if_needed();

    string path;
    string ext;

    if (!this.trace_enabled() || (_trace_fd != 0)) begin
      return;
    end

    ext = this.trace_is_csv() ? "csv" : "jsonl";
    path = cfg.trace_path;
    if (path == "") begin
      path = $sformatf("%s_axi4s_trace.%s", get_full_name(), ext);
    end

    _trace_fd = $fopen(path, "w");
    if (_trace_fd == 0) begin
      `uvm_warning(get_name(), $sformatf("Failed to open AXI4S trace file '%s'", path))
      return;
    end

    if (this.trace_is_csv()) begin
      $fwrite(
        _trace_fd,
        "event,cycle,time,tid,tdest,beat,length,tdata,tstrb,tkeep,tuser,tlast,stream,stall_cycles,latency_cycles,check,message\n"
      );
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Flush the trace file when flushing is enabled
  // ---------------------------------------------------------------------------
  protected function void trace_flush();

    if (this.trace_enabled() && cfg.trace_flush_enable && (_trace_fd != 0)) begin
      $fflush(_trace_fd);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Write one beat record to the trace file
  // ---------------------------------------------------------------------------
  protected function void trace_beat(
    input int unsigned                beat,
    input logic [TDATA_WIDTH_C-1 : 0] tdata,
    input logic [TSTRB_WIDTH_C-1 : 0] tstrb,
    input logic [TKEEP_WIDTH_C-1 : 0] tkeep,
    input logic [TUSER_WIDTH_C-1 : 0] tuser,
    input logic   [TID_WIDTH_C-1 : 0] tid,
    input logic [TDEST_WIDTH_C-1 : 0] tdest,
    input logic                       tlast,
    input int unsigned                stall_cycles
  );

    if (!this.trace_enabled()) begin
      return;
    end
    this.open_trace_if_needed();
    if (_trace_fd == 0) begin
      return;
    end

    if (this.trace_is_csv()) begin
      $fwrite(
        _trace_fd,
        "beat,%0d,%0t,0x%0h,0x%0h,%0d,,0x%0h,0x%0h,0x%0h,0x%0h,%0d,,%0d,,,\n",
        _cycle_count,
        $time,
        tid,
        tdest,
        beat,
        tdata,
        tstrb,
        tkeep,
        tuser,
        tlast,
        stall_cycles
      );
    end else begin
      $fwrite(
        _trace_fd,
        "{\"event\":\"beat\",\"cycle\":%0d,\"time\":%0t,\"tid\":\"0x%0h\",\"tdest\":\"0x%0h\",\"beat\":%0d,\"tdata\":\"0x%0h\",\"tstrb\":\"0x%0h\",\"tkeep\":\"0x%0h\",\"tuser\":\"0x%0h\",\"tlast\":%0d,\"stall_cycles\":%0d}\n",
        _cycle_count,
        $time,
        tid,
        tdest,
        beat,
        tdata,
        tstrb,
        tkeep,
        tuser,
        tlast,
        stall_cycles
      );
    end
    this.trace_flush();
  endfunction

  // ---------------------------------------------------------------------------
  // Write one packet record to the trace file
  // ---------------------------------------------------------------------------
  protected function void trace_packet(
    input vip_axi4s_item #(CFG_P) item,
    input int unsigned            stall_cycles,
    input int unsigned            latency_cycles,
    input bit                     reset_seen
  );

    string event_name;

    if (!this.trace_enabled()) begin
      return;
    end
    this.open_trace_if_needed();
    if (_trace_fd == 0) begin
      return;
    end

    event_name = reset_seen ? "packet_reset" : "packet";
    if (this.trace_is_csv()) begin
      $fwrite(
        _trace_fd,
        "%s,%0d,%0t,0x%0h,0x%0h,,%0d,,,,,,%s,%0d,%0d,,\n",
        this.csv_field_s(event_name),
        _cycle_count,
        $time,
        item.tid,
        item.tdest,
        item.burst_length,
        this.csv_field_s(item.stream_xact_type.name()),
        stall_cycles,
        latency_cycles
      );
    end else begin
      $fwrite(
        _trace_fd,
        "{\"event\":\"%s\",\"cycle\":%0d,\"time\":%0t,\"tid\":\"0x%0h\",\"tdest\":\"0x%0h\",\"length\":%0d,\"stream\":\"%s\",\"stall_cycles\":%0d,\"latency_cycles\":%0d}\n",
        this.json_string_s(event_name),
        _cycle_count,
        $time,
        item.tid,
        item.tdest,
        item.burst_length,
        this.json_string_s(item.stream_xact_type.name()),
        stall_cycles,
        latency_cycles
      );
    end
    this.trace_flush();
  endfunction

  // ---------------------------------------------------------------------------
  // Write one violation record to the trace file
  // ---------------------------------------------------------------------------
  protected function void trace_violation(
    input vip_axi4s_check_t check,
    input string            message
  );

    if (!this.trace_enabled()) begin
      return;
    end
    this.open_trace_if_needed();
    if (_trace_fd == 0) begin
      return;
    end

    if (this.trace_is_csv()) begin
      $fwrite(
        _trace_fd,
        "violation,%0d,%0t,,,,,,,,,,,,,%s,%s\n",
        _cycle_count,
        $time,
        this.csv_field_s(vip_axi4s_check_name(check)),
        this.csv_field_s(message)
      );
    end else begin
      $fwrite(
        _trace_fd,
        "{\"event\":\"violation\",\"cycle\":%0d,\"time\":%0t,\"check\":\"%s\",\"message\":\"%s\"}\n",
        _cycle_count,
        $time,
        this.json_string_s(vip_axi4s_check_name(check)),
        this.json_string_s(message)
      );
    end
    this.trace_flush();
  endfunction

  // ---------------------------------------------------------------------------
  // Close the trace file if it is open
  // ---------------------------------------------------------------------------
  protected function void close_trace();

    if (_trace_fd != 0) begin
      $fclose(_trace_fd);
      _trace_fd = 0;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Callback hook, one beat was sampled
  // ---------------------------------------------------------------------------
  protected function void do_beat_sampled(input vip_axi4s_item #(CFG_P) beat);

    foreach (callbacks[i]) begin
      callbacks[i].beat_sampled(this, beat);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Callback hook, one packet was completed
  // ---------------------------------------------------------------------------
  protected function void do_packet_completed(input vip_axi4s_item #(CFG_P) packet);

    foreach (callbacks[i]) begin
      callbacks[i].packet_completed(this, packet);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Callback hook, one check failed
  // ---------------------------------------------------------------------------
  protected function void do_checker_violation(
    input vip_axi4s_check_t check,
    input string            message
  );

    foreach (callbacks[i]) begin
      callbacks[i].checker_violation(this, check, message);
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task check_protocol();

    bit                         prev_stalled;
    logic [TDATA_WIDTH_C-1 : 0] prev_tdata;
    logic [TSTRB_WIDTH_C-1 : 0] prev_tstrb;
    logic [TKEEP_WIDTH_C-1 : 0] prev_tkeep;
    logic                       prev_tlast;
    logic   [TID_WIDTH_C-1 : 0] prev_tid;
    logic [TDEST_WIDTH_C-1 : 0] prev_tdest;
    logic [TUSER_WIDTH_C-1 : 0] prev_tuser;

    prev_stalled = 0;

    forever begin

      @(posedge _vif.clk);

      this.check_assert(
        VIP_AXI4S_CHECK_SIGNAL_VALID_TVALID_E,
        !$isunknown(_vif.tvalid),
        "TVALID contains X/Z"
      );

      if (prev_stalled) begin

        this.check_assert(
          VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E,
          _vif.tvalid === 1'b1,
          "TVALID deasserted before a handshake completed"
        );

        if (_vif.tvalid === 1'b1) begin

          this.check_assert(
            VIP_AXI4S_CHECK_SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH_E,
            _vif.tdata === prev_tdata,
            "TDATA changed while TVALID was asserted and TREADY was low"
          );

          this.check_assert(
            VIP_AXI4S_CHECK_SIGNAL_STABLE_TSTRB_WHEN_TVALID_HIGH_E,
            _vif.tstrb === prev_tstrb,
            "TSTRB changed while TVALID was asserted and TREADY was low"
          );

          this.check_assert(
            VIP_AXI4S_CHECK_SIGNAL_STABLE_TKEEP_WHEN_TVALID_HIGH_E,
            _vif.tkeep === prev_tkeep,
            "TKEEP changed while TVALID was asserted and TREADY was low"
          );

          this.check_assert(
            VIP_AXI4S_CHECK_SIGNAL_STABLE_TLAST_WHEN_TVALID_HIGH_E,
            _vif.tlast === prev_tlast,
            "TLAST changed while TVALID was asserted and TREADY was low"
          );

          this.check_assert(
            VIP_AXI4S_CHECK_SIGNAL_STABLE_TID_WHEN_TVALID_HIGH_E,
            _vif.tid === prev_tid,
            "TID changed while TVALID was asserted and TREADY was low"
          );

          this.check_assert(
            VIP_AXI4S_CHECK_SIGNAL_STABLE_TDEST_WHEN_TVALID_HIGH_E,
            _vif.tdest === prev_tdest,
            "TDEST changed while TVALID was asserted and TREADY was low"
          );

          this.check_assert(
            VIP_AXI4S_CHECK_SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH_E,
            _vif.tuser === prev_tuser,
            "TUSER changed while TVALID was asserted and TREADY was low"
          );
        end
      end

      if (_vif.tvalid === 1'b1) begin

        this.check_assert(
          VIP_AXI4S_CHECK_SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH_E,
          !$isunknown(_vif.tready),
          "TREADY contains X/Z while TVALID is high"
        );

        this.check_assert(
          VIP_AXI4S_CHECK_SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH_E,
          !$isunknown(_vif.tdata),
          "TDATA contains X/Z while TVALID is high"
        );

        this.check_assert(
          VIP_AXI4S_CHECK_SIGNAL_VALID_TSTRB_WHEN_TVALID_HIGH_E,
          !$isunknown(_vif.tstrb),
          "TSTRB contains X/Z while TVALID is high"
        );

        this.check_assert(
          VIP_AXI4S_CHECK_SIGNAL_VALID_TKEEP_WHEN_TVALID_HIGH_E,
          !$isunknown(_vif.tkeep),
          "TKEEP contains X/Z while TVALID is high"
        );

        this.check_assert(
          VIP_AXI4S_CHECK_SIGNAL_VALID_TLAST_WHEN_TVALID_HIGH_E,
          !$isunknown(_vif.tlast),
          "TLAST contains X/Z while TVALID is high"
        );

        this.check_assert(
          VIP_AXI4S_CHECK_SIGNAL_VALID_TID_WHEN_TVALID_HIGH_E,
          !$isunknown(_vif.tid),
          "TID contains X/Z while TVALID is high"
        );

        this.check_assert(
          VIP_AXI4S_CHECK_SIGNAL_VALID_TDEST_WHEN_TVALID_HIGH_E,
          !$isunknown(_vif.tdest),
          "TDEST contains X/Z while TVALID is high"
        );

        this.check_assert(
          VIP_AXI4S_CHECK_SIGNAL_VALID_TUSER_WHEN_TVALID_HIGH_E,
          !$isunknown(_vif.tuser),
          "TUSER contains X/Z while TVALID is high"
        );

        if (!$isunknown(_vif.tstrb) && !$isunknown(_vif.tkeep)) begin
          this.check_assert(
            VIP_AXI4S_CHECK_TSTRB_LOW_WHEN_TKEEP_LOW_E,
            (_vif.tstrb & ~_vif.tkeep) == '0,
            $sformatf(
              "TSTRB has byte lanes set outside TKEEP (tstrb=0x%0h tkeep=0x%0h)",
              _vif.tstrb,
              _vif.tkeep
            )
          );
        end

        if (CFG_P.VIP_AXI4S_TID_WIDTH_P == 0) begin
          this.check_assert(
            VIP_AXI4S_CHECK_ZERO_WIDTH_TID_IS_ZERO_E,
            _vif.tid === '0,
            "TID must be zero when VIP_AXI4S_TID_WIDTH_P is 0"
          );
        end

        if (CFG_P.VIP_AXI4S_TDEST_WIDTH_P == 0) begin
          this.check_assert(
            VIP_AXI4S_CHECK_ZERO_WIDTH_TDEST_IS_ZERO_E,
            _vif.tdest === '0,
            "TDEST must be zero when VIP_AXI4S_TDEST_WIDTH_P is 0"
          );
        end

        if (CFG_P.VIP_AXI4S_TUSER_WIDTH_P == 0) begin
          this.check_assert(
            VIP_AXI4S_CHECK_ZERO_WIDTH_TUSER_IS_ZERO_E,
            _vif.tuser === '0,
            "TUSER must be zero when VIP_AXI4S_TUSER_WIDTH_P is 0"
          );
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

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected function void check_assert(
    input vip_axi4s_check_t check,
    input bit               condition,
    input string            message
  );

    if (cfg == null) begin
      return;
    end

    if (!cfg.is_check_enabled(check)) begin
      return;
    end

    if (this.is_local_driven_check(check)) begin
      cfg.record_suppressed_check(check);
      return;
    end

    cfg.record_check(check);
    if (!condition) begin
      this.report_violation(check, message);
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected function bit is_local_driven_check(input vip_axi4s_check_t check);

    if (cfg == null || cfg.is_active != UVM_ACTIVE) begin
      return 1'b0;
    end

    if (cfg.vip_axi4s_agent_type == VIP_AXI4S_MASTER_AGENT_E) begin
      case (check)
        VIP_AXI4S_CHECK_SIGNAL_VALID_TVALID_E,
        VIP_AXI4S_CHECK_SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_VALID_TSTRB_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_VALID_TKEEP_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_VALID_TLAST_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_VALID_TID_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_VALID_TDEST_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_VALID_TUSER_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_STABLE_TSTRB_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_STABLE_TKEEP_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_STABLE_TLAST_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_STABLE_TID_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_STABLE_TDEST_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH_E,
        VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E,
        VIP_AXI4S_CHECK_TVALID_LOW_WHEN_RESET_IS_ACTIVE_E,
        VIP_AXI4S_CHECK_TSTRB_LOW_WHEN_TKEEP_LOW_E,
        VIP_AXI4S_CHECK_ZERO_WIDTH_TID_IS_ZERO_E,
        VIP_AXI4S_CHECK_ZERO_WIDTH_TDEST_IS_ZERO_E,
        VIP_AXI4S_CHECK_ZERO_WIDTH_TUSER_IS_ZERO_E:
          return 1'b1;

        // The stream tracking checks are deliberately not listed above. They
        // test the legality of the stimulus rather than the integrity of a
        // signal the agent drives, so they stay useful as self checks and are
        // the only protocol checking a master-only environment ever gets
        default:
          return 1'b0;
      endcase
    end

    if (cfg.vip_axi4s_agent_type == VIP_AXI4S_SLAVE_AGENT_E) begin
      return check == VIP_AXI4S_CHECK_SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH_E;
    end

    return 1'b0;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected function void report_violation(
    input vip_axi4s_check_t check,
    input string            message
  );

    string full_message;

    cfg.record_violation(check);
    full_message = $sformatf("[%s] %s", vip_axi4s_check_name(check), message);
    this.trace_violation(check, full_message);
    violation_port.write(full_message);
    this.do_checker_violation(check, full_message);

    case (cfg.get_check_severity(check))
      UVM_FATAL:   `uvm_fatal(get_name(), full_message)
      UVM_WARNING: `uvm_warning(get_name(), full_message)
      UVM_INFO:    `uvm_info(get_name(), full_message, UVM_LOW)
      default:     `uvm_error(get_name(), full_message)
    endcase
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void report_phase(uvm_phase phase);

    super.report_phase(phase);

    if (cfg != null && cfg.has_checker_activity()) begin
      `uvm_info(get_name(), cfg.checker_stats_s(), UVM_LOW)
      stats_port.write(cfg.checker_stats_s());
    end

    if (cfg != null && cfg.has_coverage_activity()) begin
      `uvm_info(get_name(), cfg.coverage_summary_s(), UVM_LOW)
      stats_port.write(cfg.coverage_summary_s());
    end

    if (cfg != null && cfg.has_performance_activity()) begin
      `uvm_info(get_name(), cfg.performance_summary_s(), UVM_LOW)
      stats_port.write(cfg.performance_summary_s());
    end

    this.close_trace();
  endfunction
endclass
