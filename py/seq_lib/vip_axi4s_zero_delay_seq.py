from __future__ import annotations

from vip_axi4s_item import vip_axi4s_item
from vip_axi4s_types_pkg import Axi4sTdataType, Axi4sTkeepType, Axi4sTuserType
from seq_lib.vip_axi4s_base_seq import vip_axi4s_base_seq


class vip_axi4s_zero_delay_seq(vip_axi4s_base_seq):

  def __init__(self, name="vip_axi4s_zero_delay_seq", cfg_t=None):
    super().__init__(name, cfg_t)

  async def body(self):
    for i in range(self._nr_of_bursts):
      req = vip_axi4s_item(f"vip_axi4s_zero_delay_item_{i}", self.cfg_t)
      if self._cfg.axi4s_tdata_type == Axi4sTdataType.CUSTOM:
        req.set_tdata(self._tdata)
        self.set_burst_length(len(self._tdata))
      if self._cfg.axi4s_tkeep_type == Axi4sTkeepType.CUSTOM:
        req.set_tkeep(self._tkeep)
        self.set_burst_length(len(self._tkeep))
      if self._cfg.axi4s_tuser_type == Axi4sTuserType.CUSTOM:
        req.set_tuser(self._tuser)
      req.set_config(self._cfg)
      req.randomize()
      req.set_tvalid_delay([0 for _ in range(req.burst_length)])
      req.set_tready_delay([0 for _ in range(req.burst_length)])
      await self.start_item(req)
      await self.finish_item(req)
