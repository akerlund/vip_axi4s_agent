from __future__ import annotations

from axi4s_base_test import axi4s_base_test
from seq_lib.vip_axi4s_zero_delay_seq import vip_axi4s_zero_delay_seq
from vip_axi4s_types_pkg import Axi4sCheck, Axi4sTdataType


class axi4s_neg_base_test(axi4s_base_test):

  def configure(self, mst_cfg, slv_cfg):
    mst_cfg.is_active = "UVM_PASSIVE"
    slv_cfg.is_active = "UVM_PASSIVE"
    for check in Axi4sCheck:
      mst_cfg.set_check_severity(check, "WARNING")
      slv_cfg.set_check_severity(check, "WARNING")

  async def run_phase(self):
    self.raise_objection()
    self.bus = self.env.mst_agent0.vif
    self.park_bus()
    await self.clk_delay(2)
    await self.run_negative_body()
    await self.clk_delay(3)
    self.drop_objection()

  async def run_negative_body(self):
    pass

  def park_bus(self):
    self.bus.drive_opt(
      tvalid=0,
      tready=0,
      tdata=0,
      tstrb=0,
      tkeep=0,
      tlast=0,
      tid=0,
      tdest=0,
      tuser=0)

  async def drive_beat(self, tdata, tstrb, tkeep, tlast, tid, tdest, tuser,
                       tready=1):
    self.bus.drive_opt(
      tvalid=1,
      tready=tready,
      tdata=tdata,
      tstrb=tstrb,
      tkeep=tkeep,
      tlast=tlast,
      tid=tid,
      tdest=tdest,
      tuser=tuser)
    await self.clk_delay(1)

  def total_violations(self, check):
    return (
      self.mst_cfg.get_check_violations(check) +
      self.slv_cfg.get_check_violations(check))

  def expect_violation(self, check):
    assert self.total_violations(check) > 0, (
      f"Expected violation for {check.name}")

  def expect_no_violation(self, check):
    assert self.total_violations(check) == 0, (
      f"Unexpected violation for {check.name}")


class tc_axi4s_neg_xz(axi4s_neg_base_test):

  async def run_negative_body(self):
    original_is_unknown = self.bus.is_unknown
    unknown_names = set()
    self.bus.is_unknown = lambda name: name in unknown_names

    try:
      unknown_names.add("tvalid")
      self.bus.drive_opt(tvalid=0, tready=1)
      await self.clk_delay(1)

      unknown_names.clear()
      unknown_names.update(
        ("tready", "tdata", "tstrb", "tkeep",
         "tlast", "tid", "tdest", "tuser"))
      self.bus.drive_opt(tvalid=1)
      await self.clk_delay(1)
    finally:
      self.bus.is_unknown = original_is_unknown
      self.park_bus()

    for check in (
      Axi4sCheck.SIGNAL_VALID_TVALID,
      Axi4sCheck.SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TSTRB_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TKEEP_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TLAST_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TID_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TDEST_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_VALID_TUSER_WHEN_TVALID_HIGH,
    ):
      self.expect_violation(check)


class tc_axi4s_neg_stability(axi4s_neg_base_test):

  async def run_negative_body(self):
    await self.drive_beat(0x1111_0000, 0xf, 0xf, 0, 1, 1, 1, tready=0)
    self.bus.drive_opt(
      tdata=0x2222_0000,
      tstrb=0xe,
      tkeep=0x7,
      tlast=1,
      tid=2,
      tdest=2,
      tuser=2)
    await self.clk_delay(1)

    self.park_bus()
    for check in (
      Axi4sCheck.SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TSTRB_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TKEEP_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TLAST_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TID_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TDEST_WHEN_TVALID_HIGH,
      Axi4sCheck.SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH,
    ):
      self.expect_violation(check)


class tc_axi4s_neg_tvalid_drop(axi4s_neg_base_test):

  async def run_negative_body(self):
    await self.drive_beat(0x3333_0000, 0xf, 0xf, 0, 3, 3, 3, tready=0)
    self.bus.drive_opt(tvalid=0)
    await self.clk_delay(1)

    self.park_bus()
    self.expect_violation(Axi4sCheck.TVALID_INTERRUPTED)


class tc_axi4s_neg_reset(axi4s_neg_base_test):

  async def run_negative_body(self):
    await self.drive_beat(0x4444_0000, 0xf, 0xf, 0, 4, 4, 4, tready=1)

    self.bus.drive_opt(tvalid=1)
    self.bus.rst_n.value = 0
    await self.clk_delay(1)

    self.park_bus()
    await self.clk_delay(1)
    self.bus.rst_n.value = 1
    await self.clk_delay(2)

    self.expect_violation(Axi4sCheck.TVALID_LOW_WHEN_RESET_IS_ACTIVE)
    self.expect_violation(Axi4sCheck.PACKET_TRUNCATED_BY_RESET)


