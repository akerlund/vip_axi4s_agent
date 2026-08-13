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

class vip_axi4s_driver #(
  vip_axi4s_cfg_t CFG_P = '{default: '0}
  ) extends uvm_driver #(vip_axi4s_item #(CFG_P));

  protected virtual vip_axi4s_if #(CFG_P) _vif;
  protected int                           _id;
  vip_axi4s_config                        cfg;
  vip_axi4s_sequencer #(CFG_P)            sequencer;
  vip_axi4s_driver_callback #(CFG_P)      callbacks [$];
  protected bit                           _master_item_active;
  protected bit                           _slave_response_active;
  protected bit                           _idle_tlast_value;
  protected bit                           _idle_tready_value;


  `uvm_component_param_utils_begin(vip_axi4s_driver #(CFG_P))
    `uvm_field_int(_id, UVM_DEFAULT)
  `uvm_component_utils_end

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function new(string name, uvm_component parent);

    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // Register a callback object
  // ---------------------------------------------------------------------------
  function void add_callback(input vip_axi4s_driver_callback #(CFG_P) cb);

    callbacks.push_back(cb);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    // Fatal check: VIF
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
          this.driver_start();
        end
      join_none

      @(negedge _vif.rst_n);
      disable fork;
      this.finish_aborted_item();
      this.reset_vif();
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  task driver_start();

    if (cfg.vip_axi4s_agent_type == VIP_AXI4S_MASTER_AGENT_E) begin

      fork

        this.master_drive();
      join
    end
    else begin

      fork

        this.slave_drive();
      join
    end
  endtask

  // ---------------------------------------------------------------------------
  // Reset VIF
  // ---------------------------------------------------------------------------
  protected task reset_vif();

    this.do_pre_reset();

    if (cfg.vip_axi4s_agent_type == VIP_AXI4S_MASTER_AGENT_E) begin

      _vif.tvalid <= '0;
      _vif.tdata  <= '0;
      _vif.tstrb  <= '0;
      _vif.tkeep  <= '0;
      _vif.tlast  <= '0;
      _vif.tid    <= '0;
      _vif.tdest  <= '0;
      _vif.tuser  <= '0;
    end
    else begin

      _vif.tready <= '0;
    end
    this.do_post_reset();
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task master_drive();

    forever begin

      seq_item_port.get_next_item(req);
      _master_item_active = 1'b1;
      this.drive_axi4s_item();
      _master_item_active = 1'b0;
      seq_item_port.item_done();
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task drive_axi4s_item();

    int unsigned beat_counter = 0;
    int unsigned burst_length = req.tdata.size();
    int unsigned cycle_count = 0;
    int unsigned prev_tvalid_cycle = 0;
    int unsigned prev_handshake_cycle = 0;
    int unsigned tvalid_delay [$];

    if (cfg.drive_idle_values_enable || cfg.tlast_idle_toggle_enable) begin
      this.drive_master_idle();
    end else begin
      _vif.tvalid <= '0;
      _vif.tlast  <= '0;
    end

    // TID/TDEST belong to the packet and must override any idle values
    _vif.tid   <= req.tid;
    _vif.tdest <= req.tdest;

    this.build_tvalid_delays(tvalid_delay, burst_length);
    this.do_pre_packet(req);

    if (this.can_use_tdata_only_fast_path(tvalid_delay)) begin
      this.drive_tdata_only_fast_path(cycle_count);
    end else begin
      while (beat_counter != burst_length) begin

        this.wait_tvalid_delay(
          tvalid_delay[beat_counter],
          beat_counter,
          cycle_count,
          prev_tvalid_cycle,
          prev_handshake_cycle
        );

        // TID/TDEST are re-driven per beat because an inter-beat delay parks
        // the bus on the idle values
        _vif.tdata <= req.tdata[beat_counter];
        _vif.tstrb <= req.tstrb[beat_counter];
        _vif.tkeep <= req.tkeep[beat_counter];
        _vif.tuser <= req.tuser[beat_counter];
        _vif.tid   <= req.tid;
        _vif.tdest <= req.tdest;
        _vif.tlast <= (beat_counter == (burst_length - 1));
        this.do_pre_beat(req, beat_counter);
        _vif.tvalid <= '1;
        prev_tvalid_cycle = cycle_count;

        // Wait for the handshake
        @(posedge _vif.clk);
        cycle_count++;
        while (!((_vif.tvalid === '1) && (_vif.tready === '1))) begin

          @(posedge _vif.clk);
          cycle_count++;
        end

        prev_handshake_cycle = cycle_count;
        this.do_post_beat(req, beat_counter);
        beat_counter++;
      end
    end

    this.drive_master_idle();
    this.do_post_packet(req);
  endtask

  // ---------------------------------------------------------------------------
  // Zero delay path that only varies TDATA and TLAST
  // ---------------------------------------------------------------------------
  protected task drive_tdata_only_fast_path(ref int unsigned cycle_count);

    int unsigned beat_counter;
    int unsigned burst_length;

    beat_counter = 0;
    burst_length = req.tdata.size();

    _vif.tstrb <= '1;
    _vif.tkeep <= '1;
    _vif.tuser <= '0;
    _vif.tid   <= req.tid;
    _vif.tdest <= req.tdest;

    while (beat_counter != burst_length) begin
      _vif.tdata <= req.tdata[beat_counter];
      _vif.tlast <= (beat_counter == (burst_length - 1));
      this.do_pre_beat(req, beat_counter);
      _vif.tvalid <= '1;

      @(posedge _vif.clk);
      cycle_count++;
      while (!((_vif.tvalid === '1) && (_vif.tready === '1))) begin
        @(posedge _vif.clk);
        cycle_count++;
      end

      this.do_post_beat(req, beat_counter);
      beat_counter++;
    end
  endtask

  // ---------------------------------------------------------------------------
  // True when the packet qualifies for the fast path
  // ---------------------------------------------------------------------------
  protected function bit can_use_tdata_only_fast_path(input int unsigned tvalid_delay [$]);

    if (!cfg.tdata_only_fast_path_enable) begin
      return 1'b0;
    end

    foreach (tvalid_delay[i]) begin
      if (tvalid_delay[i] != 0) begin
        return 1'b0;
      end
    end

    foreach (req.tkeep[i]) begin
      if (req.tkeep[i] !== '1) begin
        return 1'b0;
      end
    end

    foreach (req.tstrb[i]) begin
      if (req.tstrb[i] !== '1) begin
        return 1'b0;
      end
    end

    foreach (req.tuser[i]) begin
      if (req.tuser[i] !== '0) begin
        return 1'b0;
      end
    end

    return 1'b1;
  endfunction

  // ---------------------------------------------------------------------------
  // Callback hook, before the first beat
  // ---------------------------------------------------------------------------
  protected function void do_pre_packet(input vip_axi4s_item #(CFG_P) item);

    foreach (callbacks[i]) begin
      callbacks[i].pre_packet(this, item);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Callback hook, after the last beat
  // ---------------------------------------------------------------------------
  protected function void do_post_packet(input vip_axi4s_item #(CFG_P) item);

    foreach (callbacks[i]) begin
      callbacks[i].post_packet(this, item);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Callback hook, before a beat is driven
  // ---------------------------------------------------------------------------
  protected function void do_pre_beat(
    input vip_axi4s_item #(CFG_P) item,
    input int unsigned            beat_index
  );

    foreach (callbacks[i]) begin
      callbacks[i].pre_beat(this, item, beat_index);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Callback hook, after a beat has been handshaken
  // ---------------------------------------------------------------------------
  protected function void do_post_beat(
    input vip_axi4s_item #(CFG_P) item,
    input int unsigned            beat_index
  );

    foreach (callbacks[i]) begin
      callbacks[i].post_beat(this, item, beat_index);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Callback hook, before the bus is parked at reset
  // ---------------------------------------------------------------------------
  protected function void do_pre_reset();

    foreach (callbacks[i]) begin
      callbacks[i].pre_reset(this);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Callback hook, after the bus has been parked at reset
  // ---------------------------------------------------------------------------
  protected function void do_post_reset();

    foreach (callbacks[i]) begin
      callbacks[i].post_reset(this);
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected function void build_tvalid_delays(
    ref int unsigned delays [$],
    input int unsigned burst_length
  );

    int unsigned beats_since_delay;
    int unsigned delay_period;

    delays.delete();

    if (req.tvalid_delay.size() != 0) begin
      if (req.tvalid_delay.size() != burst_length) begin
        `uvm_fatal(get_name(), $sformatf(
          "tvalid_delay size %0d does not match burst_length %0d",
          req.tvalid_delay.size(),
          burst_length
        ))
      end
      foreach (req.tvalid_delay[i]) begin
        delays.push_back(req.tvalid_delay[i]);
      end
      return;
    end

    if ((cfg.zero_delays_enable == TRUE) || (cfg.tvalid_delay_enabled == FALSE)) begin
      for (int i = 0; i < burst_length; i++) begin
        delays.push_back(0);
      end
      return;
    end

    beats_since_delay = 0;
    delay_period = cfg.get_delay(
      .delay_enabled ( cfg.tvalid_delay_enabled       ),
      .gauss_enabled ( cfg.tvalid_delay_gauss_enabled ),
      .gauss         ( cfg.g_tvalid_period            ),
      .min           ( cfg.min_tvalid_delay_period    ),
      .max           ( cfg.max_tvalid_delay_period    )
    );

    for (int i = 0; i < burst_length; i++) begin
      if (i == 0) begin
        delays.push_back(0);
      end else if (beats_since_delay >= delay_period) begin
        delays.push_back(cfg.get_delay(
          .delay_enabled ( cfg.tvalid_delay_enabled       ),
          .gauss_enabled ( cfg.tvalid_delay_gauss_enabled ),
          .gauss         ( cfg.g_tvalid_time              ),
          .min           ( cfg.min_tvalid_delay_time      ),
          .max           ( cfg.max_tvalid_delay_time      )
        ));
        beats_since_delay = 0;
        delay_period = cfg.get_delay(
          .delay_enabled ( cfg.tvalid_delay_enabled       ),
          .gauss_enabled ( cfg.tvalid_delay_gauss_enabled ),
          .gauss         ( cfg.g_tvalid_period            ),
          .min           ( cfg.min_tvalid_delay_period    ),
          .max           ( cfg.max_tvalid_delay_period    )
        );
      end else begin
        delays.push_back(0);
      end
      beats_since_delay++;
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task wait_tvalid_delay(
    input int unsigned delay,
    input int unsigned beat_counter,
    ref   int unsigned cycle_count,
    input int unsigned prev_tvalid_cycle,
    input int unsigned prev_handshake_cycle
  );

    int unsigned target_cycle;

    if (beat_counter == 0) begin
      target_cycle = cycle_count + delay;
    end else if (req.reference_event_for_tvalid_delay == VIP_AXI4S_TVALID_DELAY_PREV_TVALID_E) begin
      target_cycle = prev_tvalid_cycle + delay;
    end else begin
      target_cycle = prev_handshake_cycle + delay;
    end

    while (cycle_count < target_cycle) begin
      this.drive_master_idle();
      @(posedge _vif.clk);
      cycle_count++;
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected function void finish_aborted_item();

    if (_master_item_active) begin
      _master_item_active = 1'b0;
      seq_item_port.item_done();
    end
    _slave_response_active = 1'b0;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task slave_drive();

    fork
      this.drive_tready();
      this.drive_tready_responses();
    join
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task drive_tready;

    int clock_counter       = 0;
    int tready_delay_time   = 0;
    int tready_delay_period = cfg.get_delay(
      .delay_enabled ( cfg.tready_delay_enabled       ),
      .gauss_enabled ( cfg.tready_delay_gauss_enabled ),
      .gauss         ( cfg.g_tready_period            ),
      .min           ( cfg.min_tready_delay_period    ),
      .max           ( cfg.max_tready_delay_period    )
    );

    if ((cfg.zero_delays_enable == TRUE) || (cfg.tready_delay_enabled == FALSE)) begin

      forever begin
        if (!_slave_response_active) begin
          this.drive_tready_default();
        end
        @(posedge _vif.clk);
      end
    end

    _vif.tready <= '1;
    forever begin

      @(posedge _vif.clk);

      if (_slave_response_active) begin
        continue;
      end

      if (this.drive_tready_idle_if_enabled()) begin
        continue;
      end

      clock_counter++;
      if (clock_counter >= tready_delay_period) begin

        _vif.tready <= '0;

        clock_counter       = 0;
        tready_delay_time   = cfg.get_delay(
          .delay_enabled ( cfg.tready_delay_enabled       ),
          .gauss_enabled ( cfg.tready_delay_gauss_enabled ),
          .gauss         ( cfg.g_tready_time              ),
          .min           ( cfg.min_tready_delay_time      ),
          .max           ( cfg.max_tready_delay_time      )
        );
        tready_delay_period = cfg.get_delay(
          .delay_enabled ( cfg.tready_delay_enabled       ),
          .gauss_enabled ( cfg.tready_delay_gauss_enabled ),
          .gauss         ( cfg.g_tready_period            ),
          .min           ( cfg.min_tready_delay_period    ),
          .max           ( cfg.max_tready_delay_period    )
        );

        repeat (tready_delay_time) begin

          @(posedge _vif.clk);
          if (_slave_response_active) begin
            break;
          end
          clock_counter++;
        end

        if (!_slave_response_active) begin
          this.drive_tready_default();
        end
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  // Park the master outputs while TVALID is low
  // ---------------------------------------------------------------------------
  protected function void drive_master_idle();

    _vif.tvalid <= '0;

    if (cfg.drive_idle_values_enable) begin
      _vif.tdata  <= cfg.idle_tdata;
      _vif.tstrb  <= cfg.idle_tstrb;
      _vif.tkeep  <= cfg.idle_tkeep;
      _vif.tid    <= cfg.idle_tid;
      _vif.tdest  <= cfg.idle_tdest;
      _vif.tuser  <= cfg.idle_tuser;
      _vif.tlast  <= cfg.idle_tlast;
    end else begin
      _vif.tlast <= '0;
    end

    if (cfg.tlast_idle_toggle_enable) begin
      _idle_tlast_value = !_idle_tlast_value;
      _vif.tlast <= _idle_tlast_value;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Drive the default TREADY unless idle toggling owns it
  // ---------------------------------------------------------------------------
  protected function void drive_tready_default();

    if (!this.drive_tready_idle_if_enabled()) begin
      _vif.tready <= '1;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Toggle TREADY while idle, returns whether it did
  // ---------------------------------------------------------------------------
  protected function bit drive_tready_idle_if_enabled();

    if (!cfg.tready_idle_toggle_enable) begin

      return 1'b0;
    end

    if (_vif.tvalid !== 1'b1) begin

      _idle_tready_value = !_idle_tready_value;
      _vif.tready <= _idle_tready_value;
      return 1'b1;
    end

    // TVALID went high while the toggle happened to leave TREADY low. Without
    // restoring it here the beat would be stalled until the next backpressure
    // period elapses, which is not what an idle toggle is meant to do
    if (!_idle_tready_value) begin

      _idle_tready_value = 1'b1;
      _vif.tready <= 1'b1;
    end

    return 1'b0;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task drive_tready_responses();

    vip_axi4s_item #(CFG_P) rsp;

    forever begin

      // Same anchor as the monitor packet start detection, so that back-to-back
      // packets are picked up as well. The delta cycles let the monitor notify
      // the sequencer and the response sequence produce its item before it is
      // fetched here
      @(negedge _vif.clk);
      #0;

      if ((_vif.rst_n === 1'b1) && (_vif.tvalid === 1'b1)) begin

        #0;
        #0;
        rsp = null;

        if ((sequencer != null) && sequencer.try_get_packet_response(rsp)) begin

          if (!sequencer.is_expected_packet_response(rsp)) begin
            `uvm_fatal(get_name(), "Slave response sequence must return the packet-start request object handle")
          end

          _slave_response_active = 1'b1;
          this.drive_tready_response(rsp, 0);
          sequencer.clear_active_packet_request(rsp);
          _slave_response_active = 1'b0;
        end else if ((sequencer != null) && sequencer.response_expected_for_active_packet()) begin

          `uvm_fatal(get_name(), "Slave response sequence did not return a response item in zero time")
        end
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task drive_tready_response(
    input vip_axi4s_item #(CFG_P) rsp,
    input int unsigned            first_beat_index
  );

    int unsigned beat_index;
    int unsigned delay;
    int unsigned beats_since_delay;
    int unsigned delay_period;

    beat_index = first_beat_index;
    beats_since_delay = 0;
    delay_period = cfg.get_delay(
      .delay_enabled ( cfg.tready_delay_enabled       ),
      .gauss_enabled ( cfg.tready_delay_gauss_enabled ),
      .gauss         ( cfg.g_tready_period            ),
      .min           ( cfg.min_tready_delay_period    ),
      .max           ( cfg.max_tready_delay_period    )
    );

    forever begin

      delay = this.get_tready_response_delay(
        rsp,
        beat_index,
        beats_since_delay,
        delay_period
      );

      _vif.tready <= '0;
      repeat (delay) begin
        @(posedge _vif.clk);
      end
      _vif.tready <= '1;

      @(posedge _vif.clk);
      while (!((_vif.tvalid === '1) && (_vif.tready === '1))) begin
        @(posedge _vif.clk);
      end

      if (_vif.tlast === '1) begin
        break;
      end

      beat_index++;
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected function int unsigned get_tready_response_delay(
    input vip_axi4s_item #(CFG_P) rsp,
    input int unsigned            beat_index,
    ref   int unsigned            beats_since_delay,
    ref   int unsigned            delay_period
  );

    if (rsp.tready_delay.size() != 0) begin
      if (beat_index >= rsp.tready_delay.size()) begin
        `uvm_fatal(get_name(), $sformatf(
          "tready_delay response array ended at beat %0d before TLAST",
          beat_index
        ))
      end
      return rsp.tready_delay[beat_index];
    end

    if ((cfg.zero_delays_enable == TRUE) || (cfg.tready_delay_enabled == FALSE)) begin
      return 0;
    end

    if (beats_since_delay >= delay_period) begin
      beats_since_delay = 0;
      delay_period = cfg.get_delay(
        .delay_enabled ( cfg.tready_delay_enabled       ),
        .gauss_enabled ( cfg.tready_delay_gauss_enabled ),
        .gauss         ( cfg.g_tready_period            ),
        .min           ( cfg.min_tready_delay_period    ),
        .max           ( cfg.max_tready_delay_period    )
      );
      return cfg.get_delay(
        .delay_enabled ( cfg.tready_delay_enabled       ),
        .gauss_enabled ( cfg.tready_delay_gauss_enabled ),
        .gauss         ( cfg.g_tready_time              ),
        .min           ( cfg.min_tready_delay_time      ),
        .max           ( cfg.max_tready_delay_time      )
      );
    end

    beats_since_delay++;
    return 0;
  endfunction
endclass
