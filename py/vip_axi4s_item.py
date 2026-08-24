################################################################################
# pyUVM port of vip_axi4s_item.sv.
################################################################################

from __future__ import annotations

import copy
import random

from pyuvm import uvm_sequence_item

from vip_axi4s_item_config import vip_axi4s_item_config
from vip_axi4s_types_pkg import (
  Axi4sCfgT, Axi4sWidths, Axi4sTidType, Axi4sTdataType, Axi4sTuserType,
  Axi4sTdestType, Axi4sTstrbType, Axi4sTkeepType, Axi4sStreamXactType,
  Axi4sTvalidDelayRef, mask,
)


class vip_axi4s_item(uvm_sequence_item):

  def __init__(self, name="vip_axi4s_item", cfg_t: Axi4sCfgT = None):
    super().__init__(name)
    self.name = name
    self.cfg_t = cfg_t if cfg_t is not None else Axi4sCfgT()
    self.widths = Axi4sWidths(self.cfg_t)
    self.TDATA_WIDTH_C = self.widths.tdata_w
    self.TSTRB_WIDTH_C = self.widths.tstrb_w
    self.TKEEP_WIDTH_C = self.widths.tkeep_w
    self.TID_WIDTH_C = self.widths.tid_w
    self.TDEST_WIDTH_C = self.widths.tdest_w
    self.TUSER_WIDTH_C = self.widths.tuser_w

    self.tdata = []
    self.tstrb = []
    self.tkeep = []
    self.tid = 0
    self.tdest = 0
    self.tuser = []
    self.burst_length = 0
    self.tvalid_delay = []
    self.tready_delay = []
    self.stream_xact_type = Axi4sStreamXactType.CONTINUOUS_ALIGNED_STREAM
    self.reference_event_for_tvalid_delay = Axi4sTvalidDelayRef.PREV_TVALID

    self._cfg = vip_axi4s_item_config()
    self._tdata = []
    self._tkeep = []
    self._tuser = []
    self._tvalid_delay = []
    self._tready_delay = []

  def set_config(self, cfg):
    self._cfg = cfg

  def set_tdata_counter(self, tdata_counter):
    self._cfg.tdata_counter = int(tdata_counter)

  def set_tuser_counter(self, tuser_counter):
    self._cfg.tuser_counter = int(tuser_counter)

  def set_tdata(self, tdata):
    self._tdata = [int(v) for v in tdata]

  def set_tkeep(self, tkeep):
    self._tkeep = [int(v) for v in tkeep]

  def set_tvalid_delay(self, tvalid_delay):
    self._tvalid_delay = [int(v) for v in tvalid_delay]
    self.tvalid_delay = list(self._tvalid_delay)

  def set_tready_delay(self, tready_delay):
    self._tready_delay = [int(v) for v in tready_delay]
    self.tready_delay = list(self._tready_delay)

  def set_tuser(self, tuser):
    self._tuser = [int(v) for v in tuser]

  def pre_randomize(self):
    cfg = self._cfg
    if cfg.min_burst_length < 1:
      raise ValueError(f"[{self.name}] min_burst_length ({cfg.min_burst_length}) must be at least 1")
    if cfg.max_burst_length < cfg.min_burst_length:
      raise ValueError(
        f"[{self.name}] max_burst_length ({cfg.max_burst_length}) must be >= "
        f"min_burst_length ({cfg.min_burst_length})")
    if cfg.axi4s_tdata_type == Axi4sTdataType.CUSTOM:
      if len(self._tdata) == 0:
        raise ValueError(f"[{self.name}] tdata has size 0")
      cfg.min_burst_length = len(self._tdata)
      cfg.max_burst_length = len(self._tdata)
    if cfg.axi4s_tkeep_type == Axi4sTkeepType.CUSTOM:
      if len(self._tkeep) == 0:
        raise ValueError(f"[{self.name}] tkeep has size 0")
      for i, value in enumerate(self._tkeep):
        if value == 0:
          raise ValueError(f"[{self.name}] tkeep[{i}] must not be zero")
      if cfg.axi4s_tdata_type == Axi4sTdataType.CUSTOM and len(self._tkeep) != len(self._tdata):
        raise ValueError(
          f"[{self.name}] tkeep has size {len(self._tkeep)} but tdata has size "
          f"{len(self._tdata)}")
      cfg.min_burst_length = len(self._tkeep)
      cfg.max_burst_length = len(self._tkeep)
    if cfg.axi4s_tuser_type == Axi4sTuserType.CUSTOM:
      if len(self._tuser) == 0:
        raise ValueError(f"[{self.name}] tuser has size 0")
      if len(self._tuser) < cfg.max_burst_length:
        raise ValueError(
          f"[{self.name}] tuser has size {len(self._tuser)} but max burst length is "
          f"{cfg.max_burst_length}")
    if len(self._tvalid_delay) != 0:
      self._constrain_burst_length_from_array_size("tvalid_delay", len(self._tvalid_delay))
    if len(self._tready_delay) != 0:
      self._constrain_burst_length_from_array_size("tready_delay", len(self._tready_delay))

  def _constrain_burst_length_from_array_size(self, name, size):
    if size == 0:
      raise ValueError(f"[{self.name}] {name} has size 0")
    cfg = self._cfg
    if cfg.min_burst_length == cfg.max_burst_length and cfg.min_burst_length != size:
      raise ValueError(
        f"[{self.name}] {name} has size {size} but burst length is constrained "
        f"to {cfg.min_burst_length}")
    cfg.min_burst_length = size
    cfg.max_burst_length = size

  def randomize(self):
    self.pre_randomize()
    cfg = self._cfg
    self.burst_length = random.randint(cfg.min_burst_length, cfg.max_burst_length)
    self.reference_event_for_tvalid_delay = cfg.reference_event_for_tvalid_delay
    self.tvalid_delay = list(self._tvalid_delay)
    self.tready_delay = list(self._tready_delay)

    data_m = mask(self.TDATA_WIDTH_C)
    strb_m = mask(self.TSTRB_WIDTH_C)
    keep_m = mask(self.TKEEP_WIDTH_C)
    tid_m = mask(self.cfg_t.TID_WIDTH_P)
    tdest_m = mask(self.cfg_t.TDEST_WIDTH_P)
    tuser_m = mask(self.TUSER_WIDTH_C)

    self.tdata = []
    for i in range(self.burst_length):
      if cfg.axi4s_tdata_type == Axi4sTdataType.COUNTER:
        value = cfg.tdata_counter + i
      elif cfg.axi4s_tdata_type == Axi4sTdataType.CUSTOM:
        value = self._tdata[i]
      elif cfg.axi4s_tdata_type == Axi4sTdataType.ZEROS:
        value = 0
      elif cfg.axi4s_tdata_type == Axi4sTdataType.ONES:
        value = data_m
      else:
        value = random.randint(0, data_m)
      self.tdata.append(value & data_m)

    self.tkeep = []
    if cfg.axi4s_tkeep_type == Axi4sTkeepType.ALL:
      self.tkeep = [keep_m for _ in range(self.burst_length)]
    elif cfg.axi4s_tkeep_type == Axi4sTkeepType.CUSTOM:
      self.tkeep = [self._tkeep[i] & keep_m for i in range(self.burst_length)]
    elif cfg.axi4s_tkeep_type == Axi4sTkeepType.SPARSE:
      if keep_m <= 1:
        self.tkeep = [keep_m for _ in range(self.burst_length)]
      else:
        self.tkeep = [_rand_nonzero_not_all(keep_m) for _ in range(self.burst_length)]
    else:
      lo = 1 if keep_m > 0 else 0
      self.tkeep = [random.randint(lo, keep_m) for _ in range(self.burst_length)]

    if cfg.axi4s_tstrb_type == Axi4sTstrbType.ALL:
      self.tstrb = [keep & strb_m for keep in self.tkeep]
    else:
      self.tstrb = [_rand_nonzero_subset(keep & strb_m) for keep in self.tkeep]

    if self.cfg_t.TID_WIDTH_P == 0:
      self.tid = 0
    elif cfg.axi4s_tid_type == Axi4sTidType.COUNTER:
      self.tid = cfg.tid_counter & tid_m
    else:
      self.tid = random.randint(cfg.min_tid, cfg.max_tid) & tid_m

    if self.cfg_t.TDEST_WIDTH_P == 0:
      self.tdest = 0
    elif cfg.axi4s_tdest_type == Axi4sTdestType.INCR:
      self.tdest = cfg.tdest_counter & tdest_m
    elif cfg.axi4s_tdest_type == Axi4sTdestType.RANDOM:
      self.tdest = random.randint(cfg.min_tdest, cfg.max_tdest) & tdest_m
    else:
      self.tdest = cfg.custom_tdest & tdest_m

    self.tuser = []
    for i in range(self.burst_length):
      if self.cfg_t.TUSER_WIDTH_P == 0:
        value = 0
      elif cfg.axi4s_tuser_type == Axi4sTuserType.COUNTER:
        value = cfg.tuser_counter + i
      elif cfg.axi4s_tuser_type == Axi4sTuserType.CUSTOM:
        value = self._tuser[i]
      elif cfg.axi4s_tuser_type == Axi4sTuserType.ZEROS:
        value = 0
      elif cfg.axi4s_tuser_type == Axi4sTuserType.ONES:
        value = tuser_m
      else:
        value = random.randint(0, tuser_m)
      self.tuser.append(value & tuser_m)

    self.post_randomize()
    return True

  def post_randomize(self):
    cfg = self._cfg
    if cfg.axi4s_tdata_type == Axi4sTdataType.COUNTER:
      cfg.tdata_counter += self.burst_length
    if cfg.axi4s_tid_type == Axi4sTidType.COUNTER:
      cfg.tid_counter += 1
    if cfg.axi4s_tdest_type == Axi4sTdestType.INCR:
      cfg.tdest_counter += self.burst_length * self.cfg_t.TDATA_BYTES_P
    if cfg.axi4s_tuser_type == Axi4sTuserType.COUNTER:
      cfg.tuser_counter += self.burst_length
    self.infer_stream_xact_type()

  def infer_stream_xact_type(self):
    has_null_byte = any(keep != mask(self.TKEEP_WIDTH_C) for keep in self.tkeep)
    has_position_byte = any((strb & keep) != keep for strb, keep in zip(self.tstrb, self.tkeep))
    has_all_data_bytes = all(
      keep == mask(self.TKEEP_WIDTH_C) and strb == mask(self.TSTRB_WIDTH_C)
      for strb, keep in zip(self.tstrb, self.tkeep))
    has_one_data_byte_per_beat = all(
      ((strb & keep).bit_count() == 1)
      for strb, keep in zip(self.tstrb, self.tkeep))

    if self._cfg is not None and self._cfg.axi4s_tkeep_type == Axi4sTkeepType.CUSTOM:
      self.stream_xact_type = Axi4sStreamXactType.USER_STREAM
    elif has_one_data_byte_per_beat:
      self.stream_xact_type = Axi4sStreamXactType.BYTE_STREAM
    elif has_all_data_bytes:
      self.stream_xact_type = Axi4sStreamXactType.CONTINUOUS_ALIGNED_STREAM
    elif has_position_byte:
      # A position byte (TKEEP high, TSTRB low) is what makes a stream sparse,
      # and it takes precedence when null bytes are present as well
      self.stream_xact_type = Axi4sStreamXactType.SPARSE_STREAM
    elif has_null_byte:
      # Only null bytes (TKEEP low): the data bytes are not aligned to the
      # full data bus width
      self.stream_xact_type = Axi4sStreamXactType.CONTINUOUS_UNALIGNED_STREAM
    else:
      self.stream_xact_type = Axi4sStreamXactType.USER_STREAM

  def clone(self):
    return copy.deepcopy(self)


def _rand_nonzero_subset(value):
  if value == 0:
    return 0
  subset = 0
  while subset == 0:
    subset = random.randint(1, value) & value
  return subset


def _rand_nonzero_not_all(mask_value):
  value = mask_value
  while value == 0 or value == mask_value:
    value = random.randint(1, mask_value)
  return value
