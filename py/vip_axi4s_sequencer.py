################################################################################
# pyUVM port of vip_axi4s_sequencer.sv.
################################################################################

from __future__ import annotations

from pyuvm import uvm_sequencer


class vip_axi4s_sequencer(uvm_sequencer):

  def __init__(self, name, parent):
    super().__init__(name, parent)

  def handle_reset(self):
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
