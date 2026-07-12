################################################################################
# Base pyUVM test for the AXI4-Stream cocotb example.
################################################################################

from __future__ import annotations

from cocotb.triggers import RisingEdge

from pyuvm import ConfigDB, uvm_test

from axi4s_env import axi4s_env
from vip_axi4s_config import vip_axi4s_config
from vip_axi4s_types_pkg import Axi4sAgentType


class axi4s_base_test(uvm_test):

  def __init__(self, name, parent):
    super().__init__(name, parent)
    self.env = None
    self.cfg_t = None
    self.mst_cfg = None
    self.slv_cfg = None

  def build_phase(self):
    self.cfg_t = ConfigDB().get(self, "", "cfg_t")
    self.env = axi4s_env("tb_env", self)

    self.mst_cfg = vip_axi4s_config("axi4s_mst_cfg0")
    self.slv_cfg = vip_axi4s_config("axi4s_slv_cfg0")

    self.mst_cfg.min_tvalid_delay_period = 2
    self.mst_cfg.max_tvalid_delay_period = 10
    self.slv_cfg.min_tready_delay_period = 2
    self.slv_cfg.max_tready_delay_period = 10
    self.slv_cfg.vip_axi4s_agent_type = Axi4sAgentType.SLAVE

    self.configure(self.mst_cfg, self.slv_cfg)

    ConfigDB().set(self, "tb_env.mst_agent0", "cfg", self.mst_cfg)
    ConfigDB().set(self, "tb_env.slv_agent0", "cfg", self.slv_cfg)

  def configure(self, mst_cfg, slv_cfg):
    pass

  @property
  def mst_sequencer(self):
    return self.env.mst_agent0.sequencer

  async def clk_delay(self, n):
    bus = ConfigDB().get(self, "", "vif")
    for _ in range(n):
      await RisingEdge(bus.clk)

  async def wait_for_compared(self, expected, timeout=20000):
    for _ in range(timeout):
      if self.env.scoreboard0.number_of_compared >= expected:
        return True
      await self.clk_delay(1)
    return self.env.scoreboard0.number_of_compared >= expected

  def report_phase(self):
    sb = self.env.scoreboard0
    self.logger.info(
      f"[{self.get_name()}] DONE -- compared={sb.number_of_compared} "
      f"passed={sb.number_of_passed} failed={sb.number_of_failed}")
