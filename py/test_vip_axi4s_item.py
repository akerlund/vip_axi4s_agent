from vip_axi4s_item import vip_axi4s_item
from vip_axi4s_item_config import vip_axi4s_item_config
from vip_axi4s_types_pkg import (
  Axi4sCfgT,
  Axi4sTdataType,
  Axi4sTuserType,
  Axi4sTdestType,
  Axi4sTidType,
)


def test_counter_defaults_advance_like_sv():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=4, TID_WIDTH_P=2, TDEST_WIDTH_P=4, TUSER_WIDTH_P=3)
  cfg = vip_axi4s_item_config()
  cfg.min_burst_length = 3
  cfg.max_burst_length = 3
  cfg.axi4s_tuser_type = Axi4sTuserType.COUNTER
  cfg.tdata_counter = 10
  cfg.tid_counter = 2
  cfg.tdest_counter = 8
  cfg.tuser_counter = 5

  item = vip_axi4s_item("item", cfg_t)
  item.set_config(cfg)
  assert item.randomize()

  assert item.tdata == [10, 11, 12]
  assert item.tstrb == [0xF, 0xF, 0xF]
  assert item.tkeep == [0xF, 0xF, 0xF]
  assert item.tid == 2
  assert item.tdest == 8
  assert item.tuser == [5, 6, 7]
  assert cfg.tdata_counter == 13
  assert cfg.tid_counter == 3
  assert cfg.tdest_counter == 20
  assert cfg.tuser_counter == 8


def test_custom_payload_sets_burst_length_and_values():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=2, TUSER_WIDTH_P=4)
  cfg = vip_axi4s_item_config()
  cfg.axi4s_tdata_type = Axi4sTdataType.CUSTOM
  cfg.axi4s_tuser_type = Axi4sTuserType.CUSTOM

  item = vip_axi4s_item("item", cfg_t)
  item.set_config(cfg)
  item.set_tdata([0x1234, 0x5678])
  item.set_tuser([0xA, 0xB])
  assert item.randomize()

  assert item.burst_length == 2
  assert item.tdata == [0x1234, 0x5678]
  assert item.tuser == [0xA, 0xB]


def test_zero_width_optional_fields_are_forced_to_zero():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=1, TID_WIDTH_P=0, TDEST_WIDTH_P=0, TUSER_WIDTH_P=0)
  cfg = vip_axi4s_item_config()
  cfg.axi4s_tid_type = Axi4sTidType.RANDOM
  cfg.axi4s_tdest_type = Axi4sTdestType.CUSTOM
  cfg.axi4s_tuser_type = Axi4sTuserType.ONES
  cfg.min_tid = 1
  cfg.max_tid = 1
  cfg.min_tdest = 1
  cfg.max_tdest = 1

  item = vip_axi4s_item("item", cfg_t)
  item.set_config(cfg)
  assert item.randomize()

  assert item.tid == 0
  assert item.tdest == 0
  assert item.tuser == [0]
