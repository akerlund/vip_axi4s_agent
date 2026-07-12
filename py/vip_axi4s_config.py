################################################################################
# pyUVM port of vip_axi4s_config.sv.
################################################################################

from __future__ import annotations

import random

try:
  from vip_gauss import vip_gauss
except Exception:
  vip_gauss = None

from vip_axi4s_types_pkg import Axi4sAgentType


class _UniformGaussFallback:
  def __init__(self, name="gauss"):
    self.name = name
    self.mn = 0
    self.mx = 0

  def gen_cdf(self, mn, mx, mean, stddev):
    self.mn = mn
    self.mx = mx

  def get_r_cdf_int(self):
    return random.randint(self.mn, self.mx)


def _new_gauss(name):
  return vip_gauss(name) if vip_gauss is not None else _UniformGaussFallback(name)


class vip_axi4s_config:

  def __init__(self, name="vip_axi4s_config"):
    self.name = name
    self.is_active = "UVM_ACTIVE"
    self.vip_axi4s_agent_type = Axi4sAgentType.MASTER

    self.tvalid_delay_enabled = True
    self.tvalid_delay_gauss_enabled = True
    self.min_tvalid_delay_time = 1
    self.max_tvalid_delay_time = 10
    self.tvalid_delay_time_mean = 4
    self.tvalid_delay_time_stddev = 2.0
    self.min_tvalid_delay_period = 10
    self.max_tvalid_delay_period = 256
    self.tvalid_delay_period_mean = 64
    self.tvalid_delay_period_stddev = 32.0
    self.g_tvalid_time = None
    self.g_tvalid_period = None

    self.tready_delay_enabled = True
    self.tready_delay_gauss_enabled = True
    self.min_tready_delay_time = 1
    self.max_tready_delay_time = 10
    self.tready_delay_time_mean = 4
    self.tready_delay_time_stddev = 2.0
    self.min_tready_delay_period = 10
    self.max_tready_delay_period = 256
    self.tready_delay_period_mean = 64
    self.tready_delay_period_stddev = 32.0
    self.g_tready_time = None
    self.g_tready_period = None

  def validate_range(self, name, mn, mx):
    if mn < 0:
      raise ValueError(f"[{self.name}] {name} min ({mn}) must be non-negative")
    if mx < mn:
      raise ValueError(f"[{self.name}] {name} max ({mx}) must be >= min ({mn})")

  def _build_gauss(self, attr, name, mn, mx, mean, stddev):
    self.validate_range(name, mn, mx)
    g = getattr(self, attr)
    if g is None:
      g = _new_gauss(name)
      setattr(self, attr, g)
    g.gen_cdf(mn, mx, mean, stddev)

  def rebuild_gauss_cdfs(self):
    self.validate_range("tvalid_delay_time",
                        self.min_tvalid_delay_time, self.max_tvalid_delay_time)
    self.validate_range("tvalid_delay_period",
                        self.min_tvalid_delay_period, self.max_tvalid_delay_period)
    self.validate_range("tready_delay_time",
                        self.min_tready_delay_time, self.max_tready_delay_time)
    self.validate_range("tready_delay_period",
                        self.min_tready_delay_period, self.max_tready_delay_period)

    if self.tvalid_delay_gauss_enabled:
      self._build_gauss(
        "g_tvalid_time", "g_tvalid_time",
        self.min_tvalid_delay_time, self.max_tvalid_delay_time,
        self.tvalid_delay_time_mean, self.tvalid_delay_time_stddev)
      self._build_gauss(
        "g_tvalid_period", "g_tvalid_period",
        self.min_tvalid_delay_period, self.max_tvalid_delay_period,
        self.tvalid_delay_period_mean, self.tvalid_delay_period_stddev)

    if self.tready_delay_gauss_enabled:
      self._build_gauss(
        "g_tready_time", "g_tready_time",
        self.min_tready_delay_time, self.max_tready_delay_time,
        self.tready_delay_time_mean, self.tready_delay_time_stddev)
      self._build_gauss(
        "g_tready_period", "g_tready_period",
        self.min_tready_delay_period, self.max_tready_delay_period,
        self.tready_delay_period_mean, self.tready_delay_period_stddev)

  def get_delay(self, delay_enabled, gauss_enabled, gauss, mn, mx):
    self.validate_range("delay", mn, mx)
    if not delay_enabled:
      return 0
    if gauss_enabled:
      if gauss is None:
        raise RuntimeError(f"[{self.name}] Gaussian delay requested before CDF was built")
      return gauss.get_r_cdf_int()
    return random.randint(mn, mx)
