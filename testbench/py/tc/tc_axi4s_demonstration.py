from __future__ import annotations

from axi4s_base_test import axi4s_base_test
from seq_lib.vip_axi4s_seq import vip_axi4s_seq
from vip_axi4s_types_pkg import Axi4sTdataType, Axi4sTstrbType


class tc_axi4s_demonstration(axi4s_base_test):

  async def run_phase(self):
    self.raise_objection()

    seq = vip_axi4s_seq("vip_axi4s_seq0", self.cfg_t)
    seq.set_nr_of_bursts(4)

    seq.set_tdata_type(Axi4sTdataType.COUNTER)
    seq.set_burst_length(16)
    seq.set_tstrb_type(Axi4sTstrbType.ALL)
    await seq.start(self.mst_sequencer)

    seq.set_tdata_type(Axi4sTdataType.COUNTER)
    seq.set_burst_length(8)
    seq.set_tstrb_type(Axi4sTstrbType.ALL)
    await seq.start(self.mst_sequencer)

    seq.set_tdata_type(Axi4sTdataType.COUNTER)
    seq.set_burst_length(4)
    seq.set_tstrb_type(Axi4sTstrbType.ALL)
    await seq.start(self.mst_sequencer)

    assert await self.wait_for_compared(12)
    assert self.env.scoreboard0.number_of_compared == 12
    assert self.env.scoreboard0.number_of_failed == 0
    self.drop_objection()
