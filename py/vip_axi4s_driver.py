################################################################################
# pyUVM port of vip_axi4s_driver.sv.
################################################################################

from __future__ import annotations

import cocotb
from cocotb.triggers import Combine, FallingEdge, NullTrigger, ReadOnly, RisingEdge, Timer

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
    self.sequencer = None
    self._slave_response_active = False
    self.callbacks = []
    self._idle_tlast_value = 0
    self._idle_tready_value = 0

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
    self._do_pre_reset()
    if self.cfg.vip_axi4s_agent_type == Axi4sAgentType.MASTER:
      self.vif.reset_master()
    else:
      self.vif.reset_slave()
    self._do_post_reset()

  def add_callback(self, cb):
    self.callbacks.append(cb)

  async def master_drive(self):
    while True:
      req = await self.seq_item_port.get_next_item()
      try:
        await self.drive_axi4s_item(req)
      finally:
        self.seq_item_port.item_done()

  async def drive_axi4s_item(self, req):
    burst_length = len(req.tdata)
    tvalid_delay = self._build_tvalid_delays(req, burst_length)
    cycle_count = 0
    prev_tvalid_cycle = 0
    prev_handshake_cycle = 0

    if self.cfg.drive_idle_values_enable or self.cfg.tlast_idle_toggle_enable:
      self._drive_master_idle()
    else:
      self.vif.drive_opt(tvalid=0, tlast=0)

    # TID/TDEST belong to the packet and must override any idle values
    self.vif.drive_opt(tid=req.tid, tdest=req.tdest)
    self._do_pre_packet(req)

    try:
      if self._can_use_tdata_only_fast_path(req, tvalid_delay):
        await self._drive_tdata_only_fast_path(req, burst_length, cycle_count)
      else:
        for beat_counter in range(burst_length):
          cycle_count = await self._wait_tvalid_delay(
            req, tvalid_delay[beat_counter], beat_counter, cycle_count,
            prev_tvalid_cycle, prev_handshake_cycle)
          # TID/TDEST are re-driven per beat because an inter-beat delay parks
          # the bus on the idle values
          self.vif.drive_opt(
            tdata=req.tdata[beat_counter],
            tstrb=req.tstrb[beat_counter],
            tkeep=req.tkeep[beat_counter],
            tuser=req.tuser[beat_counter],
            tid=req.tid,
            tdest=req.tdest,
            tlast=1 if beat_counter == burst_length - 1 else 0,
            tvalid=1)
          self._do_pre_beat(req, beat_counter)
          prev_tvalid_cycle = cycle_count

          cycle_count = await self._wait_handshake_with_cycle(cycle_count)
          prev_handshake_cycle = cycle_count
          self._do_post_beat(req, beat_counter)
    finally:
      self._drive_master_idle()
      self._do_post_packet(req)

  async def _drive_tdata_only_fast_path(self, req, burst_length, cycle_count):
    keep_mask = (1 << int(self.cfg_t.TDATA_BYTES_P)) - 1
    self.vif.drive_opt(
      tstrb=keep_mask,
      tkeep=keep_mask,
      tuser=0,
      tid=req.tid,
      tdest=req.tdest)
    for beat_counter in range(burst_length):
      self.vif.drive_opt(
        tdata=req.tdata[beat_counter],
        tlast=1 if beat_counter == burst_length - 1 else 0,
        tvalid=1)
      self._do_pre_beat(req, beat_counter)
      cycle_count = await self._wait_handshake_with_cycle(cycle_count)
      self._do_post_beat(req, beat_counter)

  def _can_use_tdata_only_fast_path(self, req, tvalid_delay):
    if not self.cfg.tdata_only_fast_path_enable:
      return False
    if any(int(delay) != 0 for delay in tvalid_delay):
      return False
    keep_mask = (1 << int(self.cfg_t.TDATA_BYTES_P)) - 1
    return (
      all(int(value) == keep_mask for value in req.tkeep) and
      all(int(value) == keep_mask for value in req.tstrb) and
      all(int(value) == 0 for value in req.tuser))

  def _build_tvalid_delays(self, req, burst_length):
    if req.tvalid_delay:
      if len(req.tvalid_delay) != burst_length:
        raise RuntimeError(
          f"tvalid_delay size {len(req.tvalid_delay)} does not match "
          f"burst_length {burst_length}")
      return list(req.tvalid_delay)

    if self.cfg.zero_delays_enable or not self.cfg.tvalid_delay_enabled:
      return [0 for _ in range(burst_length)]

    delays = []
    beats_since_delay = 0
    delay_period = self.cfg.get_delay(
      self.cfg.tvalid_delay_enabled, self.cfg.tvalid_delay_gauss_enabled,
      self.cfg.g_tvalid_period, self.cfg.min_tvalid_delay_period,
      self.cfg.max_tvalid_delay_period)

    for beat in range(burst_length):
      if beat == 0:
        delays.append(0)
      elif beats_since_delay >= delay_period:
        delays.append(self.cfg.get_delay(
          self.cfg.tvalid_delay_enabled, self.cfg.tvalid_delay_gauss_enabled,
          self.cfg.g_tvalid_time, self.cfg.min_tvalid_delay_time,
          self.cfg.max_tvalid_delay_time))
        beats_since_delay = 0
        delay_period = self.cfg.get_delay(
          self.cfg.tvalid_delay_enabled, self.cfg.tvalid_delay_gauss_enabled,
          self.cfg.g_tvalid_period, self.cfg.min_tvalid_delay_period,
          self.cfg.max_tvalid_delay_period)
      else:
        delays.append(0)
      beats_since_delay += 1
    return delays

  async def _wait_tvalid_delay(self, req, delay, beat_counter, cycle_count,
                               prev_tvalid_cycle, prev_handshake_cycle):
    if beat_counter == 0:
      target_cycle = cycle_count + delay
    elif int(req.reference_event_for_tvalid_delay) == 0:
      target_cycle = prev_tvalid_cycle + delay
    else:
      target_cycle = prev_handshake_cycle + delay

    # Each iteration must leave the coroutine just past the clock edge, in the
    # same phase _wait_handshake_with_cycle returns in. Resuming straight from
    # RisingEdge would still be inside the edge, so the next drive would land
    # in the cycle that is already being sampled and the beat would be seen
    # twice
    while cycle_count < target_cycle:
      self._drive_master_idle()
      await self.vif.rising()
      await ReadOnly()
      await Timer(1, unit="step")
      cycle_count += 1
    return cycle_count

  async def slave_drive(self):
    tasks = [
      cocotb.start_soon(self.drive_tready()),
      cocotb.start_soon(self.drive_tready_responses()),
    ]
    self._driver_tasks.extend(tasks)
    await Combine(*tasks)

  async def drive_tready(self):
    if self.cfg.zero_delays_enable or not self.cfg.tready_delay_enabled:
      while True:
        if not self._slave_response_active:
          self._drive_tready_default()
        await self.vif.rising()

    clock_counter = 0
    tready_delay_period = self.cfg.get_delay(
      self.cfg.tready_delay_enabled, self.cfg.tready_delay_gauss_enabled,
      self.cfg.g_tready_period, self.cfg.min_tready_delay_period,
      self.cfg.max_tready_delay_period)

    self.vif.drive_opt(tready=1)
    while True:
      await self.vif.rising()
      if self._slave_response_active:
        continue
      if self._drive_tready_idle_if_enabled():
        continue
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
          await self.vif.rising()
          if self._slave_response_active:
            break
          clock_counter += 1
        if not self._slave_response_active:
          self._drive_tready_default()

  async def drive_tready_responses(self):
    # Same anchor as the monitor packet start detection, so that back-to-back
    # packets, where TVALID never goes low across the TLAST boundary, are
    # picked up as well
    while True:
      await self.vif.falling()
      await ReadOnly()
      if self.vif.get_rst() == 1 and self.vif.get_or("tvalid") == 1:
        await Timer(1, unit="step")
        for _ in range(3):
          await NullTrigger()

        rsp = self._try_get_response_item()
        if rsp is not None:
          if self.sequencer is None:
            raise RuntimeError("Slave response item received without a sequencer handle")
          if not self.sequencer.is_expected_packet_response(rsp):
            raise RuntimeError(
              "Slave response sequence must return the packet-start request object handle")

          self._slave_response_active = True
          try:
            await self.drive_tready_response(rsp, 0)
          finally:
            self.sequencer.clear_active_packet_request(rsp)
            self._slave_response_active = False
        elif (self.sequencer is not None and
              self.sequencer.response_expected_for_active_packet()):
          raise RuntimeError(
            "Slave response sequence did not return a response item in zero time")

  def _try_get_response_item(self):
    if self.sequencer is None:
      return None
    return self.sequencer.try_get_packet_response()

  async def drive_tready_response(self, rsp, first_beat_index):
    beat_index = first_beat_index
    beats_since_delay = 0
    delay_period = self.cfg.get_delay(
      self.cfg.tready_delay_enabled, self.cfg.tready_delay_gauss_enabled,
      self.cfg.g_tready_period, self.cfg.min_tready_delay_period,
      self.cfg.max_tready_delay_period)

    while True:
      delay, beats_since_delay, delay_period = self._get_tready_response_delay(
        rsp, beat_index, beats_since_delay, delay_period)

      self.vif.drive_opt(tready=0)
      for _ in range(delay):
        await self.vif.rising()
      if delay > 0:
        await ReadOnly()
        await Timer(1, unit="step")
      self.vif.drive_opt(tready=1)

      if await self._wait_handshake() == 1:
        return
      beat_index += 1

  def _get_tready_response_delay(self, rsp, beat_index, beats_since_delay,
                                 delay_period):
    if rsp.tready_delay:
      if beat_index >= len(rsp.tready_delay):
        raise RuntimeError(
          f"tready_delay response array ended at beat {beat_index} before TLAST")
      return int(rsp.tready_delay[beat_index]), beats_since_delay, delay_period

    if self.cfg.zero_delays_enable or not self.cfg.tready_delay_enabled:
      return 0, beats_since_delay, delay_period

    if beats_since_delay >= delay_period:
      delay_period = self.cfg.get_delay(
        self.cfg.tready_delay_enabled, self.cfg.tready_delay_gauss_enabled,
        self.cfg.g_tready_period, self.cfg.min_tready_delay_period,
        self.cfg.max_tready_delay_period)
      delay = self.cfg.get_delay(
        self.cfg.tready_delay_enabled, self.cfg.tready_delay_gauss_enabled,
        self.cfg.g_tready_time, self.cfg.min_tready_delay_time,
        self.cfg.max_tready_delay_time)
      return delay, 0, delay_period

    return 0, beats_since_delay + 1, delay_period

  async def _wait_handshake(self):
    # TLAST is captured in the sampled phase and returned to the caller. After
    # the Timer step the master coroutine may already have driven the next
    # beat, so reading TLAST there would test the wrong beat
    while True:
      await self.vif.rising()
      await ReadOnly()
      if self.vif.get_or("tvalid") == 1 and self.vif.get_or("tready") == 1:
        tlast = self.vif.get_or("tlast")
        await Timer(1, unit="step")
        return tlast

  async def _wait_handshake_with_cycle(self, cycle_count):
    while True:
      await self.vif.rising()
      cycle_count += 1
      await ReadOnly()
      if self.vif.get_or("tvalid") == 1 and self.vif.get_or("tready") == 1:
        await Timer(1, unit="step")
        return cycle_count

  def handle_reset(self):
    for task in self._driver_tasks:
      try:
        if not task.done():
          _cancel_task(task)
      except Exception:
        pass
    self._driver_tasks = []
    self._slave_response_active = False
    self._idle_tlast_value = 0
    self._idle_tready_value = 0

  def _drive_master_idle(self):
    values = {"tvalid": 0}
    if self.cfg.drive_idle_values_enable:
      values.update({
        "tdata": self.cfg.idle_tdata,
        "tstrb": self.cfg.idle_tstrb,
        "tkeep": self.cfg.idle_tkeep,
        "tid": self.cfg.idle_tid,
        "tdest": self.cfg.idle_tdest,
        "tuser": self.cfg.idle_tuser,
      })
      values["tlast"] = self.cfg.idle_tlast
    else:
      values["tlast"] = 0

    if self.cfg.tlast_idle_toggle_enable:
      self._idle_tlast_value ^= 1
      values["tlast"] = self._idle_tlast_value

    self.vif.drive_opt(**values)

  def _drive_tready_default(self):
    if not self._drive_tready_idle_if_enabled():
      self.vif.drive_opt(tready=1)

  def _drive_tready_idle_if_enabled(self):
    if not self.cfg.tready_idle_toggle_enable:
      return False

    if self.vif.get_or("tvalid") != 1:
      self._idle_tready_value ^= 1
      self.vif.drive_opt(tready=self._idle_tready_value)
      return True

    # TVALID went high while the toggle happened to leave TREADY low. Without
    # restoring it here the beat would be stalled until the next backpressure
    # period elapses, which is not what an idle toggle is meant to do
    if not self._idle_tready_value:
      self._idle_tready_value = 1
      self.vif.drive_opt(tready=1)

    return False

  def _do_pre_packet(self, item):
    for cb in self.callbacks:
      cb.pre_packet(self, item)

  def _do_post_packet(self, item):
    for cb in self.callbacks:
      cb.post_packet(self, item)

  def _do_pre_beat(self, item, beat_index):
    for cb in self.callbacks:
      cb.pre_beat(self, item, beat_index)

  def _do_post_beat(self, item, beat_index):
    for cb in self.callbacks:
      cb.post_beat(self, item, beat_index)

  def _do_pre_reset(self):
    for cb in self.callbacks:
      cb.pre_reset(self)

  def _do_post_reset(self):
    for cb in self.callbacks:
      cb.post_reset(self)


def _cancel_task(task):
  if hasattr(task, "cancel"):
    task.cancel()
  else:
    task.kill()
