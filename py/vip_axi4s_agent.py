################################################################################
# pyUVM port of vip_axi4s_agent.sv.
################################################################################

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge

from pyuvm import ConfigDB, uvm_agent

from vip_axi4s_config import vip_axi4s_config
from vip_axi4s_driver import vip_axi4s_driver
from vip_axi4s_monitor import vip_axi4s_monitor
from vip_axi4s_sequencer import vip_axi4s_sequencer


class vip_axi4s_agent(uvm_agent):

  def __init__(self, name, parent):
    super().__init__(name, parent)
    self.vif = None
    self.cfg = None
    self.cfg_t = None
    self.monitor = None
    self.driver = None
    self.sequencer = None

  def build_phase(self):
    self.vif = ConfigDB().get(self, "", "vif")
    self.cfg_t = ConfigDB().get(self, "", "cfg_t")
    try:
      self.cfg = ConfigDB().get(self, "", "cfg")
    except Exception:
      self.logger.info("Agent has no config, creating a default config")
      self.cfg = vip_axi4s_config(f"default_config_{self.get_name()}")

    self._publish_to_children()
    self.monitor = vip_axi4s_monitor("monitor", self)
    self.monitor.agent_owned = True

    if self.cfg.is_active == "UVM_ACTIVE":
      self.cfg.rebuild_gauss_cdfs()
      self.driver = vip_axi4s_driver("driver", self)
      self.driver.agent_owned = True
      self.sequencer = vip_axi4s_sequencer("sequencer", self)

  def _publish_to_children(self):
    for key, value in (("vif", self.vif), ("cfg", self.cfg), ("cfg_t", self.cfg_t)):
      ConfigDB().set(self, "*", key, value)

  def connect_phase(self):
    if self.cfg.is_active == "UVM_ACTIVE":
      self.driver.seq_item_port.connect(self.sequencer.seq_item_export)

  async def run_phase(self):
    self._reset_driver_vif()
    while True:
      while self.vif.get_rst() == 0:
        await self.vif.rising()
      tasks = [cocotb.start_soon(self.monitor.monitor_start())]
      if self.driver is not None:
        tasks.append(cocotb.start_soon(self.driver.driver_start()))

      await FallingEdge(self.vif.rst_n)
      self.logger.info("Calling reset handler")
      for task in tasks:
        _cancel_task(task)
      self.handle_reset()
      self._reset_driver_vif()

  def _reset_driver_vif(self):
    if self.driver is not None:
      self.driver.reset_vif()

  def handle_reset(self):
    self.monitor.handle_reset()
    if self.driver is not None:
      self.driver.handle_reset()
    if self.cfg.is_active == "UVM_ACTIVE" and self.sequencer is not None:
      self.sequencer.handle_reset()


def _cancel_task(task):
  if hasattr(task, "cancel"):
    task.cancel()
  else:
    task.kill()
