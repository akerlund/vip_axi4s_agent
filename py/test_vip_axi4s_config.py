import pytest

from vip_axi4s_config import vip_axi4s_config


def test_rebuild_gauss_cdfs_builds_requested_generators():
  cfg = vip_axi4s_config()
  cfg.rebuild_gauss_cdfs()

  assert cfg.g_tvalid_time is not None
  assert cfg.g_tvalid_period is not None
  assert cfg.g_tready_time is not None
  assert cfg.g_tready_period is not None


def test_delay_ranges_are_validated():
  cfg = vip_axi4s_config()
  cfg.min_tvalid_delay_time = 5
  cfg.max_tvalid_delay_time = 4

  with pytest.raises(ValueError):
    cfg.rebuild_gauss_cdfs()


def test_uniform_delay_is_inclusive():
  cfg = vip_axi4s_config()
  values = {cfg.get_delay(True, False, None, 2, 2) for _ in range(8)}

  assert values == {2}
