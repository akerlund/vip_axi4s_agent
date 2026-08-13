import os
import sys

import pytest

from vip_axi4s_item import vip_axi4s_item
from vip_axi4s_item_config import vip_axi4s_item_config
from vip_axi4s_types_pkg import (
  Axi4sCfgT,
  Axi4sTdataType,
  Axi4sStreamXactType,
  Axi4sTkeepType,
  Axi4sTstrbType,
  Axi4sTuserType,
  Axi4sTdestType,
  Axi4sTidType,
  Axi4sTvalidDelayRef,
)

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_TB_PY = os.path.join(_ROOT, "testbench", "py", "tb")
if _TB_PY not in sys.path:
  sys.path.insert(0, _TB_PY)

from axi4s_scoreboard import compare_items  # noqa: E402


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
  assert item.stream_xact_type == Axi4sStreamXactType.CONTINUOUS_ALIGNED_STREAM
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


def test_custom_tkeep_sets_burst_length_and_tstrb_all_tracks_kept_bytes():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=4)
  cfg = vip_axi4s_item_config()
  cfg.axi4s_tdata_type = Axi4sTdataType.CUSTOM
  cfg.axi4s_tkeep_type = Axi4sTkeepType.CUSTOM
  cfg.axi4s_tstrb_type = Axi4sTstrbType.ALL

  item = vip_axi4s_item("item", cfg_t)
  item.set_config(cfg)
  item.set_tdata([0xAABB_CCDD, 0x1122_3344])
  item.set_tkeep([0xB, 0x7])
  assert item.randomize()

  assert item.burst_length == 2
  assert item.tkeep == [0xB, 0x7]
  assert item.tstrb == item.tkeep
  assert item.stream_xact_type == Axi4sStreamXactType.USER_STREAM


def test_custom_tdata_and_tkeep_lengths_must_match():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=4)
  cfg = vip_axi4s_item_config()
  cfg.axi4s_tdata_type = Axi4sTdataType.CUSTOM
  cfg.axi4s_tkeep_type = Axi4sTkeepType.CUSTOM

  item = vip_axi4s_item("item", cfg_t)
  item.set_config(cfg)
  item.set_tdata([0x1, 0x2])
  item.set_tkeep([0xF])

  try:
    item.randomize()
  except ValueError as err:
    assert "tkeep has size 1 but tdata has size 2" in str(err)
  else:
    assert False, "Expected mismatched custom TDATA/TKEEP lengths to fail"


def test_sparse_tkeep_random_tstrb_is_legal_subset():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=4)
  cfg = vip_axi4s_item_config()
  cfg.min_burst_length = 8
  cfg.max_burst_length = 8
  cfg.axi4s_tkeep_type = Axi4sTkeepType.SPARSE
  cfg.axi4s_tstrb_type = Axi4sTstrbType.RANDOM

  for _ in range(50):
    item = vip_axi4s_item("item", cfg_t)
    item.set_config(cfg)
    assert item.randomize()
    for keep, strb in zip(item.tkeep, item.tstrb):
      assert keep != 0
      assert keep != 0xF
      assert strb != 0
      assert (strb & ~keep) == 0
    assert item.stream_xact_type in (
      Axi4sStreamXactType.BYTE_STREAM,
      Axi4sStreamXactType.SPARSE_STREAM,
      Axi4sStreamXactType.CONTINUOUS_UNALIGNED_STREAM,
    )


def _stream_type_for(tkeep, tstrb):
  item = vip_axi4s_item("item", Axi4sCfgT(TDATA_BYTES_P=4))
  item.tkeep = list(tkeep)
  item.tstrb = list(tstrb)
  item.tdata = [0] * len(tkeep)
  item.tuser = [0] * len(tkeep)
  item.burst_length = len(tkeep)
  item.infer_stream_xact_type()
  return item.stream_xact_type


def test_position_bytes_make_a_sparse_stream():
  # TKEEP high with TSTRB low is a position byte, which is what the AXI4-Stream
  # spec calls a sparse stream
  assert _stream_type_for([0xF, 0xF], [0xB, 0x7]) == Axi4sStreamXactType.SPARSE_STREAM


def test_null_bytes_make_a_continuous_unaligned_stream():
  # TKEEP low is a null byte, so the data bytes are not aligned to the full bus
  assert (_stream_type_for([0x7, 0xE], [0x7, 0xE]) ==
          Axi4sStreamXactType.CONTINUOUS_UNALIGNED_STREAM)


