################################################################################
# pyUVM port of vip_axi4s_config.sv.
################################################################################

from __future__ import annotations

import random

try:
  from vip_gauss import vip_gauss
except Exception:
  vip_gauss = None

from vip_axi4s_types_pkg import (
  Axi4sAgentType, Axi4sCheck, Axi4sStreamXactType, axi4s_check_name,
)


class _UniformGaussFallback:
  def __init__(self, name="gauss"):
    self.name = name
    self.mn = 0
    self.mx = 0

  def gen_cdf(self, mn, mx, mean, stddev):
    self.mn = mn
    self.mx = mx

  def get_r_cdf_int(self):
    return random.randint(self.mn, self.mx)


def _new_gauss(name):
  return vip_gauss(name) if vip_gauss is not None else _UniformGaussFallback(name)


class vip_axi4s_config:

  def __init__(self, name="vip_axi4s_config"):
    self.name = name
    self.is_active = "UVM_ACTIVE"
    self.vip_axi4s_agent_type = Axi4sAgentType.MASTER

    self.tvalid_delay_enabled = True
    self.tvalid_delay_gauss_enabled = True
    self.min_tvalid_delay_time = 1
    self.max_tvalid_delay_time = 10
    self.tvalid_delay_time_mean = 4
    self.tvalid_delay_time_stddev = 2.0
    self.min_tvalid_delay_period = 10
    self.max_tvalid_delay_period = 256
    self.tvalid_delay_period_mean = 64
    self.tvalid_delay_period_stddev = 32.0
    self.g_tvalid_time = None
    self.g_tvalid_period = None

    self.tready_delay_enabled = True
    self.tready_delay_gauss_enabled = True
    self.min_tready_delay_time = 1
    self.max_tready_delay_time = 10
    self.tready_delay_time_mean = 4
    self.tready_delay_time_stddev = 2.0
    self.min_tready_delay_period = 10
    self.max_tready_delay_period = 256
    self.tready_delay_period_mean = 64
    self.tready_delay_period_stddev = 32.0
    self.g_tready_time = None
    self.g_tready_period = None
    self.zero_delays_enable = False

    self.protocol_checks_enable = True
    self.per_clock_checks_enable = True
    self.max_stream_burst_length = 256
    self.stream_interleave_depth = 1
    self.single_outstanding_per_tdest_enable = False
    self.coverage_enable = True
    self.trace_enable = False
    self.trace_format = "jsonl"
    self.trace_path = ""
    self.trace_flush_enable = True
    self.performance_enable = False
    self.drive_idle_values_enable = False
    self.idle_tdata = 0
    self.idle_tstrb = 0
    self.idle_tkeep = 0
    self.idle_tlast = 0
    self.idle_tid = 0
    self.idle_tdest = 0
    self.idle_tuser = 0
    self.tlast_idle_toggle_enable = False
    self.tready_idle_toggle_enable = False
    self.tdata_only_fast_path_enable = False
    self.init_checker_defaults()
    self.init_coverage()
    self.init_performance()

  def init_checker_defaults(self):
    self.check_enable = {check: True for check in Axi4sCheck}
    self.check_severity = {check: "ERROR" for check in Axi4sCheck}
    self.check_executed = {check: 0 for check in Axi4sCheck}
    self.check_suppressed = {check: 0 for check in Axi4sCheck}
    self.check_violations = {check: 0 for check in Axi4sCheck}

  def is_per_clock_check(self, check):
    check = Axi4sCheck(check)
    return check in {
      Axi4sCheck.SIGNAL_VALID_TVALID,
      Axi4sCheck.SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TSTRB_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TKEEP_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TLAST_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TID_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TDEST_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TUSER_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TSTRB_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TKEEP_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TLAST_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TID_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TDEST_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH,
    }

  def is_check_enabled(self, check):
    check = Axi4sCheck(check)
    if not self.protocol_checks_enable:
      return False
    if self.is_per_clock_check(check) and not self.per_clock_checks_enable:
      return False
    return self.check_enable.get(check, True)

  def set_check_enable(self, check, enabled):
    self.check_enable[Axi4sCheck(check)] = bool(enabled)

  def set_check_severity(self, check, severity):
    self.check_severity[Axi4sCheck(check)] = _normalize_severity(severity)

  def get_check_severity(self, check):
    return self.check_severity.get(Axi4sCheck(check), "ERROR")

  def record_check(self, check):
    check = Axi4sCheck(check)
    self.check_executed[check] = self.check_executed.get(check, 0) + 1

  def record_violation(self, check):
    check = Axi4sCheck(check)
    self.check_violations[check] = self.check_violations.get(check, 0) + 1

  def record_suppressed_check(self, check):
    # Counted apart from the executed count so that the statistics never report
    # a check as having passed when it never actually ran
    check = Axi4sCheck(check)
    self.check_suppressed[check] = self.check_suppressed.get(check, 0) + 1

  def get_check_executed(self, check):
    return self.check_executed.get(Axi4sCheck(check), 0)

  def get_check_violations(self, check):
    return self.check_violations.get(Axi4sCheck(check), 0)

  def get_check_suppressed(self, check):
    return self.check_suppressed.get(Axi4sCheck(check), 0)

  def has_checker_activity(self):
    return any(
      self.get_check_executed(check) or self.get_check_suppressed(check) or
      self.get_check_violations(check)
      for check in Axi4sCheck)

  def checker_stats_s(self):
    rows = ["AXI4S checker statistics",
            "check,executed,suppressed,violations,enabled,severity"]
    for check in Axi4sCheck:
      if (self.get_check_executed(check) or self.get_check_suppressed(check) or
          self.get_check_violations(check)):
        rows.append(
          f"{axi4s_check_name(check)},"
          f"{self.get_check_executed(check)},"
          f"{self.get_check_suppressed(check)},"
          f"{self.get_check_violations(check)},"
          f"{int(self.is_check_enabled(check))},"
          f"{self.get_check_severity(check).lower()}")
    return "\n".join(rows)

  def init_coverage(self):
    self.coverage = {
      "packets": 0,
      "beats": 0,
      "packet_length_one": 0,
      "packet_length_small": 0,
      "packet_length_medium": 0,
      "packet_length_large": 0,
      "packet_backpressure_zero": 0,
      "packet_backpressure_short": 0,
      "packet_backpressure_long": 0,
      "tid_zero": 0,
      "tid_nonzero": 0,
      "tdest_zero": 0,
      "tdest_nonzero": 0,
      "tuser_zero": 0,
      "tuser_nonzero": 0,
      "tkeep_zero": 0,
      "tkeep_all": 0,
      "tkeep_sparse": 0,
      "tstrb_zero": 0,
      "tstrb_all_qualified": 0,
      "tstrb_subset": 0,
      "tvalid_delay_zero": 0,
      "tvalid_delay_short": 0,
      "tvalid_delay_long": 0,
      "tready_stall_zero": 0,
      "tready_stall_short": 0,
      "tready_stall_long": 0,
      "reset_during_packet": 0,
    }
    for stream in Axi4sStreamXactType:
      self.coverage[f"stream_{stream_name(stream)}"] = 0

  def init_performance(self):
    self.performance = {
      "packets": 0,
      "beats": 0,
      "data_bytes": 0,
      "active_cycles": 0,
      "valid_cycles": 0,
      "ready_cycles": 0,
      "handshake_cycles": 0,
      "stall_cycles": 0,
      "reset_interruptions": 0,
      "beat_latency_samples": 0,
      "beat_latency_sum": 0,
      "beat_latency_min": 0,
      "beat_latency_max": 0,
      "packet_latency_samples": 0,
      "packet_latency_sum": 0,
      "packet_latency_min": 0,
      "packet_latency_max": 0,
    }

  def _update_min_max(self, min_name, max_name, sample_count_name, value):
    if self.performance[sample_count_name] == 0:
      self.performance[min_name] = value
      self.performance[max_name] = value
    else:
      self.performance[min_name] = min(self.performance[min_name], value)
      self.performance[max_name] = max(self.performance[max_name], value)

  def record_performance_cycle(self, tvalid, tready):
    if not self.performance_enable:
      return
    tvalid = bool(tvalid)
    tready = bool(tready)
    self.performance["active_cycles"] += 1
    if tvalid:
      self.performance["valid_cycles"] += 1
    if tready:
      self.performance["ready_cycles"] += 1
    if tvalid and tready:
      self.performance["handshake_cycles"] += 1

  def record_performance_beat(self, data_bytes, stall_cycles):
    if not self.performance_enable:
      return
    beat_latency = int(stall_cycles) + 1
    self.performance["beats"] += 1
    self.performance["data_bytes"] += int(data_bytes)
    self.performance["stall_cycles"] += int(stall_cycles)
    self._update_min_max(
      "beat_latency_min", "beat_latency_max", "beat_latency_samples",
      beat_latency)
    self.performance["beat_latency_samples"] += 1
    self.performance["beat_latency_sum"] += beat_latency

  def record_performance_packet(self, packet_latency_cycles):
    if not self.performance_enable:
      return
    packet_latency_cycles = int(packet_latency_cycles)
    self.performance["packets"] += 1
    self._update_min_max(
      "packet_latency_min", "packet_latency_max", "packet_latency_samples",
      packet_latency_cycles)
    self.performance["packet_latency_samples"] += 1
    self.performance["packet_latency_sum"] += packet_latency_cycles

  def record_performance_reset_during_packet(self):
    if self.performance_enable:
      self.performance["reset_interruptions"] += 1

  def get_performance_packets(self):
    return self.performance["packets"]

  def get_performance_beats(self):
    return self.performance["beats"]

  def get_performance_data_bytes(self):
    return self.performance["data_bytes"]

  def has_performance_activity(self):
    return self.performance_enable and (
      self.performance["active_cycles"] or self.performance["beats"] or
      self.performance["packets"] or self.performance["reset_interruptions"])

  def record_coverage_packet(self, packet_length, stream_xact_type, tid, tdest,
                             has_nonzero_tuser, backpressure_cycles):
    if not self.coverage_enable:
      return
    self.coverage["packets"] += 1
    # Fixed thresholds, matching the packet_length_cp bins of the SV covergroup.
    # They deliberately do not follow max_stream_burst_length, so that the same
    # packet always lands in the same bin
    if packet_length <= 1:
      self.coverage["packet_length_one"] += 1
    elif packet_length <= 15:
      self.coverage["packet_length_small"] += 1
    elif packet_length <= 255:
      self.coverage["packet_length_medium"] += 1
    else:
      self.coverage["packet_length_large"] += 1
    self.coverage[f"stream_{stream_name(Axi4sStreamXactType(stream_xact_type))}"] += 1
    self.coverage["tid_zero" if int(tid) == 0 else "tid_nonzero"] += 1
    self.coverage["tdest_zero" if int(tdest) == 0 else "tdest_nonzero"] += 1
    self.coverage["tuser_nonzero" if has_nonzero_tuser else "tuser_zero"] += 1
    if backpressure_cycles == 0:
      self.coverage["packet_backpressure_zero"] += 1
    elif backpressure_cycles <= 3:
      self.coverage["packet_backpressure_short"] += 1
    else:
      self.coverage["packet_backpressure_long"] += 1

  def record_coverage_beat(self, tkeep, tstrb, keep_mask, tvalid_delay,
                           stall_cycles):
    if not self.coverage_enable:
      return
    self.coverage["beats"] += 1
    if tkeep == 0:
      self.coverage["tkeep_zero"] += 1
    elif tkeep == keep_mask:
      self.coverage["tkeep_all"] += 1
    else:
      self.coverage["tkeep_sparse"] += 1
    if tstrb == 0:
      self.coverage["tstrb_zero"] += 1
    elif tstrb == tkeep:
      self.coverage["tstrb_all_qualified"] += 1
    else:
      self.coverage["tstrb_subset"] += 1
    if tvalid_delay == 0:
      self.coverage["tvalid_delay_zero"] += 1
    elif tvalid_delay <= 3:
      self.coverage["tvalid_delay_short"] += 1
    else:
      self.coverage["tvalid_delay_long"] += 1
    if stall_cycles == 0:
      self.coverage["tready_stall_zero"] += 1
    elif stall_cycles <= 3:
      self.coverage["tready_stall_short"] += 1
    else:
      self.coverage["tready_stall_long"] += 1

  def record_coverage_reset_during_packet(self):
    if self.coverage_enable:
      self.coverage["reset_during_packet"] += 1

  def has_coverage_activity(self):
    return (
      self.coverage_enable and
      (self.coverage["packets"] or self.coverage["beats"] or
       self.coverage["reset_during_packet"]))

  def coverage_summary_s(self):
    rows = ["AXI4S coverage summary", "metric,count"]
    ordered = [
      "packets",
      "beats",
      "packet_length_one",
      "packet_length_small",
      "packet_length_medium",
      "packet_length_large",
      "packet_backpressure_zero",
      "packet_backpressure_short",
      "packet_backpressure_long",
    ]
    ordered.extend(f"stream_{stream_name(stream)}" for stream in Axi4sStreamXactType)
    ordered.extend([
      "tid_zero",
      "tid_nonzero",
      "tdest_zero",
      "tdest_nonzero",
      "tuser_zero",
      "tuser_nonzero",
      "tkeep_zero",
      "tkeep_all",
      "tkeep_sparse",
      "tstrb_zero",
      "tstrb_all_qualified",
      "tstrb_subset",
      "tvalid_delay_zero",
      "tvalid_delay_short",
      "tvalid_delay_long",
      "tready_stall_zero",
      "tready_stall_short",
      "tready_stall_long",
      "reset_during_packet",
    ])
    rows.extend(f"{name},{self.coverage.get(name, 0)}" for name in ordered)
    return "\n".join(rows)

  def performance_summary_s(self):
    p = self.performance
    active_cycles = p["active_cycles"]
    mean_beat_latency = _mean(p["beat_latency_sum"], p["beat_latency_samples"])
    mean_packet_latency = _mean(
      p["packet_latency_sum"], p["packet_latency_samples"])
    rows = ["AXI4S performance summary", "metric,value"]
    rows.extend([
      f"packets,{p['packets']}",
      f"beats,{p['beats']}",
      f"data_bytes,{p['data_bytes']}",
      f"active_cycles,{active_cycles}",
      f"valid_cycles,{p['valid_cycles']}",
      f"ready_cycles,{p['ready_cycles']}",
      f"handshake_cycles,{p['handshake_cycles']}",
      f"stall_cycles,{p['stall_cycles']}",
      f"reset_interruptions,{p['reset_interruptions']}",
      f"beat_latency_min_cycles,{p['beat_latency_min']}",
      f"beat_latency_mean_cycles,{mean_beat_latency:.3f}",
      f"beat_latency_max_cycles,{p['beat_latency_max']}",
      f"packet_latency_min_cycles,{p['packet_latency_min']}",
      f"packet_latency_mean_cycles,{mean_packet_latency:.3f}",
      f"packet_latency_max_cycles,{p['packet_latency_max']}",
      f"valid_duty_percent,{_percent(p['valid_cycles'], active_cycles):.3f}",
      f"ready_duty_percent,{_percent(p['ready_cycles'], active_cycles):.3f}",
      f"bus_utilization_percent,{_percent(p['handshake_cycles'], active_cycles):.3f}",
      f"throughput_bytes_per_cycle,{_ratio(p['data_bytes'], active_cycles):.3f}",
    ])
    return "\n".join(rows)

  def validate_range(self, name, mn, mx):
    if mn < 0:
      raise ValueError(f"[{self.name}] {name} min ({mn}) must be non-negative")
    if mx < mn:
      raise ValueError(f"[{self.name}] {name} max ({mx}) must be >= min ({mn})")

  def _build_gauss(self, attr, name, mn, mx, mean, stddev):
    self.validate_range(name, mn, mx)
    g = getattr(self, attr)
    if g is None:
      g = _new_gauss(name)
      setattr(self, attr, g)
    g.gen_cdf(mn, mx, mean, stddev)

  def rebuild_gauss_cdfs(self):
    self.validate_range("tvalid_delay_time",
                        self.min_tvalid_delay_time, self.max_tvalid_delay_time)
    self.validate_range("tvalid_delay_period",
                        self.min_tvalid_delay_period, self.max_tvalid_delay_period)
    self.validate_range("tready_delay_time",
                        self.min_tready_delay_time, self.max_tready_delay_time)
    self.validate_range("tready_delay_period",
                        self.min_tready_delay_period, self.max_tready_delay_period)

    if self.tvalid_delay_gauss_enabled:
      self._build_gauss(
        "g_tvalid_time", "g_tvalid_time",
        self.min_tvalid_delay_time, self.max_tvalid_delay_time,
        self.tvalid_delay_time_mean, self.tvalid_delay_time_stddev)
      self._build_gauss(
        "g_tvalid_period", "g_tvalid_period",
        self.min_tvalid_delay_period, self.max_tvalid_delay_period,
        self.tvalid_delay_period_mean, self.tvalid_delay_period_stddev)

    if self.tready_delay_gauss_enabled:
      self._build_gauss(
        "g_tready_time", "g_tready_time",
        self.min_tready_delay_time, self.max_tready_delay_time,
        self.tready_delay_time_mean, self.tready_delay_time_stddev)
      self._build_gauss(
        "g_tready_period", "g_tready_period",
        self.min_tready_delay_period, self.max_tready_delay_period,
        self.tready_delay_period_mean, self.tready_delay_period_stddev)

  def get_delay(self, delay_enabled, gauss_enabled, gauss, mn, mx):
    self.validate_range("delay", mn, mx)
    if not delay_enabled:
      return 0
    if gauss_enabled:
      if gauss is None:
        raise RuntimeError(f"[{self.name}] Gaussian delay requested before CDF was built")
      return gauss.get_r_cdf_int()
    return random.randint(mn, mx)


def _normalize_severity(severity):
  value = str(severity).upper()
  if value.startswith("UVM_"):
    value = value[4:]
  if value == "WARN":
    value = "WARNING"
  if value not in {"INFO", "WARNING", "ERROR", "FATAL"}:
    raise ValueError(f"Unsupported AXI4S checker severity: {severity}")
  return value


def stream_name(stream):
  stream = Axi4sStreamXactType(stream)
  return {
    Axi4sStreamXactType.BYTE_STREAM: "byte_stream",
    Axi4sStreamXactType.CONTINUOUS_ALIGNED_STREAM: "continuous_aligned_stream",
    Axi4sStreamXactType.CONTINUOUS_UNALIGNED_STREAM: "continuous_unaligned_stream",
    Axi4sStreamXactType.SPARSE_STREAM: "sparse_stream",
    Axi4sStreamXactType.USER_STREAM: "user_stream",
  }[stream]


def _mean(total, count):
  return 0.0 if count == 0 else float(total) / float(count)


def _percent(value, total):
  return 0.0 if total == 0 else 100.0 * float(value) / float(total)


def _ratio(value, total):
  return 0.0 if total == 0 else float(value) / float(total)
