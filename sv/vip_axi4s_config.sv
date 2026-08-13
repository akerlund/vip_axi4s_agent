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

class vip_axi4s_config extends uvm_object;

  uvm_active_passive_enum is_active            = UVM_ACTIVE;
  vip_axi4s_agent_type_t  vip_axi4s_agent_type = VIP_AXI4S_MASTER_AGENT_E;

  bool_t    tvalid_delay_enabled       = TRUE;
  bool_t    tvalid_delay_gauss_enabled = TRUE;
  int       min_tvalid_delay_time      = 1;
  int       max_tvalid_delay_time      = 10;
  int       tvalid_delay_time_mean     = 4;
  real      tvalid_delay_time_stddev   = 2.0;
  int       min_tvalid_delay_period    = 10;
  int       max_tvalid_delay_period    = 256;
  int       tvalid_delay_period_mean   = 64;
  real      tvalid_delay_period_stddev = 32.0;
  vip_gauss g_tvalid_time;
  vip_gauss g_tvalid_period;

  bool_t    tready_delay_enabled       = TRUE;
  bool_t    tready_delay_gauss_enabled = TRUE;
  int       min_tready_delay_time      = 1;
  int       max_tready_delay_time      = 10;
  int       tready_delay_time_mean     = 4;
  real      tready_delay_time_stddev   = 2.0;
  int       min_tready_delay_period    = 10;
  int       max_tready_delay_period    = 256;
  int       tready_delay_period_mean   = 64;
  real      tready_delay_period_stddev = 32.0;
  vip_gauss g_tready_time;
  vip_gauss g_tready_period;

  bool_t    zero_delays_enable = FALSE;

  bit          protocol_checks_enable  = 1'b1;
  bit          per_clock_checks_enable = 1'b1;
  int unsigned max_stream_burst_length = 256;
  int unsigned stream_interleave_depth = 1;
  bit          single_outstanding_per_tdest_enable = 1'b0;
  bit          coverage_enable = 1'b1;
  bit          trace_enable = 1'b0;
  string       trace_format = "jsonl";
  string       trace_path = "";
  bit          trace_flush_enable = 1'b1;
  bit          performance_enable = 1'b0;
  bit          drive_idle_values_enable = 1'b0;
  uvm_bitstream_t idle_tdata = '0;
  uvm_bitstream_t idle_tstrb = '0;
  uvm_bitstream_t idle_tkeep = '0;
  bit             idle_tlast = 1'b0;
  uvm_bitstream_t idle_tid = '0;
  uvm_bitstream_t idle_tdest = '0;
  uvm_bitstream_t idle_tuser = '0;
  bit          tlast_idle_toggle_enable = 1'b0;
  bit          tready_idle_toggle_enable = 1'b0;
  bit          tdata_only_fast_path_enable = 1'b0;

  protected bit          _check_enable[int];
  protected uvm_severity _check_severity[int];
  protected int unsigned _check_executed[int];
  protected int unsigned _check_suppressed[int];
  protected int unsigned _check_violations[int];
  protected int unsigned _coverage_packets;
  protected int unsigned _coverage_beats;
  protected int unsigned _coverage_reset_during_packet;
  protected int unsigned _coverage_packet_length_one;
  protected int unsigned _coverage_packet_length_small;
  protected int unsigned _coverage_packet_length_medium;
  protected int unsigned _coverage_packet_length_large;
  protected int unsigned _coverage_packet_backpressure_zero;
  protected int unsigned _coverage_packet_backpressure_short;
  protected int unsigned _coverage_packet_backpressure_long;
  protected int unsigned _coverage_stream_type[int];
  protected int unsigned _coverage_tid_zero;
  protected int unsigned _coverage_tid_nonzero;
  protected int unsigned _coverage_tdest_zero;
  protected int unsigned _coverage_tdest_nonzero;
  protected int unsigned _coverage_tuser_zero;
  protected int unsigned _coverage_tuser_nonzero;
  protected int unsigned _coverage_tkeep_zero;
  protected int unsigned _coverage_tkeep_all;
  protected int unsigned _coverage_tkeep_sparse;
  protected int unsigned _coverage_tstrb_zero;
  protected int unsigned _coverage_tstrb_all_qualified;
  protected int unsigned _coverage_tstrb_subset;
  protected int unsigned _coverage_tvalid_delay_zero;
  protected int unsigned _coverage_tvalid_delay_short;
  protected int unsigned _coverage_tvalid_delay_long;
  protected int unsigned _coverage_tready_stall_zero;
  protected int unsigned _coverage_tready_stall_short;
  protected int unsigned _coverage_tready_stall_long;
  protected int unsigned _perf_packets;
  protected int unsigned _perf_beats;
  protected int unsigned _perf_data_bytes;
  protected int unsigned _perf_active_cycles;
  protected int unsigned _perf_valid_cycles;
  protected int unsigned _perf_ready_cycles;
  protected int unsigned _perf_handshake_cycles;
  protected int unsigned _perf_stall_cycles;
  protected int unsigned _perf_reset_interruptions;
  protected int unsigned _perf_beat_latency_samples;
  protected int unsigned _perf_beat_latency_sum;
  protected int unsigned _perf_beat_latency_min;
  protected int unsigned _perf_beat_latency_max;
  protected int unsigned _perf_packet_latency_samples;
  protected int unsigned _perf_packet_latency_sum;
  protected int unsigned _perf_packet_latency_min;
  protected int unsigned _perf_packet_latency_max;

  `uvm_object_utils_begin(vip_axi4s_config);
    `uvm_field_enum(uvm_active_passive_enum, is_active,                  UVM_PRINT)
    `uvm_field_enum(vip_axi4s_agent_type_t,  vip_axi4s_agent_type,       UVM_PRINT)
    `uvm_field_enum(bool_t,                  tvalid_delay_enabled,       UVM_PRINT)
    `uvm_field_enum(bool_t,                  tvalid_delay_gauss_enabled, UVM_PRINT)
    `uvm_field_int(min_tvalid_delay_time,                                UVM_PRINT | UVM_DEC)
    `uvm_field_int(max_tvalid_delay_time,                                UVM_PRINT | UVM_DEC)
    `uvm_field_int(tvalid_delay_time_mean,                               UVM_PRINT | UVM_DEC)
    `uvm_field_real(tvalid_delay_time_stddev,                            UVM_PRINT | UVM_DEC)
    `uvm_field_int(min_tvalid_delay_period,                              UVM_PRINT | UVM_DEC)
    `uvm_field_int(max_tvalid_delay_period,                              UVM_PRINT | UVM_DEC)
    `uvm_field_int(tvalid_delay_period_mean,                             UVM_PRINT | UVM_DEC)
    `uvm_field_real(tvalid_delay_period_stddev,                          UVM_PRINT | UVM_DEC)
    `uvm_field_enum(bool_t,                  tready_delay_enabled,       UVM_PRINT)
    `uvm_field_enum(bool_t,                  tready_delay_gauss_enabled, UVM_PRINT)
    `uvm_field_int(min_tready_delay_time,                                UVM_PRINT | UVM_DEC)
    `uvm_field_int(max_tready_delay_time,                                UVM_PRINT | UVM_DEC)
    `uvm_field_int(tready_delay_time_mean,                               UVM_PRINT | UVM_DEC)
    `uvm_field_real(tready_delay_time_stddev,                            UVM_PRINT | UVM_DEC)
    `uvm_field_int(min_tready_delay_period,                              UVM_PRINT | UVM_DEC)
    `uvm_field_int(max_tready_delay_period,                              UVM_PRINT | UVM_DEC)
    `uvm_field_int(tready_delay_period_mean,                             UVM_PRINT | UVM_DEC)
    `uvm_field_real(tready_delay_period_stddev,                          UVM_PRINT | UVM_DEC)
    `uvm_field_enum(bool_t,                  zero_delays_enable,         UVM_PRINT)
    `uvm_field_int(protocol_checks_enable,                               UVM_PRINT | UVM_BIN)
    `uvm_field_int(per_clock_checks_enable,                              UVM_PRINT | UVM_BIN)
    `uvm_field_int(max_stream_burst_length,                              UVM_PRINT | UVM_DEC)
    `uvm_field_int(stream_interleave_depth,                              UVM_PRINT | UVM_DEC)
    `uvm_field_int(single_outstanding_per_tdest_enable,                  UVM_PRINT | UVM_BIN)
    `uvm_field_int(coverage_enable,                                      UVM_PRINT | UVM_BIN)
    `uvm_field_int(trace_enable,                                         UVM_PRINT | UVM_BIN)
    `uvm_field_string(trace_format,                                      UVM_PRINT)
    `uvm_field_string(trace_path,                                        UVM_PRINT)
    `uvm_field_int(trace_flush_enable,                                   UVM_PRINT | UVM_BIN)
    `uvm_field_int(performance_enable,                                   UVM_PRINT | UVM_BIN)
    `uvm_field_int(drive_idle_values_enable,                             UVM_PRINT | UVM_BIN)
    `uvm_field_int(idle_tdata,                                           UVM_PRINT | UVM_HEX)
    `uvm_field_int(idle_tstrb,                                           UVM_PRINT | UVM_HEX)
    `uvm_field_int(idle_tkeep,                                           UVM_PRINT | UVM_HEX)
    `uvm_field_int(idle_tlast,                                           UVM_PRINT | UVM_BIN)
    `uvm_field_int(idle_tid,                                             UVM_PRINT | UVM_HEX)
    `uvm_field_int(idle_tdest,                                           UVM_PRINT | UVM_HEX)
    `uvm_field_int(idle_tuser,                                           UVM_PRINT | UVM_HEX)
    `uvm_field_int(tlast_idle_toggle_enable,                             UVM_PRINT | UVM_BIN)
    `uvm_field_int(tready_idle_toggle_enable,                            UVM_PRINT | UVM_BIN)
    `uvm_field_int(tdata_only_fast_path_enable,                          UVM_PRINT | UVM_BIN)
  `uvm_object_utils_end

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "vip_axi4s_config");

    super.new(name);
    this.init_checker_defaults();
    this.init_performance();
  endfunction

  // ---------------------------------------------------------------------------
  // Enable every check and clear its counters
  // ---------------------------------------------------------------------------
  function void init_checker_defaults();

    for (int i = 0; i < int'(VIP_AXI4S_CHECK_NUM_E); i++) begin
      _check_enable[i]     = 1'b1;
      _check_severity[i]   = UVM_ERROR;
      _check_executed[i]   = 0;
      _check_suppressed[i] = 0;
      _check_violations[i] = 0;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // True for the checks that run on every clock edge
  // ---------------------------------------------------------------------------
  function bit is_per_clock_check(input vip_axi4s_check_t check);

    case (check)
      VIP_AXI4S_CHECK_SIGNAL_VALID_TVALID_E,
      VIP_AXI4S_CHECK_SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH_E,
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
      VIP_AXI4S_CHECK_SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH_E:
        return 1'b1;
      default:
        return 1'b0;
    endcase
  endfunction

  // ---------------------------------------------------------------------------
  // Global, per clock and per check enables combined
  // ---------------------------------------------------------------------------
  function bit is_check_enabled(input vip_axi4s_check_t check);

    int check_idx;

    if (!protocol_checks_enable) begin
      return 1'b0;
    end

    if (this.is_per_clock_check(check) && !per_clock_checks_enable) begin
      return 1'b0;
    end

    check_idx = int'(check);
    if (!_check_enable.exists(check_idx)) begin
      return 1'b1;
    end

    return _check_enable[check_idx];
  endfunction

  // ---------------------------------------------------------------------------
  // Enable or disable a single check
  // ---------------------------------------------------------------------------
  function void set_check_enable(input vip_axi4s_check_t check, input bit enabled);

    _check_enable[int'(check)] = enabled;
  endfunction

  // ---------------------------------------------------------------------------
  // Report severity used when a single check fails
  // ---------------------------------------------------------------------------
  function void set_check_severity(input vip_axi4s_check_t check, input uvm_severity severity);

    _check_severity[int'(check)] = severity;
  endfunction

  // ---------------------------------------------------------------------------
  // Report severity of a single check, UVM_ERROR by default
  // ---------------------------------------------------------------------------
  function uvm_severity get_check_severity(input vip_axi4s_check_t check);

    int check_idx;

    check_idx = int'(check);
    if (!_check_severity.exists(check_idx)) begin
      return UVM_ERROR;
    end

    return _check_severity[check_idx];
  endfunction

  // ---------------------------------------------------------------------------
  // Count one execution of a check
  // ---------------------------------------------------------------------------
  function void record_check(input vip_axi4s_check_t check);

    _check_executed[int'(check)]++;
  endfunction

  // ---------------------------------------------------------------------------
  // Count one failure of a check
  // ---------------------------------------------------------------------------
  function void record_violation(input vip_axi4s_check_t check);

    _check_violations[int'(check)]++;
  endfunction

  // ---------------------------------------------------------------------------
  // Count one evaluation that was skipped because the agent drives the signals
  // itself. Kept apart from the executed count so that the statistics never
  // report a check as having passed when it never actually ran
  // ---------------------------------------------------------------------------
  function void record_suppressed_check(input vip_axi4s_check_t check);

    _check_suppressed[int'(check)]++;
  endfunction

  // ---------------------------------------------------------------------------
  // Number of times a check was skipped as locally driven
  // ---------------------------------------------------------------------------
  function int unsigned get_check_suppressed(input vip_axi4s_check_t check);

    int check_idx;

    check_idx = int'(check);
    if (!_check_suppressed.exists(check_idx)) begin
      return 0;
    end

    return _check_suppressed[check_idx];
  endfunction

  // ---------------------------------------------------------------------------
  // Number of times a check has been evaluated
  // ---------------------------------------------------------------------------
  function int unsigned get_check_executed(input vip_axi4s_check_t check);

    int check_idx;

    check_idx = int'(check);
    if (!_check_executed.exists(check_idx)) begin
      return 0;
    end

    return _check_executed[check_idx];
  endfunction

  // ---------------------------------------------------------------------------
  // Number of times a check has failed
  // ---------------------------------------------------------------------------
  function int unsigned get_check_violations(input vip_axi4s_check_t check);

    int check_idx;

    check_idx = int'(check);
    if (!_check_violations.exists(check_idx)) begin
      return 0;
    end

    return _check_violations[check_idx];
  endfunction

  // ---------------------------------------------------------------------------
  // True when any check was evaluated or failed
  // ---------------------------------------------------------------------------
  function bit has_checker_activity();

    vip_axi4s_check_t check;

    for (int i = 0; i < int'(VIP_AXI4S_CHECK_NUM_E); i++) begin
      void'($cast(check, i));
      if (this.get_check_executed(check)   != 0 ||
          this.get_check_suppressed(check) != 0 ||
          this.get_check_violations(check) != 0) begin
        return 1'b1;
      end
    end

    return 1'b0;
  endfunction

  // ---------------------------------------------------------------------------
  // Severity as a lower case string for the statistics
  // ---------------------------------------------------------------------------
  protected function string severity_s(input uvm_severity severity);

    case (severity)
      UVM_INFO:    return "info";
      UVM_WARNING: return "warning";
      UVM_ERROR:   return "error";
      UVM_FATAL:   return "fatal";
      default:     return "unknown";
    endcase
  endfunction

  // ---------------------------------------------------------------------------
  // Per check statistics as CSV text
  // ---------------------------------------------------------------------------
  function string checker_stats_s();

    vip_axi4s_check_t check;
    string            stats;

    stats = "AXI4S checker statistics\n";
    stats = {stats, "check,executed,suppressed,violations,enabled,severity\n"};

    for (int i = 0; i < int'(VIP_AXI4S_CHECK_NUM_E); i++) begin
      void'($cast(check, i));
      if (this.get_check_executed(check)   != 0 ||
          this.get_check_suppressed(check) != 0 ||
          this.get_check_violations(check) != 0) begin
        stats = {stats, $sformatf(
          "%s,%0d,%0d,%0d,%0d,%s\n",
          vip_axi4s_check_name(check),
          this.get_check_executed(check),
          this.get_check_suppressed(check),
          this.get_check_violations(check),
          this.is_check_enabled(check),
          this.severity_s(this.get_check_severity(check))
        )};
      end
    end

    return stats;
  endfunction

  // ---------------------------------------------------------------------------
  // Sample the packet level coverage counters
  // ---------------------------------------------------------------------------
  function void record_coverage_packet(
    input int unsigned                 packet_length,
    input vip_axi4s_stream_xact_type_t stream_xact_type,
    input int unsigned                 tid,
    input int unsigned                 tdest,
    input bit                          has_nonzero_tuser,
    input int unsigned                 backpressure_cycles
  );

    if (!coverage_enable) begin
      return;
    end

    _coverage_packets++;

    // Fixed thresholds, matching the packet_length_cp bins of the monitor
    // covergroup. They deliberately do not follow max_stream_burst_length, so
    // that the same packet always lands in the same bin
    if (packet_length <= 1) begin
      _coverage_packet_length_one++;
    end else if (packet_length <= 15) begin
      _coverage_packet_length_small++;
    end else if (packet_length <= 255) begin
      _coverage_packet_length_medium++;
    end else begin
      _coverage_packet_length_large++;
    end

    _coverage_stream_type[int'(stream_xact_type)]++;

    if (tid == 0) begin
      _coverage_tid_zero++;
    end else begin
      _coverage_tid_nonzero++;
    end

    if (tdest == 0) begin
      _coverage_tdest_zero++;
    end else begin
      _coverage_tdest_nonzero++;
    end

    if (has_nonzero_tuser) begin
      _coverage_tuser_nonzero++;
    end else begin
      _coverage_tuser_zero++;
    end

    if (backpressure_cycles == 0) begin
      _coverage_packet_backpressure_zero++;
    end else if (backpressure_cycles <= 3) begin
      _coverage_packet_backpressure_short++;
    end else begin
      _coverage_packet_backpressure_long++;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Sample the beat level coverage counters
  // ---------------------------------------------------------------------------
  function void record_coverage_beat(
    input int unsigned tkeep,
    input int unsigned tstrb,
    input int unsigned keep_mask,
    input int unsigned tvalid_delay,
    input int unsigned stall_cycles
  );

    if (!coverage_enable) begin
      return;
    end

    _coverage_beats++;

    if (tkeep == 0) begin
      _coverage_tkeep_zero++;
    end else if (tkeep == keep_mask) begin
      _coverage_tkeep_all++;
    end else begin
      _coverage_tkeep_sparse++;
    end

    if (tstrb == 0) begin
      _coverage_tstrb_zero++;
    end else if (tstrb == tkeep) begin
      _coverage_tstrb_all_qualified++;
    end else begin
      _coverage_tstrb_subset++;
    end

    if (tvalid_delay == 0) begin
      _coverage_tvalid_delay_zero++;
    end else if (tvalid_delay <= 3) begin
      _coverage_tvalid_delay_short++;
    end else begin
      _coverage_tvalid_delay_long++;
    end

    if (stall_cycles == 0) begin
      _coverage_tready_stall_zero++;
    end else if (stall_cycles <= 3) begin
      _coverage_tready_stall_short++;
    end else begin
      _coverage_tready_stall_long++;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Count a packet that a reset cut short
  // ---------------------------------------------------------------------------
  function void record_coverage_reset_during_packet();

    if (coverage_enable) begin
      _coverage_reset_during_packet++;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // True when any coverage counter moved
  // ---------------------------------------------------------------------------
  function bit has_coverage_activity();

    return coverage_enable && ((_coverage_packets != 0) || (_coverage_beats != 0) ||
      (_coverage_reset_during_packet != 0));
  endfunction

  // ---------------------------------------------------------------------------
  // Stream transaction type as a lower case string
  // ---------------------------------------------------------------------------
  protected function string stream_type_s(input vip_axi4s_stream_xact_type_t stream_xact_type);

    case (stream_xact_type)
      VIP_AXI4S_BYTE_STREAM_E:
        return "byte_stream";
      VIP_AXI4S_CONTINUOUS_ALIGNED_STREAM_E:
        return "continuous_aligned_stream";
      VIP_AXI4S_CONTINUOUS_UNALIGNED_STREAM_E:
        return "continuous_unaligned_stream";
      VIP_AXI4S_SPARSE_STREAM_E:
        return "sparse_stream";
      VIP_AXI4S_USER_STREAM_E:
        return "user_stream";
      default:
        return "unknown_stream";
    endcase
  endfunction

  // ---------------------------------------------------------------------------
  // Coverage counters as CSV text
  // ---------------------------------------------------------------------------
  function string coverage_summary_s();

    vip_axi4s_stream_xact_type_t stream_xact_type;
    string                       stats;

    stats = "AXI4S coverage summary\n";
    stats = {stats, "metric,count\n"};
    stats = {stats, $sformatf("packets,%0d\n", _coverage_packets)};
    stats = {stats, $sformatf("beats,%0d\n", _coverage_beats)};
    stats = {stats, $sformatf("packet_length_one,%0d\n", _coverage_packet_length_one)};
    stats = {stats, $sformatf("packet_length_small,%0d\n", _coverage_packet_length_small)};
    stats = {stats, $sformatf("packet_length_medium,%0d\n", _coverage_packet_length_medium)};
    stats = {stats, $sformatf("packet_length_large,%0d\n", _coverage_packet_length_large)};
    stats = {stats, $sformatf("packet_backpressure_zero,%0d\n", _coverage_packet_backpressure_zero)};
    stats = {stats, $sformatf("packet_backpressure_short,%0d\n", _coverage_packet_backpressure_short)};
    stats = {stats, $sformatf("packet_backpressure_long,%0d\n", _coverage_packet_backpressure_long)};

    for (int i = 0; i <= int'(VIP_AXI4S_USER_STREAM_E); i++) begin
      void'($cast(stream_xact_type, i));
      stats = {stats, $sformatf(
        "stream_%s,%0d\n",
        this.stream_type_s(stream_xact_type),
        _coverage_stream_type[i]
      )};
    end

    stats = {stats, $sformatf("tid_zero,%0d\n", _coverage_tid_zero)};
    stats = {stats, $sformatf("tid_nonzero,%0d\n", _coverage_tid_nonzero)};
    stats = {stats, $sformatf("tdest_zero,%0d\n", _coverage_tdest_zero)};
    stats = {stats, $sformatf("tdest_nonzero,%0d\n", _coverage_tdest_nonzero)};
    stats = {stats, $sformatf("tuser_zero,%0d\n", _coverage_tuser_zero)};
    stats = {stats, $sformatf("tuser_nonzero,%0d\n", _coverage_tuser_nonzero)};
    stats = {stats, $sformatf("tkeep_zero,%0d\n", _coverage_tkeep_zero)};
    stats = {stats, $sformatf("tkeep_all,%0d\n", _coverage_tkeep_all)};
    stats = {stats, $sformatf("tkeep_sparse,%0d\n", _coverage_tkeep_sparse)};
    stats = {stats, $sformatf("tstrb_zero,%0d\n", _coverage_tstrb_zero)};
    stats = {stats, $sformatf("tstrb_all_qualified,%0d\n", _coverage_tstrb_all_qualified)};
    stats = {stats, $sformatf("tstrb_subset,%0d\n", _coverage_tstrb_subset)};
    stats = {stats, $sformatf("tvalid_delay_zero,%0d\n", _coverage_tvalid_delay_zero)};
    stats = {stats, $sformatf("tvalid_delay_short,%0d\n", _coverage_tvalid_delay_short)};
    stats = {stats, $sformatf("tvalid_delay_long,%0d\n", _coverage_tvalid_delay_long)};
    stats = {stats, $sformatf("tready_stall_zero,%0d\n", _coverage_tready_stall_zero)};
    stats = {stats, $sformatf("tready_stall_short,%0d\n", _coverage_tready_stall_short)};
    stats = {stats, $sformatf("tready_stall_long,%0d\n", _coverage_tready_stall_long)};
    stats = {stats, $sformatf("reset_during_packet,%0d\n", _coverage_reset_during_packet)};

    return stats;
  endfunction

  // ---------------------------------------------------------------------------
  // Clear every performance counter
  // ---------------------------------------------------------------------------
  function void init_performance();

    _perf_packets = 0;
    _perf_beats = 0;
    _perf_data_bytes = 0;
    _perf_active_cycles = 0;
    _perf_valid_cycles = 0;
    _perf_ready_cycles = 0;
    _perf_handshake_cycles = 0;
    _perf_stall_cycles = 0;
    _perf_reset_interruptions = 0;
    _perf_beat_latency_samples = 0;
    _perf_beat_latency_sum = 0;
    _perf_beat_latency_min = 0;
    _perf_beat_latency_max = 0;
    _perf_packet_latency_samples = 0;
    _perf_packet_latency_sum = 0;
    _perf_packet_latency_min = 0;
    _perf_packet_latency_max = 0;
  endfunction

  // ---------------------------------------------------------------------------
  // Track the smallest and largest sample seen so far
  // ---------------------------------------------------------------------------
  protected function void update_perf_min_max(
    ref int unsigned min_value,
    ref int unsigned max_value,
    input int unsigned sample_count,
    input int unsigned value
  );

    if (sample_count == 0) begin
      min_value = value;
      max_value = value;
    end else begin
      if (value < min_value) begin
        min_value = value;
      end
      if (value > max_value) begin
        max_value = value;
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Count one observed clock cycle
  // ---------------------------------------------------------------------------
  function void record_performance_cycle(input bit tvalid, input bit tready);

    if (!performance_enable) begin
      return;
    end
    _perf_active_cycles++;
    if (tvalid) begin
      _perf_valid_cycles++;
    end
    if (tready) begin
      _perf_ready_cycles++;
    end
    if (tvalid && tready) begin
      _perf_handshake_cycles++;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Count one observed beat and its stall cycles
  // ---------------------------------------------------------------------------
  function void record_performance_beat(
    input int unsigned data_bytes,
    input int unsigned stall_cycles
  );

    int unsigned beat_latency;

    if (!performance_enable) begin
      return;
    end

    beat_latency = stall_cycles + 1;
    _perf_beats++;
    _perf_data_bytes += data_bytes;
    _perf_stall_cycles += stall_cycles;
    this.update_perf_min_max(
      _perf_beat_latency_min,
      _perf_beat_latency_max,
      _perf_beat_latency_samples,
      beat_latency
    );
    _perf_beat_latency_samples++;
    _perf_beat_latency_sum += beat_latency;
  endfunction

  // ---------------------------------------------------------------------------
  // Count one observed packet and its latency
  // ---------------------------------------------------------------------------
  function void record_performance_packet(input int unsigned packet_latency_cycles);

    if (!performance_enable) begin
      return;
    end

    _perf_packets++;
    this.update_perf_min_max(
      _perf_packet_latency_min,
      _perf_packet_latency_max,
      _perf_packet_latency_samples,
      packet_latency_cycles
    );
    _perf_packet_latency_samples++;
    _perf_packet_latency_sum += packet_latency_cycles;
  endfunction

  // ---------------------------------------------------------------------------
  // Count a packet that a reset cut short
  // ---------------------------------------------------------------------------
  function void record_performance_reset_during_packet();

    if (performance_enable) begin
      _perf_reset_interruptions++;
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Number of observed packets
  // ---------------------------------------------------------------------------
  function int unsigned get_performance_packets();

    return _perf_packets;
  endfunction

  // ---------------------------------------------------------------------------
  // Number of observed beats
  // ---------------------------------------------------------------------------
  function int unsigned get_performance_beats();

    return _perf_beats;
  endfunction

  // ---------------------------------------------------------------------------
  // Number of observed data bytes
  // ---------------------------------------------------------------------------
  function int unsigned get_performance_data_bytes();

    return _perf_data_bytes;
  endfunction

  // ---------------------------------------------------------------------------
  // True when any performance counter moved
  // ---------------------------------------------------------------------------
  function bit has_performance_activity();

    return performance_enable && ((_perf_active_cycles != 0) || (_perf_beats != 0) ||
      (_perf_packets != 0) || (_perf_reset_interruptions != 0));
  endfunction

  // ---------------------------------------------------------------------------
  // Mean of a sum and a sample count, zero when there are none
  // ---------------------------------------------------------------------------
  protected function real mean_value(input int unsigned total, input int unsigned count);

    if (count == 0) begin
      return 0.0;
    end
    return real'(total) / real'(count);
  endfunction

  // ---------------------------------------------------------------------------
  // Percentage of a total, zero when the total is zero
  // ---------------------------------------------------------------------------
  protected function real percent_value(input int unsigned value, input int unsigned total);

    if (total == 0) begin
      return 0.0;
    end
    return 100.0 * real'(value) / real'(total);
  endfunction

  // ---------------------------------------------------------------------------
  // Ratio of a total, zero when the total is zero
  // ---------------------------------------------------------------------------
  protected function real ratio_value(input int unsigned value, input int unsigned total);

    if (total == 0) begin
      return 0.0;
    end
    return real'(value) / real'(total);
  endfunction

  // ---------------------------------------------------------------------------
  // Performance counters as CSV text
  // ---------------------------------------------------------------------------
  function string performance_summary_s();

    string stats;

    stats = "AXI4S performance summary\n";
    stats = {stats, "metric,value\n"};
    stats = {stats, $sformatf("packets,%0d\n", _perf_packets)};
    stats = {stats, $sformatf("beats,%0d\n", _perf_beats)};
    stats = {stats, $sformatf("data_bytes,%0d\n", _perf_data_bytes)};
    stats = {stats, $sformatf("active_cycles,%0d\n", _perf_active_cycles)};
    stats = {stats, $sformatf("valid_cycles,%0d\n", _perf_valid_cycles)};
    stats = {stats, $sformatf("ready_cycles,%0d\n", _perf_ready_cycles)};
    stats = {stats, $sformatf("handshake_cycles,%0d\n", _perf_handshake_cycles)};
    stats = {stats, $sformatf("stall_cycles,%0d\n", _perf_stall_cycles)};
    stats = {stats, $sformatf("reset_interruptions,%0d\n", _perf_reset_interruptions)};
    stats = {stats, $sformatf("beat_latency_min_cycles,%0d\n", _perf_beat_latency_min)};
    stats = {stats, $sformatf("beat_latency_mean_cycles,%0.3f\n",
      this.mean_value(_perf_beat_latency_sum, _perf_beat_latency_samples))};
    stats = {stats, $sformatf("beat_latency_max_cycles,%0d\n", _perf_beat_latency_max)};
    stats = {stats, $sformatf("packet_latency_min_cycles,%0d\n", _perf_packet_latency_min)};
    stats = {stats, $sformatf("packet_latency_mean_cycles,%0.3f\n",
      this.mean_value(_perf_packet_latency_sum, _perf_packet_latency_samples))};
    stats = {stats, $sformatf("packet_latency_max_cycles,%0d\n", _perf_packet_latency_max)};
    stats = {stats, $sformatf("valid_duty_percent,%0.3f\n",
      this.percent_value(_perf_valid_cycles, _perf_active_cycles))};
    stats = {stats, $sformatf("ready_duty_percent,%0.3f\n",
      this.percent_value(_perf_ready_cycles, _perf_active_cycles))};
    stats = {stats, $sformatf("bus_utilization_percent,%0.3f\n",
      this.percent_value(_perf_handshake_cycles, _perf_active_cycles))};
    stats = {stats, $sformatf("throughput_bytes_per_cycle,%0.3f\n",
      this.ratio_value(_perf_data_bytes, _perf_active_cycles))};
    return stats;
  endfunction

  // ---------------------------------------------------------------------------
  // Fatal out on a negative or inverted delay range
  // ---------------------------------------------------------------------------
  protected function void validate_range(
    input string name,
    input int    min,
    input int    max
  );

    if (min < 0) begin

      `uvm_fatal(get_name(), $sformatf(
      "%s min (%0d) must be non-negative", name, min))
    end

    if (max < min) begin

      `uvm_fatal(get_name(), $sformatf(
      "%s max (%0d) must be >= min (%0d)", name, max, min))
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Create the generator if needed and build its CDF
  // ---------------------------------------------------------------------------
  protected function void build_gauss(
    ref   vip_gauss g,
    input string    name,
    input int       min,
    input int       max,
    input int       mean,
    input real      stddev
  );

    this.validate_range(name, min, max);

    if (g == null) begin

      g = vip_gauss::type_id::create(name);
    end

    g.gen_cdf(min, max, mean, stddev);
  endfunction

  // ---------------------------------------------------------------------------
  // Rebuild every enabled Gaussian delay CDF
  // ---------------------------------------------------------------------------
  function void rebuild_gauss_cdfs();

    this.validate_range("tvalid_delay_time", min_tvalid_delay_time, max_tvalid_delay_time);
    this.validate_range("tvalid_delay_period", min_tvalid_delay_period, max_tvalid_delay_period);
    this.validate_range("tready_delay_time", min_tready_delay_time, max_tready_delay_time);
    this.validate_range("tready_delay_period", min_tready_delay_period, max_tready_delay_period);

    if (tvalid_delay_gauss_enabled == TRUE) begin

      this.build_gauss(
        g_tvalid_time,
        "g_tvalid_time",
        min_tvalid_delay_time,
        max_tvalid_delay_time,
        tvalid_delay_time_mean,
        tvalid_delay_time_stddev
      );

      this.build_gauss(
        g_tvalid_period,
        "g_tvalid_period",
        min_tvalid_delay_period,
        max_tvalid_delay_period,
        tvalid_delay_period_mean,
        tvalid_delay_period_stddev
      );
    end

    if (tready_delay_gauss_enabled == TRUE) begin

      this.build_gauss(
        g_tready_time,
        "g_tready_time",
        min_tready_delay_time,
        max_tready_delay_time,
        tready_delay_time_mean,
        tready_delay_time_stddev
      );

      this.build_gauss(
        g_tready_period,
        "g_tready_period",
        min_tready_delay_period,
        max_tready_delay_period,
        tready_delay_period_mean,
        tready_delay_period_stddev
      );
    end
  endfunction

  // ---------------------------------------------------------------------------
  // One delay value, Gaussian or uniform
  // ---------------------------------------------------------------------------
  function int unsigned get_delay(
    input bool_t    delay_enabled,
    input bool_t    gauss_enabled,
          vip_gauss gauss,
    input int       min,
    input int       max
  );

    this.validate_range("delay", min, max);

    if (delay_enabled == FALSE) begin

      return 0;
    end

    if (gauss_enabled == TRUE) begin

      if (gauss == null) begin

        `uvm_fatal(get_name(), "Gaussian delay requested before CDF was built")
      end

      return gauss.get_r_cdf_int();
    end

    return $urandom_range(max, min);
  endfunction
endclass
