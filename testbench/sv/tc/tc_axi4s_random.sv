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
//
// Long randomized run. The agent configuration, the timing controls and the
// payload shapes are all randomized, then packets are streamed for several
// thousand clock periods. Everything the VIP drives is legal traffic, so the
// run must finish without a single protocol violation, and every packet the
// driver sent must be observed by the monitor exactly as it was driven.
//
////////////////////////////////////////////////////////////////////////////////

// -----------------------------------------------------------------------------
// Records every packet the master driver completed
// -----------------------------------------------------------------------------
class axi4s_random_driven_cb extends vip_axi4s_driver_callback #(VIP_AXI4S_CFG_C);

  vip_axi4s_item #(VIP_AXI4S_CFG_C) packets [$];

  `uvm_object_utils(axi4s_random_driven_cb)

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi4s_random_driven_cb");

    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  // Called by the driver once the last beat of a packet has been handshaken
  // ---------------------------------------------------------------------------
  function void post_packet(
    input uvm_component               driver,
    input vip_axi4s_item #(VIP_AXI4S_CFG_C) item
  );

    packets.push_back(item);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Records every packet the master monitor collected and every violation
// -----------------------------------------------------------------------------
class axi4s_random_observed_cb extends vip_axi4s_monitor_callback #(VIP_AXI4S_CFG_C);

  vip_axi4s_item #(VIP_AXI4S_CFG_C) packets [$];
  string                            violations [$];

  `uvm_object_utils(axi4s_random_observed_cb)

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi4s_random_observed_cb");

    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  // Called by the monitor for every completed packet
  // ---------------------------------------------------------------------------
  function void packet_completed(
    input uvm_component               monitor,
    input vip_axi4s_item #(VIP_AXI4S_CFG_C) packet
  );

    packets.push_back(packet);
  endfunction

  // ---------------------------------------------------------------------------
  // Called by the monitor for every reported checker violation
  // ---------------------------------------------------------------------------
  function void checker_violation(
    input uvm_component     monitor,
    input vip_axi4s_check_t check,
    input string            message
  );

    violations.push_back(message);
  endfunction
endclass

