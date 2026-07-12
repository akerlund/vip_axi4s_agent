################################################################################
# pyUVM port of vip_axi4s_monitor.sv.
################################################################################

from __future__ import annotations

import cocotb
from cocotb.triggers import Combine, FallingEdge

from pyuvm import ConfigDB, uvm_analysis_port, uvm_monitor

from vip_axi4s_item import vip_axi4s_item


class vip_axi4s_monitor(uvm_monitor):

  def __init__(self, name, parent):
    super().__init__(name, parent)
    self.tdata_port = uvm_analysis_port("tdata_port", self)
    self.vif = None
    self.cfg_t = None
    self._monitor_tasks = []
    self.agent_owned = False
    self.handle_reset()

  def build_phase(self):
    self.vif = ConfigDB().get(self, "", "vif")
    self.cfg_t = ConfigDB().get(self, "", "cfg_t")

  async def run_phase(self):
    if self.agent_owned:
      return
    while True:
      while self.vif.get_rst() == 0:
        await self.vif.rising()
      task = cocotb.start_soon(self.monitor_start())
      await FallingEdge(self.vif.rst_n)
      _cancel_task(task)
      self.handle_reset()

  async def monitor_start(self):
    self._monitor_tasks = [
      cocotb.start_soon(self.collect_transfers()),
      cocotb.start_soon(self.check_protocol()),
    ]
    await Combine(*self._monitor_tasks)

  def handle_reset(self):
    for task in getattr(self, "_monitor_tasks", []):
      try:
        if not task.done():
          _cancel_task(task)
      except Exception:
        pass
    self._monitor_tasks = []
    self._tdata_beats = []
    self._tstrb_beats = []
    self._tkeep_beats = []
    self._tuser_beats = []

  async def collect_transfers(self):
    while True:
      await self.vif.sample_edge()
      if self._handshake():
        self._tdata_beats.append(self.vif.get_or("tdata"))
        self._tstrb_beats.append(self.vif.get_or("tstrb"))
        self._tkeep_beats.append(self.vif.get_or("tkeep"))
        self._tuser_beats.append(self.vif.get_or("tuser"))

      if self._handshake() and self.vif.get_or("tlast") == 1:
        item = vip_axi4s_item("axi4s_item", self.cfg_t)
        item.tid = self.vif.get_or("tid")
        item.tdest = self.vif.get_or("tdest")
        item.tdata = list(self._tdata_beats)
        item.tstrb = list(self._tstrb_beats)
        item.tkeep = list(self._tkeep_beats)
        item.tuser = list(self._tuser_beats)
        item.burst_length = len(item.tdata)
        self._tdata_beats.clear()
        self._tstrb_beats.clear()
        self._tkeep_beats.clear()
        self._tuser_beats.clear()
        self.tdata_port.write(item)

  async def check_protocol(self):
    prev_stalled = False
    prev = {}
    while True:
      await self.vif.sample_edge()
      cur = {name: self.vif.get_or(name) for name in
             ("tvalid", "tready", "tdata", "tstrb", "tkeep", "tlast", "tid", "tdest", "tuser")}

      if prev_stalled:
        if cur["tvalid"] != 1:
          self.logger.error("TVALID deasserted before a handshake completed")
        else:
          for name in ("tdata", "tstrb", "tkeep", "tlast", "tid", "tdest", "tuser"):
            if cur[name] != prev[name]:
              self.logger.error(f"{name.upper()} changed while TVALID was asserted and TREADY was low")

      if cur["tvalid"] == 1:
        if self.cfg_t.TID_WIDTH_P == 0 and cur["tid"] != 0:
          self.logger.error("TID must be zero when VIP_AXI4S_TID_WIDTH_P is 0")
        if self.cfg_t.TDEST_WIDTH_P == 0 and cur["tdest"] != 0:
          self.logger.error("TDEST must be zero when VIP_AXI4S_TDEST_WIDTH_P is 0")
        if self.cfg_t.TUSER_WIDTH_P == 0 and cur["tuser"] != 0:
          self.logger.error("TUSER must be zero when VIP_AXI4S_TUSER_WIDTH_P is 0")

      prev_stalled = cur["tvalid"] == 1 and cur["tready"] != 1
      prev = cur

  def _handshake(self):
    return self.vif.get_or("tvalid") == 1 and self.vif.get_or("tready") == 1


def _cancel_task(task):
  if hasattr(task, "cancel"):
    task.cancel()
  else:
    task.kill()
