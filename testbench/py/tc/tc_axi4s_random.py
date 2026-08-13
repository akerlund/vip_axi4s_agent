################################################################################
# Long randomized AXI4-Stream run.
#
# Randomizes the agent configuration, the timing controls and the payload
# shapes, then streams packets for several thousand clock periods. Everything
# the VIP drives is legal traffic, so the run must finish without a single
# protocol violation, and every packet the driver sent must be observed by the
# monitor exactly as it was driven.
################################################################################

from __future__ import annotations

import csv
import json
import os
import random

from cocotb.utils import get_sim_time

from axi4s_base_test import axi4s_base_test
from seq_lib.vip_axi4s_seq import vip_axi4s_seq
from vip_axi4s_callbacks import vip_axi4s_driver_callback, vip_axi4s_monitor_callback
from vip_axi4s_types_pkg import (
  Axi4sCheck,
  Axi4sTdataType,
  Axi4sTdestType,
  Axi4sTidType,
  Axi4sTkeepType,
  Axi4sTstrbType,
  Axi4sTuserType,
  Axi4sTvalidDelayRef,
  axi4s_check_name,
)

CLOCK_PERIOD_NS = 10


def _packet_key(item):
  return (
    int(item.tid),
    int(item.tdest),
    [int(v) for v in item.tdata],
    [int(v) for v in item.tstrb],
    [int(v) for v in item.tkeep],
    [int(v) for v in item.tuser],
  )


class _DrivenRecorder(vip_axi4s_driver_callback):

  def __init__(self):
    self.packets = []

  def post_packet(self, driver, item):
    self.packets.append(_packet_key(item))


class _ObservedRecorder(vip_axi4s_monitor_callback):

  def __init__(self):
    self.packets = []
    self.violations = []

  def packet_completed(self, monitor, packet):
    self.packets.append(_packet_key(packet))

  def checker_violation(self, monitor, check, message):
    self.violations.append(message)


