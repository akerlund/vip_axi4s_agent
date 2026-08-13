################################################################################
# pyUVM port of vip_axi4s_sequencer.sv.
################################################################################

from __future__ import annotations

from cocotb.queue import Queue

from pyuvm import uvm_sequencer


class vip_axi4s_sequencer(uvm_sequencer):

  def __init__(self, name, parent):
    super().__init__(name, parent)
    self.packet_start_q = Queue()
    self.packet_response_q = Queue()
    self.active_packet_request = None
    self.packet_start_waiters = 0
    self.response_expected = False

  def notify_packet_start(self, item):
    self.active_packet_request = item
    self.response_expected = self.packet_start_waiters != 0

    # Only queue the request when a response sequence is actually waiting for
    # it. The response contract is zero time, so a request that nobody is
    # waiting for is stale by the time anyone could pop it and would otherwise
    # accumulate for the whole test
    if self.response_expected:
      self.packet_start_q.put_nowait(item)

  async def get_packet_start(self):
    self.packet_start_waiters += 1
    try:
      return await self.packet_start_q.get()
    finally:
      self.packet_start_waiters -= 1

  def response_expected_for_active_packet(self):
    return self.response_expected

  def is_expected_packet_response(self, item):
    return item is not None and item is self.active_packet_request

  def put_packet_response(self, item):
    if not self.is_expected_packet_response(item):
      raise RuntimeError(
        "Slave response sequence must return the packet-start request object handle")
    self.packet_response_q.put_nowait(item)

  def try_get_packet_response(self):
    if self.packet_response_q.empty():
      return None
    return self.packet_response_q.get_nowait()

  def clear_active_packet_request(self, item):
    if item is self.active_packet_request:
      self.active_packet_request = None
      self.response_expected = False

  def handle_reset(self):
    self.active_packet_request = None
    self.packet_start_waiters = 0
    self.response_expected = False
    _drain(self.packet_start_q)
    _drain(self.packet_response_q)
    exp = getattr(self, "seq_item_export", None)
    if exp is not None:
      exp.current_item = None
      for q in (getattr(exp, "req_q", None), getattr(exp, "rsp_q", None)):
        _drain(q)
    _drain(getattr(self, "seq_q", None))


def _drain(q):
  if q is None:
    return
  while True:
    try:
      q.get_nowait()
    except Exception:
      break
