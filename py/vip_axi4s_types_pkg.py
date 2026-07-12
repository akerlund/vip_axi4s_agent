################################################################################
#
# Copyright (C) 2026 Fredrik Akerlund
# https://github.com/akerlund/VIP
#
# See the SystemVerilog originals for the full MIT notice.
#
################################################################################
#
# pyUVM port of vip_axi4s_types_pkg.sv.
#
################################################################################

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum


class Axi4sAgentType(IntEnum):
  MASTER = 0
  SLAVE = 1


class Axi4sTidType(IntEnum):
  COUNTER = 0
  RANDOM = 1


class Axi4sTdataType(IntEnum):
  COUNTER = 0
  RANDOM = 1
  ZEROS = 2
  ONES = 3
  CUSTOM = 4


class Axi4sTuserType(IntEnum):
  COUNTER = 0
  RANDOM = 1
  ZEROS = 2
  ONES = 3
  CUSTOM = 4


class Axi4sTdestType(IntEnum):
  INCR = 0
  CUSTOM = 1


class Axi4sTstrbType(IntEnum):
  ALL = 0
  RANDOM = 1


@dataclass
class Axi4sCfgT:
  TDATA_BYTES_P: int = 0
  TID_WIDTH_P: int = 0
  TDEST_WIDTH_P: int = 0
  TUSER_WIDTH_P: int = 0

  @property
  def VIP_AXI4S_TDATA_BYTES_P(self):
    return self.TDATA_BYTES_P

  @property
  def VIP_AXI4S_TID_WIDTH_P(self):
    return self.TID_WIDTH_P

  @property
  def VIP_AXI4S_TDEST_WIDTH_P(self):
    return self.TDEST_WIDTH_P

  @property
  def VIP_AXI4S_TUSER_WIDTH_P(self):
    return self.TUSER_WIDTH_P


@dataclass(frozen=True)
class Axi4sWidths:
  tdata_w: int
  tstrb_w: int
  tkeep_w: int
  tid_w: int
  tdest_w: int
  tuser_w: int

  def __init__(self, cfg_t: Axi4sCfgT):
    object.__setattr__(self, "tdata_w", 8 * int(cfg_t.TDATA_BYTES_P))
    object.__setattr__(self, "tstrb_w", int(cfg_t.TDATA_BYTES_P))
    object.__setattr__(self, "tkeep_w", int(cfg_t.TDATA_BYTES_P))
    object.__setattr__(self, "tid_w", max(int(cfg_t.TID_WIDTH_P), 1))
    object.__setattr__(self, "tdest_w", max(int(cfg_t.TDEST_WIDTH_P), 1))
    object.__setattr__(self, "tuser_w", max(int(cfg_t.TUSER_WIDTH_P), 1))


def mask(width: int) -> int:
  return 0 if width <= 0 else (1 << width) - 1


VIP_AXI4S_MASTER_AGENT_E = Axi4sAgentType.MASTER
VIP_AXI4S_SLAVE_AGENT_E = Axi4sAgentType.SLAVE

VIP_AXI4S_TID_COUNTER_E = Axi4sTidType.COUNTER
VIP_AXI4S_TID_RANDOM_E = Axi4sTidType.RANDOM

VIP_AXI4S_TDATA_COUNTER_E = Axi4sTdataType.COUNTER
VIP_AXI4S_TDATA_RANDOM_E = Axi4sTdataType.RANDOM
VIP_AXI4S_TDATA_ZEROS_E = Axi4sTdataType.ZEROS
VIP_AXI4S_TDATA_ONES_E = Axi4sTdataType.ONES
VIP_AXI4S_TDATA_CUSTOM_E = Axi4sTdataType.CUSTOM

VIP_AXI4S_TUSER_COUNTER_E = Axi4sTuserType.COUNTER
VIP_AXI4S_TUSER_RANDOM_E = Axi4sTuserType.RANDOM
VIP_AXI4S_TUSER_ZEROS_E = Axi4sTuserType.ZEROS
VIP_AXI4S_TUSER_ONES_E = Axi4sTuserType.ONES
VIP_AXI4S_TUSER_CUSTOM_E = Axi4sTuserType.CUSTOM

VIP_AXI4S_TDEST_INCR_E = Axi4sTdestType.INCR
VIP_AXI4S_TDEST_CUSTOM_E = Axi4sTdestType.CUSTOM

VIP_AXI4S_TSTRB_ALL_E = Axi4sTstrbType.ALL
VIP_AXI4S_TSTRB_RANDOM_E = Axi4sTstrbType.RANDOM