class tc_axi4s_random extends axi4s_base_test;

  `uvm_component_utils(tc_axi4s_random)

  localparam int MIN_CYCLES_C = 4000;

  protected axi4s_random_driven_cb   _driven;
  protected axi4s_random_observed_cb _observed;
  protected int unsigned             _seed;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "tc_axi4s_random", uvm_component parent = null);

    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // Randomize the agent configuration
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);

    logic [VIP_AXI4S_TDATA_BYTES_C-1 : 0] idle_keep;

    super.build_phase(phase);

    // Thousands of clock periods is far beyond the UVM default phase timeout
    uvm_top.set_timeout(1ms, 0);

    _seed = $urandom;

    `uvm_info(get_name(), $sformatf(
    "INFO [%s] Random seed value: %0d",
    get_name(), _seed), UVM_LOW)

    // The master sends one packet at a time, so the strictest stream tracking
    // settings must hold for the whole run
    axi4s_mst_cfg0.max_stream_burst_length = 64;
    axi4s_slv_cfg0.max_stream_burst_length = 64;
    axi4s_mst_cfg0.stream_interleave_depth = 1;
    axi4s_slv_cfg0.stream_interleave_depth = 1;
    axi4s_mst_cfg0.single_outstanding_per_tdest_enable = 1'b1;
    axi4s_slv_cfg0.single_outstanding_per_tdest_enable = 1'b1;
    axi4s_mst_cfg0.performance_enable = 1'b1;
    axi4s_slv_cfg0.performance_enable = 1'b1;

    this.randomize_tvalid_delays();
    this.randomize_tready_delays();

    axi4s_mst_cfg0.zero_delays_enable = ($urandom_range(3, 0) == 0) ? TRUE : FALSE;
    axi4s_slv_cfg0.zero_delays_enable = ($urandom_range(3, 0) == 0) ? TRUE : FALSE;

    // Idle bus behaviour: these are what make the driver park the bus on other
    // values between beats, so TID/TDEST must survive them
    axi4s_mst_cfg0.drive_idle_values_enable = $urandom_range(1, 0);
    if (axi4s_mst_cfg0.drive_idle_values_enable) begin

      idle_keep = $urandom;
      axi4s_mst_cfg0.idle_tdata = $urandom;
      axi4s_mst_cfg0.idle_tkeep = idle_keep;
      axi4s_mst_cfg0.idle_tstrb = idle_keep & $urandom;
      axi4s_mst_cfg0.idle_tlast = $urandom_range(1, 0);
      axi4s_mst_cfg0.idle_tid   = $urandom;
      axi4s_mst_cfg0.idle_tdest = $urandom;
      axi4s_mst_cfg0.idle_tuser = $urandom;
    end

    axi4s_mst_cfg0.tlast_idle_toggle_enable    = $urandom_range(1, 0);
    axi4s_mst_cfg0.tdata_only_fast_path_enable = $urandom_range(1, 0);
    axi4s_slv_cfg0.tready_idle_toggle_enable   = $urandom_range(1, 0);

    if ($urandom_range(1, 0)) begin

      axi4s_mst_cfg0.trace_enable = 1'b1;
      axi4s_mst_cfg0.trace_format = ($urandom_range(1, 0)) ? "csv" : "jsonl";
      axi4s_mst_cfg0.trace_path   = {"axi4s_random_mst.", axi4s_mst_cfg0.trace_format};
    end
  endfunction

  // ---------------------------------------------------------------------------
  // TVALID timing, kept inside the ranges the CDF builder accepts
  // ---------------------------------------------------------------------------
  protected function void randomize_tvalid_delays();

    int min_time;
    int max_time;
    int min_period;
    int max_period;

    min_time   = $urandom_range(3, 0);
    max_time   = min_time + $urandom_range(6, 0);
    min_period = $urandom_range(8, 1);
    max_period = min_period + $urandom_range(24, 0);

    axi4s_mst_cfg0.tvalid_delay_enabled       = ($urandom_range(4, 0) != 0) ? TRUE : FALSE;
    axi4s_mst_cfg0.tvalid_delay_gauss_enabled = ($urandom_range(1, 0)) ? TRUE : FALSE;
    axi4s_mst_cfg0.min_tvalid_delay_time      = min_time;
    axi4s_mst_cfg0.max_tvalid_delay_time      = max_time;
    axi4s_mst_cfg0.tvalid_delay_time_mean     = (min_time + max_time) / 2;
    axi4s_mst_cfg0.tvalid_delay_time_stddev   = this.stddev_of(min_time, max_time);
    axi4s_mst_cfg0.min_tvalid_delay_period    = min_period;
    axi4s_mst_cfg0.max_tvalid_delay_period    = max_period;
    axi4s_mst_cfg0.tvalid_delay_period_mean   = (min_period + max_period) / 2;
    axi4s_mst_cfg0.tvalid_delay_period_stddev = this.stddev_of(min_period, max_period);
  endfunction

  // ---------------------------------------------------------------------------
  // TREADY timing, kept inside the ranges the CDF builder accepts
  // ---------------------------------------------------------------------------
  protected function void randomize_tready_delays();

    int min_time;
    int max_time;
    int min_period;
    int max_period;

    min_time   = $urandom_range(3, 0);
    max_time   = min_time + $urandom_range(6, 0);
    min_period = $urandom_range(8, 1);
    max_period = min_period + $urandom_range(24, 0);

    axi4s_slv_cfg0.tready_delay_enabled       = ($urandom_range(4, 0) != 0) ? TRUE : FALSE;
    axi4s_slv_cfg0.tready_delay_gauss_enabled = ($urandom_range(1, 0)) ? TRUE : FALSE;
    axi4s_slv_cfg0.min_tready_delay_time      = min_time;
    axi4s_slv_cfg0.max_tready_delay_time      = max_time;
    axi4s_slv_cfg0.tready_delay_time_mean     = (min_time + max_time) / 2;
    axi4s_slv_cfg0.tready_delay_time_stddev   = this.stddev_of(min_time, max_time);
    axi4s_slv_cfg0.min_tready_delay_period    = min_period;
    axi4s_slv_cfg0.max_tready_delay_period    = max_period;
    axi4s_slv_cfg0.tready_delay_period_mean   = (min_period + max_period) / 2;
    axi4s_slv_cfg0.tready_delay_period_stddev = this.stddev_of(min_period, max_period);
  endfunction

  // ---------------------------------------------------------------------------
  // A non-zero standard deviation for the Gaussian CDF
  // ---------------------------------------------------------------------------
  protected function real stddev_of(input int min_value, input int max_value);

    real spread;

    spread = real'(max_value - min_value) / 2.0;
    return (spread < 1.0) ? 1.0 : spread;
  endfunction

  // ---------------------------------------------------------------------------
  // Hook the recording callbacks into the master agent
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    _driven   = axi4s_random_driven_cb::type_id::create("axi4s_random_driven_cb");
    _observed = axi4s_random_observed_cb::type_id::create("axi4s_random_observed_cb");

    tb_env.mst_agent0.driver.add_callback(_driven);
    tb_env.mst_agent0.monitor.add_callback(_observed);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);

    realtime start_time;
    int      groups;
    int      packets;

    super.run_phase(phase);
    phase.raise_objection(this);

    start_time = $realtime;
    groups     = 0;

    while (this.elapsed_cycles(start_time) < MIN_CYCLES_C) begin

      this.run_random_group(groups);
      groups++;
    end

    packets = _driven.packets.size();
    this.wait_for_compared(packets);

    `uvm_info(get_name(), $sformatf(
    "INFO [%s] seed=%0d groups=%0d packets=%0d cycles=%0d",
    get_name(), _seed, groups, packets, this.elapsed_cycles(start_time)), UVM_LOW)

    if (packets == 0) begin

      `uvm_error(get_name(), "The random run did not send any packet")
    end

    if (tb_env.scoreboard0.number_of_compared != packets) begin

      `uvm_error(get_name(), $sformatf(
      "ERROR [%s] Only %0d of %0d packets were compared",
      get_name(), tb_env.scoreboard0.number_of_compared, packets))
    end

    if (tb_env.scoreboard0.number_of_failed != 0) begin

      `uvm_error(get_name(), $sformatf(
      "ERROR [%s] Scoreboard reported %0d failures",
      get_name(), tb_env.scoreboard0.number_of_failed))
    end

    this.compare_driven_with_observed();
    this.check_no_violations();

    `uvm_info(get_name(), "Done!", UVM_LOW)
    phase.drop_objection(this);
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected function int elapsed_cycles(input realtime start_time);

    return int'(($realtime - start_time) / clk_rst_config0.clock_period);
  endfunction

  // ---------------------------------------------------------------------------
  // One group of packets, with a randomly chosen payload shape
  // ---------------------------------------------------------------------------
  protected task run_random_group(input int index);

    vip_axi4s_seq_t seq;

    seq = vip_axi4s_seq_t::type_id::create($sformatf("vip_axi4s_random_seq%0d", index));
    seq.set_verbose(FALSE);
    seq.set_nr_of_bursts($urandom_range(6, 1));
    seq.set_cfg_burst_length($urandom_range(24, 8), $urandom_range(4, 1));

    case ($urandom_range(3, 0))
      0:       seq.set_tdata_type(VIP_AXI4S_TDATA_COUNTER_E);
      1:       seq.set_tdata_type(VIP_AXI4S_TDATA_RANDOM_E);
      2:       seq.set_tdata_type(VIP_AXI4S_TDATA_ZEROS_E);
      default: seq.set_tdata_type(VIP_AXI4S_TDATA_ONES_E);
    endcase

    case ($urandom_range(3, 0))
      0:       seq.set_tuser_type(VIP_AXI4S_TUSER_COUNTER_E);
      1:       seq.set_tuser_type(VIP_AXI4S_TUSER_RANDOM_E);
      2:       seq.set_tuser_type(VIP_AXI4S_TUSER_ZEROS_E);
      default: seq.set_tuser_type(VIP_AXI4S_TUSER_ONES_E);
    endcase

    case ($urandom_range(2, 0))
      0:       seq.set_tkeep_type(VIP_AXI4S_TKEEP_ALL_E);
      1:       seq.set_tkeep_type(VIP_AXI4S_TKEEP_RANDOM_E);
      default: seq.set_tkeep_type(VIP_AXI4S_TKEEP_SPARSE_E);
    endcase

    seq.set_tstrb_type(($urandom_range(1, 0)) ?
      VIP_AXI4S_TSTRB_ALL_E : VIP_AXI4S_TSTRB_RANDOM_E);
    seq.set_id_type(($urandom_range(1, 0)) ?
      VIP_AXI4S_TID_COUNTER_E : VIP_AXI4S_TID_RANDOM_E);

    case ($urandom_range(2, 0))
      0:       seq.set_tdest_type(VIP_AXI4S_TDEST_INCR_E);
      1:       seq.set_tdest_type(VIP_AXI4S_TDEST_RANDOM_E);
      default: seq.set_tdest_type(VIP_AXI4S_TDEST_CUSTOM_E);
    endcase

    seq.set_reference_event_for_tvalid_delay(($urandom_range(1, 0)) ?
      VIP_AXI4S_TVALID_DELAY_PREV_TVALID_E :
      VIP_AXI4S_TVALID_DELAY_PREV_TVALID_TREADY_HANDSHAKE_E);

    seq.start(v_sqr.mst_sequencer);
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task wait_for_compared(input int expected);

    for (int i = 0; i < 20000; i++) begin
      if (tb_env.scoreboard0.number_of_compared >= expected) begin
        return;
      end
      this.clk_delay(1);
    end
  endtask

  // ---------------------------------------------------------------------------
  // Every packet must reach the monitor exactly as the driver sent it, which is
  // what catches payload or TID/TDEST corruption from the idle values
  // ---------------------------------------------------------------------------
  protected function void compare_driven_with_observed();

    vip_axi4s_item #(VIP_AXI4S_CFG_C) driven_item;
    vip_axi4s_item #(VIP_AXI4S_CFG_C) observed_item;

    if (_driven.packets.size() != _observed.packets.size()) begin

      `uvm_error(get_name(), $sformatf(
      "ERROR [%s] seed=%0d driver sent %0d packets, monitor saw %0d",
      get_name(), _seed, _driven.packets.size(), _observed.packets.size()))
    end

    foreach (_driven.packets[i]) begin

      if (i >= _observed.packets.size()) begin
        break;
      end

      driven_item   = _driven.packets[i];
      observed_item = _observed.packets[i];

      if (driven_item.tid !== observed_item.tid || driven_item.tdest !== observed_item.tdest) begin

        `uvm_error(get_name(), $sformatf(
        "ERROR [%s] seed=%0d packet %0d TID/TDEST mismatch, driven 0x%0h/0x%0h observed 0x%0h/0x%0h",
        get_name(), _seed, i,
        driven_item.tid, driven_item.tdest,
        observed_item.tid, observed_item.tdest))
        return;
      end

      if (driven_item.tdata.size() != observed_item.tdata.size()) begin

        `uvm_error(get_name(), $sformatf(
        "ERROR [%s] seed=%0d packet %0d length mismatch, driven %0d observed %0d",
        get_name(), _seed, i, driven_item.tdata.size(), observed_item.tdata.size()))
        return;
      end

      foreach (driven_item.tdata[beat]) begin
        if (driven_item.tdata[beat] !== observed_item.tdata[beat] ||
            driven_item.tstrb[beat] !== observed_item.tstrb[beat] ||
            driven_item.tkeep[beat] !== observed_item.tkeep[beat] ||
            driven_item.tuser[beat] !== observed_item.tuser[beat]) begin

          `uvm_error(get_name(), $sformatf(
          "ERROR [%s] seed=%0d packet %0d beat %0d mismatch",
          get_name(), _seed, i, beat))
          return;
        end
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // The VIP only drives legal traffic, so nothing may be reported
  // ---------------------------------------------------------------------------
  protected function void check_no_violations();

    vip_axi4s_check_t check;
    int unsigned      total;

    foreach (_observed.violations[i]) begin

      `uvm_error(get_name(), $sformatf(
      "ERROR [%s] seed=%0d Unexpected protocol violation: %s",
      get_name(), _seed, _observed.violations[i]))
    end

    for (int i = 0; i < int'(VIP_AXI4S_CHECK_NUM_E); i++) begin

      void'($cast(check, i));
      total = axi4s_mst_cfg0.get_check_violations(check) +
              axi4s_slv_cfg0.get_check_violations(check);

      if (total != 0) begin

        `uvm_error(get_name(), $sformatf(
        "ERROR [%s] seed=%0d %0d violations of %s",
        get_name(), _seed, total, vip_axi4s_check_name(check)))
      end
    end
  endfunction
endclass
