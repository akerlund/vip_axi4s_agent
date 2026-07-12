################################################################################
# pyUVM port of vip_axi4s_item_config.sv.
################################################################################

from __future__ import annotations

from vip_axi4s_types_pkg import (
  Axi4sTidType, Axi4sTdataType, Axi4sTuserType, Axi4sTdestType,
  Axi4sTstrbType,
)


class vip_axi4s_item_config:

  def __init__(self, name="vip_axi4s_item_config"):
    self.name = name
    self.axi4s_tdata_type = Axi4sTdataType.COUNTER
    self.axi4s_tstrb_type = Axi4sTstrbType.ALL
    self.axi4s_tid_type = Axi4sTidType.COUNTER
    self.axi4s_tdest_type = Axi4sTdestType.INCR
    self.axi4s_tuser_type = Axi4sTuserType.ZEROS
    self.tdata_counter = 0
    self.tid_counter = 0
    self.tdest_counter = 0
    self.tuser_counter = 0
    self.min_tid = 0
    self.max_tid = 0
    self.min_tdest = 0
    self.max_tdest = 0
    self.min_burst_length = 1
    self.max_burst_length = 1
