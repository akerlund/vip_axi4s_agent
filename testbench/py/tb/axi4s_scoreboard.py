################################################################################
# pyUVM scoreboard for the AXI4-Stream cocotb example.
################################################################################

from __future__ import annotations

from pyuvm import uvm_component, uvm_subscriber


class _SbSub(uvm_subscriber):
  def __init__(self, name, parent, cb):
    super().__init__(name, parent)
    self._cb = cb

  def write(self, item):
    self._cb(item)


class axi4s_scoreboard(uvm_component):

  def __init__(self, name, parent):
    super().__init__(name, parent)
    self.mst_items = []
    self.slv_items = []
    self.number_of_mst_items = 0
    self.number_of_slv_items = 0
    self.number_of_compared = 0
    self.number_of_passed = 0
    self.number_of_failed = 0
    self.mst_port = None
    self.slv_port = None

  def build_phase(self):
    self._mst_sub = _SbSub("mst_sub", self, self.write_mst_port)
    self._slv_sub = _SbSub("slv_sub", self, self.write_slv_port)
    self.mst_port = self._mst_sub.analysis_export
    self.slv_port = self._slv_sub.analysis_export

  def handle_reset(self):
    self.mst_items.clear()
    self.slv_items.clear()

  def write_mst_port(self, item):
    self.number_of_mst_items += 1
    self.mst_items.append(item.clone())
    self._compare_ready_items()

  def write_slv_port(self, item):
    self.number_of_slv_items += 1
    self.slv_items.append(item.clone())
    self._compare_ready_items()

  def _compare_ready_items(self):
    while self.mst_items and self.slv_items:
      mst = self.mst_items.pop(0)
      slv = self.slv_items.pop(0)
      self.number_of_compared += 1
      if _items_equal(mst, slv):
        self.number_of_passed += 1
      else:
        self.number_of_failed += 1
        self.logger.error(
          f"Packet {self.number_of_compared} mismatch: "
          f"mst={_item_tuple(mst)} slv={_item_tuple(slv)}")

  def check_phase(self):
    self._compare_ready_items()
    if self.mst_items or self.slv_items:
      self.number_of_failed += len(self.mst_items) + len(self.slv_items)
      self.logger.error(
        f"Unmatched packets: mst={len(self.mst_items)} slv={len(self.slv_items)}")
    if self.number_of_failed:
      self.logger.error(f"Test failed! ({self.number_of_failed}) mismatches")
    else:
      self.logger.info(
        f"Test passed ({self.number_of_passed}/{self.number_of_compared}) "
        f"finished transfers")


def _item_tuple(item):
  return (
    int(item.tid),
    int(item.tdest),
    [int(x) for x in item.tdata],
    [int(x) for x in item.tstrb],
    [int(x) for x in item.tkeep],
    [int(x) for x in item.tuser],
  )


def _items_equal(a, b):
  return _item_tuple(a) == _item_tuple(b)