def test_position_bytes_win_over_null_bytes():
  assert _stream_type_for([0x7, 0xE], [0x3, 0xE]) == Axi4sStreamXactType.SPARSE_STREAM


def test_all_qualified_is_a_continuous_aligned_stream():
  assert (_stream_type_for([0xF, 0xF], [0xF, 0xF]) ==
          Axi4sStreamXactType.CONTINUOUS_ALIGNED_STREAM)


def test_random_tkeep_tstrb_modes_are_legal():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=4)
  for tkeep_type in (Axi4sTkeepType.ALL, Axi4sTkeepType.RANDOM, Axi4sTkeepType.SPARSE):
    for tstrb_type in (Axi4sTstrbType.ALL, Axi4sTstrbType.RANDOM):
      cfg = vip_axi4s_item_config()
      cfg.min_burst_length = 4
      cfg.max_burst_length = 4
      cfg.axi4s_tkeep_type = tkeep_type
      cfg.axi4s_tstrb_type = tstrb_type
      item = vip_axi4s_item("item", cfg_t)
      item.set_config(cfg)
      assert item.randomize()
      for keep, strb in zip(item.tkeep, item.tstrb):
        assert keep != 0
        assert (strb & ~keep) == 0
        if tstrb_type == Axi4sTstrbType.ALL:
          assert strb == keep
        else:
          assert strb != 0


def test_tdest_random_and_custom_are_distinct_modes():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=1, TDEST_WIDTH_P=3)

  random_cfg = vip_axi4s_item_config()
  random_cfg.axi4s_tdest_type = Axi4sTdestType.RANDOM
  random_cfg.min_tdest = 2
  random_cfg.max_tdest = 2
  random_item = vip_axi4s_item("random_item", cfg_t)
  random_item.set_config(random_cfg)
  assert random_item.randomize()
  assert random_item.tdest == 2

  custom_cfg = vip_axi4s_item_config()
  custom_cfg.axi4s_tdest_type = Axi4sTdestType.CUSTOM
  custom_cfg.custom_tdest = 5
  custom_item = vip_axi4s_item("custom_item", cfg_t)
  custom_item.set_config(custom_cfg)
  assert custom_item.randomize()
  assert custom_item.tdest == 5


def test_per_beat_delay_arrays_set_burst_length_and_reference_event():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=1)
  cfg = vip_axi4s_item_config()
  cfg.min_burst_length = 1
  cfg.max_burst_length = 8
  cfg.reference_event_for_tvalid_delay = (
    Axi4sTvalidDelayRef.PREV_TVALID_TREADY_HANDSHAKE)

  item = vip_axi4s_item("item", cfg_t)
  item.set_config(cfg)
  item.set_tvalid_delay([0, 2, 0])
  item.set_tready_delay([0, 3, 0])
  assert item.randomize()

  assert item.burst_length == 3
  assert item.tvalid_delay == [0, 2, 0]
  assert item.tready_delay == [0, 3, 0]
  assert item.reference_event_for_tvalid_delay == (
    Axi4sTvalidDelayRef.PREV_TVALID_TREADY_HANDSHAKE)


def test_delay_array_size_must_match_fixed_burst_length():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=1)
  cfg = vip_axi4s_item_config()
  cfg.min_burst_length = 2
  cfg.max_burst_length = 2

  item = vip_axi4s_item("item", cfg_t)
  item.set_config(cfg)
  item.set_tvalid_delay([0, 1, 0])

  with pytest.raises(ValueError, match="tvalid_delay has size 3"):
    item.randomize()


def test_qualified_scoreboard_ignores_null_and_position_byte_data():
  cfg_t = Axi4sCfgT(TDATA_BYTES_P=4, TID_WIDTH_P=2, TDEST_WIDTH_P=2, TUSER_WIDTH_P=1)
  mst = vip_axi4s_item("mst", cfg_t)
  slv = vip_axi4s_item("slv", cfg_t)

  mst.tid = slv.tid = 1
  mst.tdest = slv.tdest = 2
  mst.tdata = [0x4433_2211]
  slv.tdata = [0x44BB_AA11]
  mst.tkeep = slv.tkeep = [0xB]
  mst.tstrb = slv.tstrb = [0x9]
  mst.tuser = slv.tuser = [1]

  qualified_equal, _ = compare_items(mst, slv, byte_exact=False)
  exact_equal, _ = compare_items(mst, slv, byte_exact=True)

  assert qualified_equal
  assert not exact_equal
