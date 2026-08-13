################################################################################
# pyUVM callback base classes for vip_axi4s_agent.
################################################################################

from __future__ import annotations


class vip_axi4s_driver_callback:

  def pre_packet(self, driver, item):
    pass

  def post_packet(self, driver, item):
    pass

  def pre_beat(self, driver, item, beat_index):
    pass

  def post_beat(self, driver, item, beat_index):
    pass

  def pre_reset(self, driver):
    pass

  def post_reset(self, driver):
    pass


class vip_axi4s_monitor_callback:

  def beat_sampled(self, monitor, beat):
    pass

  def packet_completed(self, monitor, packet):
    pass

  def checker_violation(self, monitor, check, message):
    pass
