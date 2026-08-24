from __future__ import annotations

from axi4s_base_test import axi4s_base_test
from axi4s_scoreboard import compare_items
from seq_lib.vip_axi4s_seq import vip_axi4s_seq
from vip_axi4s_item import vip_axi4s_item
from vip_axi4s_types_pkg import Axi4sTdataType, Axi4sTkeepType, Axi4sTstrbType


class tc_axi4s_sparse_qualifiers(axi4s_base_test):

  async def run_phase(self):
    self.raise_objection()

    seq = vip_axi4s_seq("vip_axi4s_seq0", self.cfg_t)
    seq.set_verbose(False)
    seq.set_tdata_type(Axi4sTdataType.CUSTOM)
    seq.set_tdata([0xAABB_CCDD, 0x1122_3344])
    seq.set_tkeep_type(Axi4sTkeepType.CUSTOM)
    seq.set_tkeep([0xB, 0x7])
    seq.set_tstrb_type(Axi4sTstrbType.ALL)
    await seq.start(self.mst_sequencer)

    assert await self.wait_for_compared(1)
    assert self.env.scoreboard0.number_of_compared == 1
    assert self.env.scoreboard0.number_of_failed == 0

    self._check_scoreboard_compare_modes()
    self.drop_objection()

  def _check_scoreboard_compare_modes(self):
    mst = vip_axi4s_item("mst", self.cfg_t)
    slv = vip_axi4s_item("slv", self.cfg_t)

    mst.tid = slv.tid = 1
    mst.tdest = slv.tdest = 1
    mst.tdata = [0x4433_2211]
    slv.tdata = [0x44BB_AA11]
    mst.tstrb = slv.tstrb = [0x9]
    mst.tkeep = slv.tkeep = [0xB]
    mst.tuser = slv.tuser = [1]

    qualified_equal, _ = compare_items(mst, slv, byte_exact=False)
    exact_equal, _ = compare_items(mst, slv, byte_exact=True)

    assert qualified_equal
    assert not exact_equal
