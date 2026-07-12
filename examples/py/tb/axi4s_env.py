################################################################################
# pyUVM environment for the AXI4-Stream cocotb example.
################################################################################

from __future__ import annotations

from pyuvm import ConfigDB, uvm_env

from vip_axi4s_agent import vip_axi4s_agent
from axi4s_scoreboard import axi4s_scoreboard


class axi4s_env(uvm_env):

  def __init__(self, name, parent):
    super().__init__(name, parent)
    self.mst_agent0 = None
    self.slv_agent0 = None
    self.scoreboard0 = None

  def build_phase(self):
    self.mst_agent0 = vip_axi4s_agent("mst_agent0", self)
    self.slv_agent0 = vip_axi4s_agent("slv_agent0", self)
    self.scoreboard0 = axi4s_scoreboard("scoreboard0", self)

  def connect_phase(self):
    self.mst_agent0.monitor.tdata_port.connect(self.scoreboard0.mst_port)
    self.slv_agent0.monitor.tdata_port.connect(self.scoreboard0.slv_port)

  def handle_reset(self):
    self.scoreboard0.handle_reset()
