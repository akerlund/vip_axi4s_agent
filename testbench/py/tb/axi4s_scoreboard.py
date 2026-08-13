################################################################################
# pyUVM scoreboard for the AXI4-Stream cocotb example.
################################################################################

from __future__ import annotations

from pyuvm import ConfigDB, uvm_component, uvm_subscriber


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
    self.byte_exact_compare = False

  def build_phase(self):
    self._mst_sub = _SbSub("mst_sub", self, self.write_mst_port)
    self._slv_sub = _SbSub("slv_sub", self, self.write_slv_port)
    self.mst_port = self._mst_sub.analysis_export
    self.slv_port = self._slv_sub.analysis_export
    try:
      self.byte_exact_compare = bool(ConfigDB().get(self, "", "byte_exact_compare"))
    except Exception:
      pass

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
      equal, mismatch = compare_items(mst, slv, self.byte_exact_compare)
      if equal:
        self.number_of_passed += 1
      else:
        self.number_of_failed += 1
        self.logger.error(
          f"Packet {self.number_of_compared} mismatch: "
          f"{mismatch}; mst={_item_tuple(mst)} slv={_item_tuple(slv)}")

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
  return compare_items(a, b, byte_exact=True)[0]


def compare_items(a, b, byte_exact=False):
  if byte_exact:
    return _items_equal_byte_exact(a, b)
  return _items_equal_qualified(a, b)


def _items_equal_byte_exact(a, b):
  if _item_tuple(a) != _item_tuple(b):
    return False, "byte-exact packet fields differ"
  return True, ""


def _items_equal_qualified(a, b):
  if int(a.tid) != int(b.tid):
    return False, f"TID mismatch mst=0x{int(a.tid):x} slv=0x{int(b.tid):x}"
  if int(a.tdest) != int(b.tdest):
    return False, f"TDEST mismatch mst=0x{int(a.tdest):x} slv=0x{int(b.tdest):x}"
  if len(a.tdata) != len(b.tdata):
    return False, f"TDATA size mismatch mst={len(a.tdata)} slv={len(b.tdata)}"
  if len(a.tstrb) != len(b.tstrb) or len(a.tkeep) != len(b.tkeep) or len(a.tuser) != len(b.tuser):
    return False, "qualifier or TUSER array size mismatch"

  for beat, (a_data, b_data, a_strb, b_strb, a_keep, b_keep, a_user, b_user) in enumerate(zip(
      a.tdata, b.tdata, a.tstrb, b.tstrb, a.tkeep, b.tkeep, a.tuser, b.tuser)):
    a_strb = int(a_strb)
    b_strb = int(b_strb)
    a_keep = int(a_keep)
    b_keep = int(b_keep)
    if a_strb != b_strb:
      return False, f"TSTRB[{beat}] mismatch mst=0x{a_strb:x} slv=0x{b_strb:x}"
    if a_keep != b_keep:
      return False, f"TKEEP[{beat}] mismatch mst=0x{a_keep:x} slv=0x{b_keep:x}"
    if int(a_user) != int(b_user):
      return False, f"TUSER[{beat}] mismatch mst=0x{int(a_user):x} slv=0x{int(b_user):x}"

    qualified = a_strb & a_keep
    for lane in range(max(a.cfg_t.TDATA_BYTES_P, b.cfg_t.TDATA_BYTES_P)):
      if qualified & (1 << lane):
        a_byte = (int(a_data) >> (8 * lane)) & 0xFF
        b_byte = (int(b_data) >> (8 * lane)) & 0xFF
        if a_byte != b_byte:
          return False, (
            f"TDATA[{beat}] byte {lane} mismatch "
            f"mst=0x{a_byte:02x} slv=0x{b_byte:02x}")

  return True, ""
