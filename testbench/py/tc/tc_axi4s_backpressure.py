from __future__ import annotations

from axi4s_base_test import axi4s_base_test
from seq_lib.vip_axi4s_seq import vip_axi4s_seq
from vip_axi4s_types_pkg import Axi4sTdataType, Axi4sTstrbType


class tc_axi4s_backpressure(axi4s_base_test):

  def configure(self, mst_cfg, slv_cfg):
    mst_cfg.tvalid_delay_gauss_enabled = False
    mst_cfg.min_tvalid_delay_period = 1
    mst_cfg.max_tvalid_delay_period = 3
    mst_cfg.min_tvalid_delay_time = 1
    mst_cfg.max_tvalid_delay_time = 2

    slv_cfg.tready_delay_gauss_enabled = False
    slv_cfg.min_tready_delay_period = 1
    slv_cfg.max_tready_delay_period = 2
    slv_cfg.min_tready_delay_time = 3
    slv_cfg.max_tready_delay_time = 6

  async def run_phase(self):
    self.raise_objection()

    seq = vip_axi4s_seq("vip_axi4s_seq0", self.cfg_t)
    custom_tdata = [0xCA50_0000 + i for i in range(32)]

    seq.set_verbose(False)
    seq.set_tdata_type(Axi4sTdataType.CUSTOM)
    seq.set_tdata(custom_tdata)
    seq.set_tstrb_type(Axi4sTstrbType.RANDOM)
    await seq.start(self.mst_sequencer)

    seq.set_verbose(True)
    seq.set_nr_of_bursts(8)
    seq.set_tdata_type(Axi4sTdataType.COUNTER)
    seq.set_burst_length(9)
    seq.set_tstrb_type(Axi4sTstrbType.RANDOM)
    await seq.start(self.mst_sequencer)

    assert await self.wait_for_compared(9)
    assert self.env.scoreboard0.number_of_compared == 9
    assert self.env.scoreboard0.number_of_failed == 0
    self.drop_objection()
