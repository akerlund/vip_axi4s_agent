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
  RANDOM = 1
  CUSTOM = 2


class Axi4sTstrbType(IntEnum):
  ALL = 0
  RANDOM = 1


class Axi4sTkeepType(IntEnum):
  ALL = 0
  RANDOM = 1
  CUSTOM = 2
  SPARSE = 3


class Axi4sStreamXactType(IntEnum):
  BYTE_STREAM = 0
  CONTINUOUS_ALIGNED_STREAM = 1
  CONTINUOUS_UNALIGNED_STREAM = 2
  SPARSE_STREAM = 3
  USER_STREAM = 4


class Axi4sTvalidDelayRef(IntEnum):
  PREV_TVALID = 0
  PREV_TVALID_TREADY_HANDSHAKE = 1


class Axi4sCheck(IntEnum):
  SIGNAL_VALID_TVALID = 0
  SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH = 1
  SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH = 2
  SIGNAL_VALID_TSTRB_WHEN_TVALID_HIGH = 3
  SIGNAL_VALID_TKEEP_WHEN_TVALID_HIGH = 4
  SIGNAL_VALID_TLAST_WHEN_TVALID_HIGH = 5
  SIGNAL_VALID_TID_WHEN_TVALID_HIGH = 6
  SIGNAL_VALID_TDEST_WHEN_TVALID_HIGH = 7
  SIGNAL_VALID_TUSER_WHEN_TVALID_HIGH = 8
  SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH = 9
  SIGNAL_STABLE_TSTRB_WHEN_TVALID_HIGH = 10
  SIGNAL_STABLE_TKEEP_WHEN_TVALID_HIGH = 11
  SIGNAL_STABLE_TLAST_WHEN_TVALID_HIGH = 12
  SIGNAL_STABLE_TID_WHEN_TVALID_HIGH = 13
  SIGNAL_STABLE_TDEST_WHEN_TVALID_HIGH = 14
  SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH = 15
  TVALID_INTERRUPTED = 16
  TVALID_LOW_WHEN_RESET_IS_ACTIVE = 17
  TSTRB_LOW_WHEN_TKEEP_LOW = 18
  TID_OR_TDEST_CHANGE_BEFORE_TLAST = 19
  MAX_STREAM_BURST_LENGTH_EXCEEDED = 20
  PACKET_TRUNCATED_BY_RESET = 21
  STREAM_INTERLEAVE_DEPTH_EXCEEDED = 22
  SINGLE_OUTSTANDING_PER_TDEST = 23
  ZERO_WIDTH_TID_IS_ZERO = 24
  ZERO_WIDTH_TDEST_IS_ZERO = 25
  ZERO_WIDTH_TUSER_IS_ZERO = 26