class tc_axi4s_neg_byte_qualifier(axi4s_neg_base_test):

  async def run_negative_body(self):
    await self.drive_beat(0x5555_0000, 0xf, 0xa, 1, 5, 5, 5, tready=1)
    self.park_bus()
    self.expect_violation(Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW)


class tc_axi4s_neg_packet_boundary(axi4s_neg_base_test):

  async def run_negative_body(self):
    await self.drive_beat(0x6666_0000, 0xf, 0xf, 0, 6, 6, 6, tready=1)
    await self.drive_beat(0x6666_0001, 0xf, 0xf, 1, 7, 7, 6, tready=1)
    self.park_bus()
    self.expect_violation(Axi4sCheck.TID_OR_TDEST_CHANGE_BEFORE_TLAST)


class tc_axi4s_neg_max_length(axi4s_neg_base_test):

  def configure(self, mst_cfg, slv_cfg):
    super().configure(mst_cfg, slv_cfg)
    mst_cfg.max_stream_burst_length = 1
    slv_cfg.max_stream_burst_length = 1

  async def run_negative_body(self):
    await self.drive_beat(0x7777_0000, 0xf, 0xf, 0, 7, 7, 7, tready=1)
    await self.drive_beat(0x7777_0001, 0xf, 0xf, 1, 7, 7, 7, tready=1)
    self.park_bus()
    self.expect_violation(Axi4sCheck.MAX_STREAM_BURST_LENGTH_EXCEEDED)


class tc_axi4s_neg_stream_tracking(axi4s_neg_base_test):

  def configure(self, mst_cfg, slv_cfg):
    super().configure(mst_cfg, slv_cfg)
    mst_cfg.stream_interleave_depth = 1
    slv_cfg.stream_interleave_depth = 1
    mst_cfg.single_outstanding_per_tdest_enable = True
    slv_cfg.single_outstanding_per_tdest_enable = True

  async def run_negative_body(self):
    await self.drive_beat(0x9999_0000, 0xf, 0xf, 0, 1, 3, 0, tready=1)
    await self.drive_beat(0xAAAA_0000, 0xf, 0xf, 0, 2, 3, 0, tready=1)
    await self.drive_beat(0xAAAA_0001, 0xf, 0xf, 1, 2, 3, 0, tready=1)
    await self.drive_beat(0x9999_0001, 0xf, 0xf, 1, 1, 3, 0, tready=1)
    self.park_bus()
    self.expect_violation(Axi4sCheck.STREAM_INTERLEAVE_DEPTH_EXCEEDED)
    self.expect_violation(Axi4sCheck.SINGLE_OUTSTANDING_PER_TDEST)

    # With interleaving not permitted, switching stream mid packet is also a
    # TID/TDEST change before TLAST
    self.expect_violation(Axi4sCheck.TID_OR_TDEST_CHANGE_BEFORE_TLAST)


class tc_axi4s_master_self_check(axi4s_base_test):
  """An active master must still check the legality of its own stimulus.

  Signal integrity checks stay suppressed there, because the agent would only
  be checking its own driver, but the stream tracking checks are the only
  protocol checking a master-only environment ever gets.
  """

  def configure(self, mst_cfg, slv_cfg):
    mst_cfg.zero_delays_enable = True
    slv_cfg.zero_delays_enable = True
    mst_cfg.max_stream_burst_length = 4
    for cfg in (mst_cfg, slv_cfg):
      cfg.set_check_severity(Axi4sCheck.MAX_STREAM_BURST_LENGTH_EXCEEDED, "WARNING")

  async def run_phase(self):
    self.raise_objection()

    seq = vip_axi4s_zero_delay_seq("vip_axi4s_zero_delay_seq0", self.cfg_t)
    seq.set_verbose(False)
    seq.set_tdata_type(Axi4sTdataType.CUSTOM)
    seq.set_tdata([0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17])
    await seq.start(self.mst_sequencer)
    assert await self.wait_for_compared(1)

    # The eight beat packet exceeds the master's max_stream_burst_length of 4
    assert self.mst_cfg.get_check_violations(
      Axi4sCheck.MAX_STREAM_BURST_LENGTH_EXCEEDED) > 0, (
      "The active master did not check its own stimulus length")

    # A signal the master drives itself is still not re-checked by it, and the
    # statistics must show that as suppressed rather than as executed
    valid_tdata = Axi4sCheck.SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH
    assert self.mst_cfg.get_check_suppressed(valid_tdata) > 0
    assert self.mst_cfg.get_check_executed(valid_tdata) == 0

    # The slave agent observes the same signal and does check it
    assert self.slv_cfg.get_check_executed(valid_tdata) > 0

    self.drop_objection()