class tc_axi4s_random(axi4s_base_test):
  """Randomized soak test, reproducible through AXI4S_RANDOM_SEED."""

  MIN_CYCLES = 4000

  def configure(self, mst_cfg, slv_cfg):
    seed = os.environ.get("AXI4S_RANDOM_SEED")
    self.seed = int(seed) if seed else random.randrange(1 << 30)

    # The item constraints draw from the module level generator, so seeding it
    # here is what makes a failing run reproducible
    random.seed(self.seed)
    self.rng = random.Random(self.seed)
    rng = self.rng

    self.trace_path = None

    for cfg in (mst_cfg, slv_cfg):
      cfg.protocol_checks_enable = True
      cfg.per_clock_checks_enable = True
      cfg.coverage_enable = True
      cfg.performance_enable = True

      # The master sends one packet at a time, so the strictest stream tracking
      # settings must hold for the whole run
      cfg.max_stream_burst_length = 64
      cfg.stream_interleave_depth = 1
      cfg.single_outstanding_per_tdest_enable = True

    self._randomize_delays(mst_cfg, "tvalid")
    self._randomize_delays(slv_cfg, "tready")
    mst_cfg.zero_delays_enable = rng.random() < 0.25
    slv_cfg.zero_delays_enable = rng.random() < 0.25

    # Idle bus behaviour: these are what make the driver park the bus on other
    # values between beats, so TID/TDEST must survive them
    mst_cfg.drive_idle_values_enable = rng.random() < 0.5
    if mst_cfg.drive_idle_values_enable:
      keep = rng.randrange(1 << self.cfg_t.TDATA_BYTES_P)
      mst_cfg.idle_tdata = rng.randrange(1 << (8 * self.cfg_t.TDATA_BYTES_P))
      mst_cfg.idle_tkeep = keep
      mst_cfg.idle_tstrb = keep & rng.randrange(1 << self.cfg_t.TDATA_BYTES_P)
      mst_cfg.idle_tlast = rng.randrange(2)
      mst_cfg.idle_tid = rng.randrange(1 << max(self.cfg_t.TID_WIDTH_P, 1))
      mst_cfg.idle_tdest = rng.randrange(1 << max(self.cfg_t.TDEST_WIDTH_P, 1))
      mst_cfg.idle_tuser = rng.randrange(1 << max(self.cfg_t.TUSER_WIDTH_P, 1))

    mst_cfg.tlast_idle_toggle_enable = rng.random() < 0.5
    mst_cfg.tdata_only_fast_path_enable = rng.random() < 0.5
    slv_cfg.tready_idle_toggle_enable = rng.random() < 0.5

    if rng.random() < 0.5:
      mst_cfg.trace_enable = True
      mst_cfg.trace_format = rng.choice(["jsonl", "csv"])
      self.trace_path = f"axi4s_random_mst.{mst_cfg.trace_format}"
      mst_cfg.trace_path = self.trace_path

  def _randomize_delays(self, cfg, kind):
    rng = self.rng
    enabled = rng.random() < 0.8
    gauss = rng.random() < 0.5

    min_time = rng.randint(0, 3)
    max_time = min_time + rng.randint(0, 6)
    min_period = rng.randint(1, 8)
    max_period = min_period + rng.randint(0, 24)

    setattr(cfg, f"{kind}_delay_enabled", enabled)
    setattr(cfg, f"{kind}_delay_gauss_enabled", gauss)
    setattr(cfg, f"min_{kind}_delay_time", min_time)
    setattr(cfg, f"max_{kind}_delay_time", max_time)
    setattr(cfg, f"{kind}_delay_time_mean", (min_time + max_time) // 2)
    setattr(cfg, f"{kind}_delay_time_stddev", max(1.0, (max_time - min_time) / 2.0))
    setattr(cfg, f"min_{kind}_delay_period", min_period)
    setattr(cfg, f"max_{kind}_delay_period", max_period)
    setattr(cfg, f"{kind}_delay_period_mean", (min_period + max_period) // 2)
    setattr(cfg, f"{kind}_delay_period_stddev",
            max(1.0, (max_period - min_period) / 2.0))

  async def run_phase(self):
    self.raise_objection()
    self.logger.info(f"[{self.get_name()}] Random seed value: {self.seed}")

    driven = _DrivenRecorder()
    observed = _ObservedRecorder()
    self.env.mst_agent0.driver.add_callback(driven)
    self.env.mst_agent0.monitor.add_callback(observed)

    start_ns = get_sim_time("ns")
    groups = 0
    while self._elapsed_cycles(start_ns) < self.MIN_CYCLES:
      await self._run_random_group(groups)
      groups += 1

    packets = len(driven.packets)
    assert await self.wait_for_compared(packets), (
      f"Only {self.env.scoreboard0.number_of_compared} of {packets} packets compared")

    cycles = self._elapsed_cycles(start_ns)
    self.logger.info(
      f"[{self.get_name()}] seed={self.seed} groups={groups} packets={packets} "
      f"cycles={cycles}")

    assert cycles >= self.MIN_CYCLES
    assert packets > 0
    assert self.env.scoreboard0.number_of_failed == 0

    # Every packet must reach the monitor exactly as the driver sent it. This
    # is what catches payload or TID/TDEST corruption from the idle values
    assert observed.packets == driven.packets, (
      self._first_difference(driven.packets, observed.packets))

    # The VIP only drives legal traffic, so nothing may be reported
    assert not observed.violations, (
      f"Unexpected protocol violations: {observed.violations[:5]}")
    self._assert_no_violations()

    if self.trace_path is not None:
      self._check_trace_file()

    self.drop_objection()

  def _elapsed_cycles(self, start_ns):
    return int((get_sim_time("ns") - start_ns) // CLOCK_PERIOD_NS)

  async def _run_random_group(self, index):
    rng = self.rng
    seq = vip_axi4s_seq(f"vip_axi4s_random_seq{index}", self.cfg_t)
    seq.set_verbose(False)
    seq.set_nr_of_bursts(rng.randint(1, 6))
    seq.set_cfg_burst_length(rng.randint(8, 24), rng.randint(1, 4))

    seq.set_tdata_type(rng.choice([
      Axi4sTdataType.COUNTER, Axi4sTdataType.RANDOM,
      Axi4sTdataType.ZEROS, Axi4sTdataType.ONES]))
    seq.set_tuser_type(rng.choice([
      Axi4sTuserType.COUNTER, Axi4sTuserType.RANDOM,
      Axi4sTuserType.ZEROS, Axi4sTuserType.ONES]))
    seq.set_tkeep_type(rng.choice([
      Axi4sTkeepType.ALL, Axi4sTkeepType.RANDOM, Axi4sTkeepType.SPARSE]))
    seq.set_tstrb_type(rng.choice([Axi4sTstrbType.ALL, Axi4sTstrbType.RANDOM]))
    seq.set_id_type(rng.choice([Axi4sTidType.COUNTER, Axi4sTidType.RANDOM]))
    seq.set_tdest_type(rng.choice([
      Axi4sTdestType.INCR, Axi4sTdestType.RANDOM, Axi4sTdestType.CUSTOM]))
    seq.set_reference_event_for_tvalid_delay(rng.choice([
      Axi4sTvalidDelayRef.PREV_TVALID,
      Axi4sTvalidDelayRef.PREV_TVALID_TREADY_HANDSHAKE]))

    await seq.start(self.mst_sequencer)

  def _assert_no_violations(self):
    for check in Axi4sCheck:
      total = (self.mst_cfg.get_check_violations(check) +
               self.slv_cfg.get_check_violations(check))
      assert total == 0, (
        f"seed={self.seed}: {total} violations of {axi4s_check_name(check)}")

  def _first_difference(self, driven, seen):
    head = (f"seed={self.seed}: driver sent {len(driven)} packets, "
            f"monitor saw {len(seen)}")
    for index, (a, b) in enumerate(zip(driven, seen)):
      if a != b:
        return (f"{head}; first difference at packet {index}\n"
                f"  driven  tid=0x{a[0]:x} tdest=0x{a[1]:x} len={len(a[2])} "
                f"tdata={[hex(v) for v in a[2]]}\n"
                f"  observed tid=0x{b[0]:x} tdest=0x{b[1]:x} len={len(b[2])} "
                f"tdata={[hex(v) for v in b[2]]}")
    return f"{head}; the shorter list is a prefix of the longer one"

  def _check_trace_file(self):
    # The trace must stay machine readable even though checker messages and
    # enum names end up inside CSV columns and JSON strings
    assert os.path.exists(self.trace_path), f"Missing trace file {self.trace_path}"

    with open(self.trace_path, newline="") as handle:
      if self.trace_path.endswith(".csv"):
        rows = list(csv.reader(handle))
        header = rows[0]
        for row in rows[1:]:
          assert len(row) == len(header), (
            f"Trace row has {len(row)} fields, expected {len(header)}: {row}")
        assert len(rows) > 1
      else:
        lines = [line for line in handle if line.strip()]
        for line in lines:
          json.loads(line)
        assert lines
