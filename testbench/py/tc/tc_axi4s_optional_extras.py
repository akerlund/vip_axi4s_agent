from __future__ import annotations

import json
import os

from axi4s_base_test import axi4s_base_test
from seq_lib.vip_axi4s_seq import vip_axi4s_seq
from vip_axi4s_types_pkg import (
  Axi4sTdataType, Axi4sTstrbType, Axi4sTuserType,
)


class tc_axi4s_optional_extras(axi4s_base_test):

  def configure(self, mst_cfg, slv_cfg):
    self._mst_trace = os.path.abspath("axi4s_optional_mst.jsonl")
    self._slv_trace = os.path.abspath("axi4s_optional_slv.jsonl")
    for path in (self._mst_trace, self._slv_trace):
      try:
        os.remove(path)
      except FileNotFoundError:
        pass

    for cfg, path in ((mst_cfg, self._mst_trace), (slv_cfg, self._slv_trace)):
      cfg.zero_delays_enable = True
      cfg.trace_enable = True
      cfg.trace_format = "jsonl"
      cfg.trace_path = path
      cfg.performance_enable = True

    mst_cfg.drive_idle_values_enable = True
    mst_cfg.idle_tdata = 0xDEAD_BEEF
    mst_cfg.idle_tstrb = 0
    mst_cfg.idle_tkeep = 0
    mst_cfg.idle_tlast = 0
    mst_cfg.idle_tid = 0
    mst_cfg.idle_tdest = 0
    mst_cfg.idle_tuser = 0
    mst_cfg.tlast_idle_toggle_enable = True
    mst_cfg.tdata_only_fast_path_enable = True
    slv_cfg.tready_idle_toggle_enable = True

  async def run_phase(self):
    self.raise_objection()

    seq = vip_axi4s_seq("vip_axi4s_seq0", self.cfg_t)
    seq.set_verbose(False)
    seq.set_tdata_type(Axi4sTdataType.CUSTOM)
    seq.set_tdata([0x1000_0000, 0x1000_0001, 0x1000_0002])
    seq.set_tstrb_type(Axi4sTstrbType.ALL)
    seq.set_tuser_type(Axi4sTuserType.CUSTOM)
    seq.set_tuser([0, 0, 0])
    seq.set_tvalid_delay([0, 0, 0])
    await seq.start(self.mst_sequencer)

    assert await self.wait_for_compared(1)
    assert self.env.scoreboard0.number_of_failed == 0
    assert self.mst_cfg.get_performance_beats() >= 3
    assert self.slv_cfg.get_performance_packets() >= 1
    assert self.mst_cfg.get_performance_data_bytes() >= 12
    self._check_trace(self._mst_trace)
    self._check_trace(self._slv_trace)

    self.drop_objection()

  def _check_trace(self, path):
    with open(path, encoding="utf-8") as file:
      events = [json.loads(line)["event"] for line in file if line.strip()]
    assert "beat" in events
    assert "packet" in events