class tc_axi4s_packet_start_back_to_back(axi4s_neg_base_test):
  """A packet start must be announced even when TVALID never goes low.

  Back-to-back packets have no TVALID rising edge at the packet boundary, so
  the notification cannot be driven from that edge alone.
  """

  async def run_negative_body(self):
    starts = []
    monitor = self.env.mst_agent0.monitor
    monitor.packet_start_cb = lambda item: starts.append(
      (int(item.tid), int(item.tdest)))

    # Two single-beat packets and one two-beat packet, TVALID held high all the
    # way through so that there is no rising edge between them
    await self.drive_beat(0xB000_0000, 0xf, 0xf, 1, 1, 0, 0, tready=1)
    await self.drive_beat(0xB000_0001, 0xf, 0xf, 1, 2, 0, 0, tready=1)
    await self.drive_beat(0xB000_0002, 0xf, 0xf, 0, 3, 0, 0, tready=1)
    await self.drive_beat(0xB000_0003, 0xf, 0xf, 1, 3, 0, 0, tready=1)
    self.park_bus()
    await self.clk_delay(2)

    assert starts == [(1, 0), (2, 0), (3, 0)], (
      f"Expected one packet start per packet, got {starts}")


class tc_axi4s_interleaved_streams(axi4s_neg_base_test):
  """Interleaved observation is legal once stream_interleave_depth allows it."""

  def configure(self, mst_cfg, slv_cfg):
    super().configure(mst_cfg, slv_cfg)
    mst_cfg.stream_interleave_depth = 2
    slv_cfg.stream_interleave_depth = 2

  async def run_negative_body(self):
    starts = []
    monitor = self.env.mst_agent0.monitor
    monitor.packet_start_cb = lambda item: starts.append(
      (int(item.tid), int(item.tdest)))

    await self.drive_beat(0x9999_0000, 0xf, 0xf, 0, 1, 3, 0, tready=1)
    await self.drive_beat(0xAAAA_0000, 0xf, 0xf, 0, 2, 4, 0, tready=1)
    await self.drive_beat(0xAAAA_0001, 0xf, 0xf, 1, 2, 4, 0, tready=1)
    await self.drive_beat(0x9999_0001, 0xf, 0xf, 1, 1, 3, 0, tready=1)
    self.park_bus()
    await self.clk_delay(2)

    assert starts == [(1, 3), (2, 4)], (
      f"Expected one packet start per interleaved stream, got {starts}")
    self.expect_no_violation(Axi4sCheck.TID_OR_TDEST_CHANGE_BEFORE_TLAST)
    self.expect_no_violation(Axi4sCheck.STREAM_INTERLEAVE_DEPTH_EXCEEDED)
    self.expect_no_violation(Axi4sCheck.PACKET_TRUNCATED_BY_RESET)


class tc_axi4s_neg_disable_controls(axi4s_neg_base_test):

  async def run_negative_body(self):
    self.mst_cfg.protocol_checks_enable = False
    self.slv_cfg.protocol_checks_enable = False
    before = self.total_violations(Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW)
    await self.drive_beat(0x8888_0000, 0xf, 0x0, 1, 8, 8, 8, tready=1)
    self.park_bus()
    await self.clk_delay(2)
    assert self.total_violations(Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW) == before

    self.mst_cfg.protocol_checks_enable = True
    self.slv_cfg.protocol_checks_enable = True
    self.mst_cfg.set_check_enable(Axi4sCheck.TVALID_INTERRUPTED, False)
    self.slv_cfg.set_check_enable(Axi4sCheck.TVALID_INTERRUPTED, False)
    before = self.total_violations(Axi4sCheck.TVALID_INTERRUPTED)
    await self.drive_beat(0x8888_0001, 0xf, 0xf, 0, 8, 8, 8, tready=0)
    self.bus.drive_opt(tvalid=0)
    await self.clk_delay(1)
    self.park_bus()
    await self.clk_delay(2)
    assert self.total_violations(Axi4sCheck.TVALID_INTERRUPTED) == before

    self.mst_cfg.set_check_enable(Axi4sCheck.TVALID_INTERRUPTED, True)
    self.slv_cfg.set_check_enable(Axi4sCheck.TVALID_INTERRUPTED, True)
    self.mst_cfg.set_check_severity(Axi4sCheck.TVALID_INTERRUPTED, "INFO")
    self.slv_cfg.set_check_severity(Axi4sCheck.TVALID_INTERRUPTED, "INFO")
    before = self.total_violations(Axi4sCheck.TVALID_INTERRUPTED)
    await self.drive_beat(0x8888_0002, 0xf, 0xf, 0, 8, 8, 8, tready=0)
    self.bus.drive_opt(tvalid=0)
    await self.clk_delay(1)
    self.park_bus()
    await self.clk_delay(2)
    assert self.total_violations(Axi4sCheck.TVALID_INTERRUPTED) > before
