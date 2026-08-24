################################################################################
# pyUVM port of vip_axi4s_monitor.sv.
################################################################################

from __future__ import annotations

import csv
import json
import os

import cocotb
from cocotb.triggers import Combine, FallingEdge, ReadOnly
from cocotb.utils import get_sim_time

from pyuvm import ConfigDB, uvm_analysis_port, uvm_monitor

from vip_axi4s_config import vip_axi4s_config
from vip_axi4s_item import vip_axi4s_item
from vip_axi4s_types_pkg import Axi4sAgentType, Axi4sCheck, axi4s_check_name


TRACE_COLUMNS = [
  "event", "cycle", "time_ns", "tid", "tdest", "beat", "length",
  "tdata", "tstrb", "tkeep", "tuser", "tlast", "stream",
  "stall_cycles", "latency_cycles", "check", "message",
]


class vip_axi4s_monitor(uvm_monitor):

  def __init__(self, name, parent):
    super().__init__(name, parent)
    self.tdata_port = uvm_analysis_port("tdata_port", self)
    self.beat_port = uvm_analysis_port("beat_port", self)
    self.violation_port = uvm_analysis_port("violation_port", self)
    self.stats_port = uvm_analysis_port("stats_port", self)
    self.vif = None
    self.cfg = None
    self.cfg_t = None
    self._monitor_tasks = []
    self.agent_owned = False
    self.packet_start_cb = None
    self.callbacks = []
    self._packet_open = False
    self._packet_start_open_keys = set()
    self._packet_tid = 0
    self._packet_tdest = 0
    self._open_packets = {}
    self._pending_stall_cycles = 0
    self._tvalid_delay_cycles = 0
    self._saw_tvalid = False
    self._cycle_count = 0
    self._trace_file = None
    self._trace_writer = None
    self.handle_reset(report_packet=False)

  def build_phase(self):
    self.vif = ConfigDB().get(self, "", "vif")
    self.cfg_t = ConfigDB().get(self, "", "cfg_t")
    try:
      self.cfg = ConfigDB().get(self, "", "cfg")
    except Exception:
      self.logger.info("Monitor has no config, creating a default config")
      self.cfg = vip_axi4s_config(f"default_config_{self.get_name()}")

  async def run_phase(self):
    if self.agent_owned:
      return
    cocotb.start_soon(self.check_reset_protocol())
    while True:
      while self.vif.get_rst() == 0:
        await self.vif.rising()
      task = cocotb.start_soon(self.monitor_start())
      await FallingEdge(self.vif.rst_n)
      _cancel_task(task)
      self.handle_reset()

  async def monitor_start(self):
    self._monitor_tasks = [
      cocotb.start_soon(self.collect_transfers()),
      cocotb.start_soon(self.check_protocol()),
      cocotb.start_soon(self.detect_packet_start()),
    ]
    await Combine(*self._monitor_tasks)

  async def detect_packet_start(self):
    # The falling clock edge is used instead of a TVALID rising edge so that
    # back-to-back packets, where TVALID never goes low across the TLAST
    # boundary, are detected too. It is still half a clock cycle before the
    # first beat can handshake, which is what the zero time response contract
    # needs
    while True:
      await self.vif.falling()
      await ReadOnly()
      if self.vif.get_rst() == 1 and self.vif.get_or("tvalid") == 1:
        tid = self.vif.get_or("tid")
        tdest = self.vif.get_or("tdest")
        if not self._packet_start_is_open(tid, tdest):
          self._notify_packet_start(tid, tdest)

  def add_callback(self, cb):
    self.callbacks.append(cb)

  def handle_reset(self, report_packet=True):
    for task in getattr(self, "_monitor_tasks", []):
      try:
        if not task.done():
          _cancel_task(task)
      except Exception:
        pass
    self._monitor_tasks = []

    if report_packet:
      for state in self._open_packets.values():
        if not state["tdata"]:
          continue
        self._check_assert(
          Axi4sCheck.PACKET_TRUNCATED_BY_RESET,
          False,
          f"Packet truncated by reset after {len(state['tdata'])} beats "
          f"(tid=0x{state['tid']:x} tdest=0x{state['tdest']:x})")
        item = self._build_packet_item(state)
        self._sample_packet_coverage(item, state["stall_cycles"], reset_seen=True)
        if self.cfg is not None:
          self.cfg.record_performance_reset_during_packet()
        self._trace_packet(
          item,
          state["stall_cycles"],
          self._packet_latency_cycles(state),
          reset_seen=True)
        if self.cfg is not None:
          self.cfg.record_coverage_reset_during_packet()

    self._packet_open = False
    self._packet_start_open_keys.clear()
    self._packet_tid = 0
    self._packet_tdest = 0
    self._open_packets = {}
    self._pending_stall_cycles = 0
    self._tvalid_delay_cycles = 0
    self._saw_tvalid = False

  async def collect_transfers(self):
    while True:
      await self.vif.sample_edge()
      self._cycle_count += 1
      self._record_performance_cycle()
      self._update_stall_tracking()
      handshake = self._handshake()

      if handshake:
        tid = self.vif.get_or("tid")
        tdest = self.vif.get_or("tdest")
        key = self._stream_key(tid, tdest)

        if key not in self._open_packets:
          self._check_single_outstanding_per_tdest(tdest, key)
          self._open_packets[key] = {
            "tid": tid,
            "tdest": tdest,
            "tdata": [],
            "tstrb": [],
            "tkeep": [],
            "tuser": [],
            "stall_cycles": 0,
            "start_cycle": self._cycle_count,
          }
          self._check_stream_interleave_depth()

        state = self._open_packets[key]
        beat_index = len(state["tdata"])

        # A TID/TDEST change before TLAST is only a violation when interleaving
        # is not permitted. Once more than one stream may be open at a time,
        # switching between them mid packet is legal and the per stream
        # tracking in _open_packets is what keeps the packets apart
        if not self._packet_open:
          self._packet_open = True
          self._packet_tid = tid
          self._packet_tdest = tdest
        elif not self._interleaving_allowed():
          self._check_assert(
            Axi4sCheck.TID_OR_TDEST_CHANGE_BEFORE_TLAST,
            tid == self._packet_tid and tdest == self._packet_tdest,
            "TID/TDEST changed before TLAST "
            f"(first tid=0x{self._packet_tid:x} tdest=0x{self._packet_tdest:x}, "
            f"current tid=0x{tid:x} tdest=0x{tdest:x})")

        tdata = self.vif.get_or("tdata")
        tstrb = self.vif.get_or("tstrb")
        tkeep = self.vif.get_or("tkeep")
        tuser = self.vif.get_or("tuser")
        state["tdata"].append(tdata)
        state["tstrb"].append(tstrb)
        state["tkeep"].append(tkeep)
        state["tuser"].append(tuser)
        state["stall_cycles"] += self._pending_stall_cycles

        beat_item = self._build_beat_item(tdata, tstrb, tkeep, tuser, tid, tdest)
        self._sample_beat_coverage(
          tkeep,
          tstrb,
          self._current_tvalid_delay(),
          self._pending_stall_cycles)
        self._record_performance_beat(tstrb, tkeep, self._pending_stall_cycles)
        self._trace_beat(
          beat_index,
          tdata,
          tstrb,
          tkeep,
          tuser,
          tid,
          tdest,
          self.vif.get_or("tlast"),
          self._pending_stall_cycles)
        self.beat_port.write(beat_item)
        self._do_beat_sampled(beat_item)

        self._check_assert(
          Axi4sCheck.MAX_STREAM_BURST_LENGTH_EXCEEDED,
          len(state["tdata"]) <= self.cfg.max_stream_burst_length,
          f"Packet length {len(state['tdata'])} exceeds "
          f"max_stream_burst_length {self.cfg.max_stream_burst_length}")
        self._pending_stall_cycles = 0

      if handshake and self.vif.get_or("tlast") == 1:
        key = self._stream_key(self.vif.get_or("tid"), self.vif.get_or("tdest"))
        state = self._open_packets.pop(key, None)
        if state is not None:
          item = self._build_packet_item(state)
          packet_latency = self._packet_latency_cycles(state)
          stall_cycles = state["stall_cycles"]
          self._sample_packet_coverage(item, stall_cycles, reset_seen=False)
          self._record_performance_packet(packet_latency)
          self._trace_packet(item, stall_cycles, packet_latency, reset_seen=False)

          self._packet_open = False
          self._close_packet_start(self.vif.get_or("tid"), self.vif.get_or("tdest"))
          self._packet_tid = 0
          self._packet_tdest = 0
          self.tdata_port.write(item)
          self._do_packet_completed(item)

      self._update_tvalid_delay_tracking()

  def _notify_packet_start(self, tid, tdest):
    self._packet_start_open_keys.add(self._stream_key(tid, tdest))
    if self.packet_start_cb is None:
      return
    packet_start_item = vip_axi4s_item("packet_start_item", self.cfg_t)
    packet_start_item.tid = tid
    packet_start_item.tdest = tdest
    self.packet_start_cb(packet_start_item)

  def _packet_start_is_open(self, tid, tdest):
    if self._interleaving_allowed():
      return self._stream_key(tid, tdest) in self._packet_start_open_keys
    return bool(self._packet_start_open_keys)

  def _close_packet_start(self, tid, tdest):
    self._packet_start_open_keys.discard(self._stream_key(tid, tdest))

  def _interleaving_allowed(self):
    return self.cfg is not None and self.cfg.stream_interleave_depth > 1

  def _stream_key(self, tid, tdest):
    return f"{int(tid):x}:{int(tdest):x}"

  def _check_single_outstanding_per_tdest(self, tdest, new_key):
    if self.cfg is None or not self.cfg.single_outstanding_per_tdest_enable:
      return
    allowed = all(
      key == new_key or state["tdest"] != tdest
      for key, state in self._open_packets.items())
    self._check_assert(
      Axi4sCheck.SINGLE_OUTSTANDING_PER_TDEST,
      allowed,
      f"Multiple open packets target TDEST 0x{int(tdest):x}")

  def _check_stream_interleave_depth(self):
    if self.cfg is None:
      return
    self._check_assert(
      Axi4sCheck.STREAM_INTERLEAVE_DEPTH_EXCEEDED,
      len(self._open_packets) <= self.cfg.stream_interleave_depth,
      f"Open stream count {len(self._open_packets)} exceeds "
      f"stream_interleave_depth {self.cfg.stream_interleave_depth}")

  def _build_beat_item(self, tdata, tstrb, tkeep, tuser, tid, tdest):
    item = vip_axi4s_item("axi4s_beat", self.cfg_t)
    item.tid = tid
    item.tdest = tdest
    item.tdata = [tdata]
    item.tstrb = [tstrb]
    item.tkeep = [tkeep]
    item.tuser = [tuser]
    item.burst_length = 1
    item.infer_stream_xact_type()
    return item

  def _build_packet_item(self, state):
    item = vip_axi4s_item("axi4s_item", self.cfg_t)
    item.tid = state["tid"]
    item.tdest = state["tdest"]
    item.tdata = list(state["tdata"])
    item.tstrb = list(state["tstrb"])
    item.tkeep = list(state["tkeep"])
    item.tuser = list(state["tuser"])
    item.burst_length = len(item.tdata)
    item.infer_stream_xact_type()
    return item

  def _packet_latency_cycles(self, state):
    start_cycle = int(state.get("start_cycle", self._cycle_count))
    if self._cycle_count < start_cycle:
      return 0
    return self._cycle_count - start_cycle + 1

  def _update_stall_tracking(self):
    if self.vif.get_or("tvalid") == 1 and self.vif.get_or("tready") != 1:
      self._pending_stall_cycles += 1
    elif self.vif.get_or("tvalid") != 1:
      self._pending_stall_cycles = 0

  def _current_tvalid_delay(self):
    return self._tvalid_delay_cycles if self._saw_tvalid else 0

  def _update_tvalid_delay_tracking(self):
    if self.vif.get_or("tvalid") == 1:
      self._saw_tvalid = True
      self._tvalid_delay_cycles = 0
    elif self._saw_tvalid:
      self._tvalid_delay_cycles += 1

  def _sample_beat_coverage(self, tkeep, tstrb, tvalid_delay, stall_cycles):
    if self.cfg is None:
      return
    keep_mask = (1 << int(self.cfg_t.TDATA_BYTES_P)) - 1
    self.cfg.record_coverage_beat(
      int(tkeep), int(tstrb), keep_mask, int(tvalid_delay), int(stall_cycles))

  def _sample_packet_coverage(self, item, stall_cycles, reset_seen):
    if self.cfg is None:
      return
    self.cfg.record_coverage_packet(
      item.burst_length,
      item.stream_xact_type,
      item.tid,
      item.tdest,
      any(int(value) != 0 for value in item.tuser),
      int(stall_cycles))

  def _record_performance_cycle(self):
    if self.cfg is None:
      return
    self.cfg.record_performance_cycle(
      self.vif.get_or("tvalid") == 1,
      self.vif.get_or("tready") == 1)

  def _record_performance_beat(self, tstrb, tkeep, stall_cycles):
    if self.cfg is None:
      return
    data_bytes = (int(tstrb) & int(tkeep)).bit_count()
    self.cfg.record_performance_beat(data_bytes, int(stall_cycles))

  def _record_performance_packet(self, packet_latency):
    if self.cfg is not None:
      self.cfg.record_performance_packet(packet_latency)

  def _do_beat_sampled(self, beat):
    for cb in self.callbacks:
      cb.beat_sampled(self, beat)

  def _do_packet_completed(self, packet):
    for cb in self.callbacks:
      cb.packet_completed(self, packet)

  def _do_checker_violation(self, check, message):
    for cb in self.callbacks:
      cb.checker_violation(self, check, message)

  async def check_reset_protocol(self):
    while True:
      await self.vif.sample_edge()
      if self.vif.get_rst() != 1:
        self._check_assert(
          Axi4sCheck.TVALID_LOW_WHEN_RESET_IS_ACTIVE,
          self.vif.get_or("tvalid") != 1,
          "TVALID must be low while reset is active")

  async def check_protocol(self):
    prev_stalled = False
    prev = {}
    while True:
      await self.vif.sample_edge()
      cur = {name: self.vif.get_or(name) for name in
             ("tvalid", "tready", "tdata", "tstrb", "tkeep", "tlast", "tid", "tdest", "tuser")}
      unknown = {name: self.vif.is_unknown(name) for name in cur}

      self._check_assert(
        Axi4sCheck.SIGNAL_VALID_TVALID,
        not unknown["tvalid"],
        "TVALID contains X/Z")

      if prev_stalled:
        self._check_assert(
          Axi4sCheck.TVALID_INTERRUPTED,
          cur["tvalid"] == 1,
          "TVALID deasserted before a handshake completed")
        if cur["tvalid"] == 1:
          stable_checks = {
            "tdata": Axi4sCheck.SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH,
            "tstrb": Axi4sCheck.SIGNAL_STABLE_TSTRB_WHEN_TVALID_HIGH,
            "tkeep": Axi4sCheck.SIGNAL_STABLE_TKEEP_WHEN_TVALID_HIGH,
            "tlast": Axi4sCheck.SIGNAL_STABLE_TLAST_WHEN_TVALID_HIGH,
            "tid": Axi4sCheck.SIGNAL_STABLE_TID_WHEN_TVALID_HIGH,
            "tdest": Axi4sCheck.SIGNAL_STABLE_TDEST_WHEN_TVALID_HIGH,
            "tuser": Axi4sCheck.SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH,
          }
          for name, check in stable_checks.items():
            self._check_assert(
              check,
              cur[name] == prev[name],
              f"{name.upper()} changed while TVALID was asserted and TREADY was low")

      if cur["tvalid"] == 1:
        valid_checks = {
          "tready": Axi4sCheck.SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH,
          "tdata": Axi4sCheck.SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH,
          "tstrb": Axi4sCheck.SIGNAL_VALID_TSTRB_WHEN_TVALID_HIGH,
          "tkeep": Axi4sCheck.SIGNAL_VALID_TKEEP_WHEN_TVALID_HIGH,
          "tlast": Axi4sCheck.SIGNAL_VALID_TLAST_WHEN_TVALID_HIGH,
          "tid": Axi4sCheck.SIGNAL_VALID_TID_WHEN_TVALID_HIGH,
          "tdest": Axi4sCheck.SIGNAL_VALID_TDEST_WHEN_TVALID_HIGH,
          "tuser": Axi4sCheck.SIGNAL_VALID_TUSER_WHEN_TVALID_HIGH,
        }
        for name, check in valid_checks.items():
          self._check_assert(
            check,
            not unknown[name],
            f"{name.upper()} contains X/Z while TVALID is high")

        if not unknown["tstrb"] and not unknown["tkeep"]:
          self._check_assert(
            Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW,
            (cur["tstrb"] & ~cur["tkeep"]) == 0,
            f"TSTRB has byte lanes set outside TKEEP "
            f"(tstrb=0x{cur['tstrb']:x} tkeep=0x{cur['tkeep']:x})")

        if self.cfg_t.TID_WIDTH_P == 0:
          self._check_assert(
            Axi4sCheck.ZERO_WIDTH_TID_IS_ZERO,
            cur["tid"] == 0,
            "TID must be zero when VIP_AXI4S_TID_WIDTH_P is 0")
        if self.cfg_t.TDEST_WIDTH_P == 0:
          self._check_assert(
            Axi4sCheck.ZERO_WIDTH_TDEST_IS_ZERO,
            cur["tdest"] == 0,
            "TDEST must be zero when VIP_AXI4S_TDEST_WIDTH_P is 0")
        if self.cfg_t.TUSER_WIDTH_P == 0:
          self._check_assert(
            Axi4sCheck.ZERO_WIDTH_TUSER_IS_ZERO,
            cur["tuser"] == 0,
            "TUSER must be zero when VIP_AXI4S_TUSER_WIDTH_P is 0")

      prev_stalled = cur["tvalid"] == 1 and cur["tready"] != 1
      prev = cur

  def _handshake(self):
    return self.vif.get_or("tvalid") == 1 and self.vif.get_or("tready") == 1

  def _check_assert(self, check, condition, message):
    if self.cfg is None:
      return
    if not self.cfg.is_check_enabled(check):
      return
    if self._is_local_driven_check(check):
      self.cfg.record_suppressed_check(check)
      return
    self.cfg.record_check(check)
    if not condition:
      self._report_violation(check, message)

  def _is_local_driven_check(self, check):
    if self.cfg is None or self.cfg.is_active != "UVM_ACTIVE":
      return False
    check = Axi4sCheck(check)
    if self.cfg.vip_axi4s_agent_type == Axi4sAgentType.MASTER:
      return check in {
        Axi4sCheck.SIGNAL_VALID_TVALID,
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
        Axi4sCheck.TVALID_INTERRUPTED,
        Axi4sCheck.TVALID_LOW_WHEN_RESET_IS_ACTIVE,
        Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW,
        Axi4sCheck.ZERO_WIDTH_TID_IS_ZERO,
        Axi4sCheck.ZERO_WIDTH_TDEST_IS_ZERO,
        Axi4sCheck.ZERO_WIDTH_TUSER_IS_ZERO,
        # The stream tracking checks are deliberately not listed here. They
        # test the legality of the stimulus rather than the integrity of a
        # signal the agent drives, so they stay useful as self checks and are
        # the only protocol checking a master-only environment ever gets
      }
    if self.cfg.vip_axi4s_agent_type == Axi4sAgentType.SLAVE:
      return check == Axi4sCheck.SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH
    return False

  def _report_violation(self, check, message):
    self.cfg.record_violation(check)
    full_message = f"[{axi4s_check_name(check)}] {message}"
    self._trace_violation(check, full_message)
    self.violation_port.write(full_message)
    self._do_checker_violation(check, full_message)
    severity = self.cfg.get_check_severity(check)
    if severity == "FATAL":
      self.logger.critical(full_message)
      raise RuntimeError(full_message)
    if severity == "WARNING":
      self.logger.warning(full_message)
    elif severity == "INFO":
      self.logger.info(full_message)
    else:
      self.logger.error(full_message)

  def report_phase(self):
    if self.cfg is not None and self.cfg.has_checker_activity():
      checker_stats = self.cfg.checker_stats_s()
      self.logger.info(checker_stats)
      self.stats_port.write(checker_stats)
    if self.cfg is not None and self.cfg.has_coverage_activity():
      coverage_stats = self.cfg.coverage_summary_s()
      self.logger.info(coverage_stats)
      self.stats_port.write(coverage_stats)
    if self.cfg is not None and self.cfg.has_performance_activity():
      performance_stats = self.cfg.performance_summary_s()
      self.logger.info(performance_stats)
      self.stats_port.write(performance_stats)
    self._close_trace()

  def _trace_enabled(self):
    return self.cfg is not None and bool(self.cfg.trace_enable)

  def _trace_format(self):
    fmt = str(getattr(self.cfg, "trace_format", "jsonl")).lower()
    return "csv" if fmt == "csv" else "jsonl"

  def _trace_path(self):
    fmt = self._trace_format()
    path = getattr(self.cfg, "trace_path", "")
    if path:
      return path
    safe_name = self.get_full_name().replace(".", "_")
    return f"{safe_name}_axi4s_trace.{fmt}"

  def _ensure_trace_open(self):
    if not self._trace_enabled() or self._trace_file is not None:
      return
    path = self._trace_path()
    directory = os.path.dirname(os.path.abspath(path))
    if directory:
      os.makedirs(directory, exist_ok=True)
    self._trace_file = open(path, "w", newline="", encoding="utf-8")
    if self._trace_format() == "csv":
      self._trace_writer = csv.DictWriter(
        self._trace_file, fieldnames=TRACE_COLUMNS, extrasaction="ignore")
      self._trace_writer.writeheader()

  def _trace_event(self, event, **fields):
    if not self._trace_enabled():
      return
    self._ensure_trace_open()
    if self._trace_file is None:
      return
    row = {name: "" for name in TRACE_COLUMNS}
    row.update({
      "event": event,
      "cycle": self._cycle_count,
      "time_ns": get_sim_time("ns"),
    })
    row.update(fields)
    if self._trace_format() == "csv":
      self._trace_writer.writerow(row)
    else:
      self._trace_file.write(json.dumps(row, sort_keys=True) + "\n")
    if self.cfg.trace_flush_enable:
      self._trace_file.flush()

  def _trace_beat(self, beat, tdata, tstrb, tkeep, tuser, tid, tdest, tlast,
                  stall_cycles):
    self._trace_event(
      "beat",
      beat=int(beat),
      tid=f"0x{int(tid):x}",
      tdest=f"0x{int(tdest):x}",
      tdata=f"0x{int(tdata):x}",
      tstrb=f"0x{int(tstrb):x}",
      tkeep=f"0x{int(tkeep):x}",
      tuser=f"0x{int(tuser):x}",
      tlast=int(tlast),
      stall_cycles=int(stall_cycles))

  def _trace_packet(self, item, stall_cycles, latency_cycles, reset_seen):
    self._trace_event(
      "packet_reset" if reset_seen else "packet",
      tid=f"0x{int(item.tid):x}",
      tdest=f"0x{int(item.tdest):x}",
      length=int(item.burst_length),
      stream=str(item.stream_xact_type.name).lower(),
      stall_cycles=int(stall_cycles),
      latency_cycles=int(latency_cycles))

  def _trace_violation(self, check, message):
    self._trace_event(
      "violation",
      check=axi4s_check_name(check),
      message=message)

  def _close_trace(self):
    if self._trace_file is not None:
      self._trace_file.close()
      self._trace_file = None
      self._trace_writer = None


def _cancel_task(task):
  if hasattr(task, "cancel"):
    task.cancel()
  else:
    task.kill()
