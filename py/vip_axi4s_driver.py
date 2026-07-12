################################################################################
# pyUVM port of vip_axi4s_driver.sv.
################################################################################

from __future__ import annotations

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge

from pyuvm import ConfigDB, uvm_driver

from vip_axi4s_types_pkg import Axi4sAgentType


class vip_axi4s_driver(uvm_driver):

  def __init__(self, name, parent):
    super().__init__(name, parent)
    self.vif = None
    self.cfg = None
    self.cfg_t = None
    self._driver_tasks = []
    self.agent_owned = False

  def build_phase(self):
    self.vif = ConfigDB().get(self, "", "vif")
    self.cfg = ConfigDB().get(self, "", "cfg")
    self.cfg_t = ConfigDB().get(self, "", "cfg_t")

  async def run_phase(self):
    if self.agent_owned:
      return
    while True:
      while self.vif.get_rst() == 0:
        await RisingEdge(self.vif.clk)
      task = cocotb.start_soon(self.driver_start())
      await FallingEdge(self.vif.rst_n)
      _cancel_task(task)
      self.handle_reset()
      self.reset_vif()

  async def driver_start(self):
    if self.cfg.vip_axi4s_agent_type == Axi4sAgentType.MASTER:
      await self.master_drive()
    else:
      await self.slave_drive()

  def reset_vif(self):
    if self.cfg.vip_axi4s_agent_type == Axi4sAgentType.MASTER:
      self.vif.reset_master()
    else:
      self.vif.reset_slave()

  async def master_drive(self):
    while True:
      req = await self.seq_item_port.get_next_item()
      try:
        await self.drive_axi4s_item(req)
      finally:
        self.seq_item_port.item_done()

  async def drive_axi4s_item(self, req):
    beat_counter = 0
    burst_length = len(req.tdata)

    self.vif.drive_opt(tlast=0, tid=req.tid, tdest=req.tdest)
    tvalid_task = None
    if self.cfg.tvalid_delay_enabled:
      tvalid_task = cocotb.start_soon(self.drive_tvalid())
      self._driver_tasks.append(tvalid_task)
    else:
      self.vif.drive_opt(tvalid=1)

    try:
      while beat_counter != burst_length:
        self.vif.drive_opt(
          tdata=req.tdata[beat_counter],
          tstrb=req.tstrb[beat_counter],
          tkeep=req.tkeep[beat_counter],
          tuser=req.tuser[beat_counter])
        beat_counter += 1
        self.vif.drive_opt(tlast=1 if beat_counter == burst_length else 0)

        await self._wait_handshake()
        if beat_counter == burst_length:
          self.vif.drive_opt(tvalid=0)
    finally:
      if tvalid_task is not None and not tvalid_task.done():
        _cancel_task(tvalid_task)
      self.vif.drive_opt(tvalid=0)

  async def drive_tvalid(self):
    clock_counter = 0
    tvalid_delay_period = self.cfg.get_delay(
      self.cfg.tvalid_delay_enabled, self.cfg.tvalid_delay_gauss_enabled,
      self.cfg.g_tvalid_period, self.cfg.min_tvalid_delay_period,
      self.cfg.max_tvalid_delay_period)

    self.vif.drive_opt(tvalid=1)
    while True:
      await self.vif.rising()
      if self.vif.get_or("tvalid") == 1 and self.vif.get_or("tready") == 1 and self.vif.get_or("tlast") == 1:
        await self.vif.rising()
        self.vif.drive_opt(tvalid=0)
        return

      clock_counter += 1
      if (clock_counter >= tvalid_delay_period and
          self.vif.get_or("tvalid") == 1 and self.vif.get_or("tready") == 1):
        self.vif.drive_opt(tvalid=0)
        clock_counter = 0
        tvalid_delay_time = self.cfg.get_delay(
          self.cfg.tvalid_delay_enabled, self.cfg.tvalid_delay_gauss_enabled,
          self.cfg.g_tvalid_time, self.cfg.min_tvalid_delay_time,
          self.cfg.max_tvalid_delay_time)
        tvalid_delay_period = self.cfg.get_delay(
          self.cfg.tvalid_delay_enabled, self.cfg.tvalid_delay_gauss_enabled,
          self.cfg.g_tvalid_period, self.cfg.min_tvalid_delay_period,
          self.cfg.max_tvalid_delay_period)
        for _ in range(tvalid_delay_time):
          await self.vif.rising()
      else:
        self.vif.drive_opt(tvalid=1)

  async def slave_drive(self):
    await self.drive_tready()

  async def drive_tready(self):
    if not self.cfg.tready_delay_enabled:
      self.vif.drive_opt(tready=1)
      while True:
        await self.vif.rising()

    clock_counter = 0
    tready_delay_period = self.cfg.get_delay(
      self.cfg.tready_delay_enabled, self.cfg.tready_delay_gauss_enabled,
      self.cfg.g_tready_period, self.cfg.min_tready_delay_period,
      self.cfg.max_tready_delay_period)

    self.vif.drive_opt(tready=1)
    while True:
      await self.vif.rising()
      clock_counter += 1
      if clock_counter >= tready_delay_period:
        self.vif.drive_opt(tready=0)
        clock_counter = 0
        tready_delay_time = self.cfg.get_delay(
          self.cfg.tready_delay_enabled, self.cfg.tready_delay_gauss_enabled,
          self.cfg.g_tready_time, self.cfg.min_tready_delay_time,
          self.cfg.max_tready_delay_time)
        tready_delay_period = self.cfg.get_delay(
          self.cfg.tready_delay_enabled, self.cfg.tready_delay_gauss_enabled,
          self.cfg.g_tready_period, self.cfg.min_tready_delay_period,
          self.cfg.max_tready_delay_period)
        for _ in range(tready_delay_time):
          clock_counter += 1
          await self.vif.rising()
        self.vif.drive_opt(tready=1)

  async def _wait_handshake(self):
    while True:
      await self.vif.rising()
      if self.vif.get_or("tvalid") == 1 and self.vif.get_or("tready") == 1:
        return

  def handle_reset(self):
    for task in self._driver_tasks:
      try:
        if not task.done():
          _cancel_task(task)
      except Exception:
        pass
    self._driver_tasks = []


def _cancel_task(task):
  if hasattr(task, "cancel"):
    task.cancel()
  else:
    task.kill()
