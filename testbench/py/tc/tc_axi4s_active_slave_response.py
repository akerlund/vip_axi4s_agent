from __future__ import annotations

import cocotb

from axi4s_base_test import axi4s_base_test
from seq_lib.vip_axi4s_slave_response_seq import vip_axi4s_slave_response_seq
from seq_lib.vip_axi4s_zero_delay_seq import vip_axi4s_zero_delay_seq
from vip_axi4s_types_pkg import Axi4sTdataType


class _TargetedSecondBeatStallSeq(vip_axi4s_slave_response_seq):

  def __init__(self, name="_TargetedSecondBeatStallSeq"):
    super().__init__(name)
    self.seen_tid = None
    self.seen_tdest = None
    self.set_max_responses(1)

  def configure_response(self, rsp):
    self.seen_tid = int(rsp.tid)
    self.seen_tdest = int(rsp.tdest)
    rsp.set_tready_delay([0, 3, 0])


class tc_axi4s_active_slave_response(axi4s_base_test):

  def configure(self, mst_cfg, slv_cfg):
    mst_cfg.zero_delays_enable = True
    slv_cfg.zero_delays_enable = True

  async def run_phase(self):
    self.raise_objection()

    response_seq = _TargetedSecondBeatStallSeq()
    response_task = cocotb.start_soon(response_seq.start(self.slv_sequencer))
    stall_watch = cocotb.start_soon(self._count_second_beat_stalls())

    seq = vip_axi4s_zero_delay_seq("vip_axi4s_zero_delay_seq0", self.cfg_t)
    seq.set_verbose(False)
    seq.set_tdata_type(Axi4sTdataType.CUSTOM)
    seq.set_tdata([0, 1, 2])
    await seq.start(self.mst_sequencer)

    assert await self.wait_for_compared(1)
    stalls = await stall_watch
    await response_task

    assert response_seq.seen_tid == 0
    assert response_seq.seen_tdest == 0
    assert stalls >= 3
    assert self.env.scoreboard0.number_of_failed == 0

    self.drop_objection()

  async def _count_second_beat_stalls(self, cycles=20):
    bus = self.env.mst_agent0.vif
    stalls = 0
    for _ in range(cycles):
      await bus.sample_edge()
      if (bus.get_or("tvalid") == 1 and
          bus.get_or("tready") == 0 and
          bus.get_or("tdata") == 1):
        stalls += 1
    return stalls