def axi4s_check_name(check: Axi4sCheck) -> str:
  names = {
    Axi4sCheck.SIGNAL_VALID_TVALID: "signal_valid_tvalid",
    Axi4sCheck.SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH: "signal_valid_tready_when_tvalid_high",
    Axi4sCheck.SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH: "signal_valid_tdata_when_tvalid_high",
    Axi4sCheck.SIGNAL_VALID_TSTRB_WHEN_TVALID_HIGH: "signal_valid_tstrb_when_tvalid_high",
    Axi4sCheck.SIGNAL_VALID_TKEEP_WHEN_TVALID_HIGH: "signal_valid_tkeep_when_tvalid_high",
    Axi4sCheck.SIGNAL_VALID_TLAST_WHEN_TVALID_HIGH: "signal_valid_tlast_when_tvalid_high",
    Axi4sCheck.SIGNAL_VALID_TID_WHEN_TVALID_HIGH: "signal_valid_tid_when_tvalid_high",
    Axi4sCheck.SIGNAL_VALID_TDEST_WHEN_TVALID_HIGH: "signal_valid_tdest_when_tvalid_high",
    Axi4sCheck.SIGNAL_VALID_TUSER_WHEN_TVALID_HIGH: "signal_valid_tuser_when_tvalid_high",
    Axi4sCheck.SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH: "signal_stable_tdata_when_tvalid_high",
    Axi4sCheck.SIGNAL_STABLE_TSTRB_WHEN_TVALID_HIGH: "signal_stable_tstrb_when_tvalid_high",
    Axi4sCheck.SIGNAL_STABLE_TKEEP_WHEN_TVALID_HIGH: "signal_stable_tkeep_when_tvalid_high",
    Axi4sCheck.SIGNAL_STABLE_TLAST_WHEN_TVALID_HIGH: "signal_stable_tlast_when_tvalid_high",
    Axi4sCheck.SIGNAL_STABLE_TID_WHEN_TVALID_HIGH: "signal_stable_tid_when_tvalid_high",
    Axi4sCheck.SIGNAL_STABLE_TDEST_WHEN_TVALID_HIGH: "signal_stable_tdest_when_tvalid_high",
    Axi4sCheck.SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH: "signal_stable_tuser_when_tvalid_high",
    Axi4sCheck.TVALID_INTERRUPTED: "tvalid_interrupted",
    Axi4sCheck.TVALID_LOW_WHEN_RESET_IS_ACTIVE: "tvalid_low_when_reset_is_active",
    Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW: "tstrb_low_when_tkeep_low",
    Axi4sCheck.TID_OR_TDEST_CHANGE_BEFORE_TLAST: "tid_or_tdest_change_before_tlast",
    Axi4sCheck.MAX_STREAM_BURST_LENGTH_EXCEEDED: "max_stream_burst_length_exceeded",
    Axi4sCheck.PACKET_TRUNCATED_BY_RESET: "packet_truncated_by_reset",
    Axi4sCheck.STREAM_INTERLEAVE_DEPTH_EXCEEDED: "stream_interleave_depth_exceeded",
    Axi4sCheck.SINGLE_OUTSTANDING_PER_TDEST: "single_outstanding_per_tdest",
    Axi4sCheck.ZERO_WIDTH_TID_IS_ZERO: "zero_width_tid_is_zero",
    Axi4sCheck.ZERO_WIDTH_TDEST_IS_ZERO: "zero_width_tdest_is_zero",
    Axi4sCheck.ZERO_WIDTH_TUSER_IS_ZERO: "zero_width_tuser_is_zero",
  }
  return names.get(check, "unknown_axi4s_check")


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
VIP_AXI4S_TDEST_RANDOM_E = Axi4sTdestType.RANDOM
VIP_AXI4S_TDEST_CUSTOM_E = Axi4sTdestType.CUSTOM

VIP_AXI4S_TSTRB_ALL_E = Axi4sTstrbType.ALL
VIP_AXI4S_TSTRB_RANDOM_E = Axi4sTstrbType.RANDOM

VIP_AXI4S_TKEEP_ALL_E = Axi4sTkeepType.ALL
VIP_AXI4S_TKEEP_RANDOM_E = Axi4sTkeepType.RANDOM
VIP_AXI4S_TKEEP_CUSTOM_E = Axi4sTkeepType.CUSTOM
VIP_AXI4S_TKEEP_SPARSE_E = Axi4sTkeepType.SPARSE

VIP_AXI4S_BYTE_STREAM_E = Axi4sStreamXactType.BYTE_STREAM
VIP_AXI4S_CONTINUOUS_ALIGNED_STREAM_E = Axi4sStreamXactType.CONTINUOUS_ALIGNED_STREAM
VIP_AXI4S_CONTINUOUS_UNALIGNED_STREAM_E = Axi4sStreamXactType.CONTINUOUS_UNALIGNED_STREAM
VIP_AXI4S_SPARSE_STREAM_E = Axi4sStreamXactType.SPARSE_STREAM
VIP_AXI4S_USER_STREAM_E = Axi4sStreamXactType.USER_STREAM

VIP_AXI4S_TVALID_DELAY_PREV_TVALID_E = Axi4sTvalidDelayRef.PREV_TVALID
VIP_AXI4S_TVALID_DELAY_PREV_TVALID_TREADY_HANDSHAKE_E = (
  Axi4sTvalidDelayRef.PREV_TVALID_TREADY_HANDSHAKE)
