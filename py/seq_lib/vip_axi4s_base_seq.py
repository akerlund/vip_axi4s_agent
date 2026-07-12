################################################################################
# pyUVM port of vip_axi4s_seq_lib.sv.
################################################################################

from __future__ import annotations

from pyuvm import uvm_sequence

from vip_axi4s_item import vip_axi4s_item
from vip_axi4s_item_config import vip_axi4s_item_config
from vip_axi4s_types_pkg import (
  Axi4sCfgT, Axi4sTidType, Axi4sTdataType, Axi4sTuserType, Axi4sTdestType,
  Axi4sTstrbType,
)


class vip_axi4s_base_seq(uvm_sequence):

  def __init__(self, name="vip_axi4s_base_seq", cfg_t: Axi4sCfgT = None):
    super().__init__(name)
    self.cfg_t = cfg_t if cfg_t is not None else Axi4sCfgT()
    self._verbose = True
    self._log_denominator = 100
    self._cfg = vip_axi4s_item_config()
    self._cfg.max_tid = (1 << self.cfg_t.TID_WIDTH_P) - 1 if self.cfg_t.TID_WIDTH_P > 0 else 0
    self._cfg.max_tdest = (1 << self.cfg_t.TDEST_WIDTH_P) - 1 if self.cfg_t.TDEST_WIDTH_P > 0 else 0
    self._cfg.max_burst_length = 256
    self._nr_of_bursts = 1
    self._tdata = []
    self._tuser = []

  def set_verbose(self, verbose):
    self._verbose = bool(verbose)

  def set_log_denominator(self, log_denominator):
    self._log_denominator = int(log_denominator)

  def set_id_type(self, axi4s_tid_type: Axi4sTidType):
    self._cfg.axi4s_tid_type = axi4s_tid_type

  def set_tdata_type(self, axi4s_tdata_type: Axi4sTdataType):
    self._cfg.axi4s_tdata_type = axi4s_tdata_type
    if self._cfg.axi4s_tdata_type == Axi4sTdataType.CUSTOM:
      self._nr_of_bursts = 1

  def set_tdest_type(self, axi4s_tdest_type: Axi4sTdestType):
    self._cfg.axi4s_tdest_type = axi4s_tdest_type

  def set_tuser_type(self, axi4s_tuser_type: Axi4sTuserType):
    self._cfg.axi4s_tuser_type = axi4s_tuser_type

  def set_tdata(self, tdata):
    self._tdata = [int(v) for v in tdata]

  def set_tuser(self, tuser):
    self._tuser = [int(v) for v in tuser]

  def set_tuser_counter(self, counter):
    self._cfg.tuser_counter = int(counter)

  def set_nr_of_bursts(self, nr_of_bursts):
    self._nr_of_bursts = int(nr_of_bursts)

  def set_tdata_counter(self, counter):
    self._cfg.tdata_counter = int(counter)

  def get_tdata_counter(self):
    return self._cfg.tdata_counter

  def set_tid(self, tid):
    self._cfg.min_tid = int(tid)
    self._cfg.max_tid = int(tid)

  def set_tdest(self, tdest):
    self._cfg.min_tdest = int(tdest)
    self._cfg.max_tdest = int(tdest)

  def set_burst_length(self, burst_length):
    self._cfg.min_burst_length = int(burst_length)
    self._cfg.max_burst_length = int(burst_length)

  def set_tstrb_type(self, axi4s_tstrb_type: Axi4sTstrbType):
    self._cfg.axi4s_tstrb_type = axi4s_tstrb_type

  def set_cfg_tid(self, max_tid, min_tid):
    self._cfg.min_tid = int(min_tid)
    self._cfg.max_tid = int(max_tid)

  def set_cfg_tdest(self, max_tdest, min_tdest):
    self._cfg.min_tdest = int(min_tdest)
    self._cfg.max_tdest = int(max_tdest)

  def set_cfg_burst_length(self, max_burst_length, min_burst_length):
    self._cfg.min_burst_length = int(min_burst_length)
    self._cfg.max_burst_length = int(max_burst_length)

  async def body(self):
    for i in range(self._nr_of_bursts):
      req = vip_axi4s_item(f"vip_axi4s_item_{i}", self.cfg_t)
      if self._cfg.axi4s_tdata_type == Axi4sTdataType.CUSTOM:
        req.set_tdata(self._tdata)
        self.set_burst_length(len(self._tdata))
      if self._cfg.axi4s_tuser_type == Axi4sTuserType.CUSTOM:
        req.set_tuser(self._tuser)
      req.set_config(self._cfg)
      req.randomize()
      await self.start_item(req)
      await self.finish_item(req)
