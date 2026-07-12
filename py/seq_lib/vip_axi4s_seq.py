from __future__ import annotations

from seq_lib.vip_axi4s_base_seq import vip_axi4s_base_seq


class vip_axi4s_seq(vip_axi4s_base_seq):

  def __init__(self, name="vip_axi4s_seq", cfg_t=None):
    super().__init__(name, cfg_t)
