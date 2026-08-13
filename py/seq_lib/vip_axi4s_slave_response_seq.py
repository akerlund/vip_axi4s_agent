from __future__ import annotations

from pyuvm import uvm_sequence


class vip_axi4s_slave_response_seq(uvm_sequence):

  def __init__(self, name="vip_axi4s_slave_response_seq"):
    super().__init__(name)
    self._max_responses = -1
    self._tready_delay = []

  def set_max_responses(self, max_responses):
    self._max_responses = int(max_responses)

  def set_tready_delay(self, tready_delay):
    self._tready_delay = [int(v) for v in tready_delay]

  def configure_response(self, rsp):
    if self._tready_delay:
      rsp.set_tready_delay(self._tready_delay)

  async def body(self):
    responses = 0
    while self._max_responses < 0 or responses < self._max_responses:
      req = await self.sequencer.get_packet_start()
      self.configure_response(req)
      self.sequencer.put_packet_response(req)
      responses += 1
