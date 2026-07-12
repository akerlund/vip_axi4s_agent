################################################################################
# cocotb signal wrapper for vip_axi4s_if.sv.
################################################################################

from __future__ import annotations

from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly


AXI4S_SIGNALS = [
  "tvalid", "tready", "tdata", "tstrb", "tkeep", "tlast",
  "tid", "tdest", "tuser",
]

MASTER_OUTPUTS = ["tvalid", "tdata", "tstrb", "tkeep", "tlast", "tid", "tdest", "tuser"]
SLAVE_OUTPUTS = ["tready"]


class Axi4sBus:

  def __init__(self, dut, clock_name="clk", reset_name="rst_n", prefix=""):
    self.dut = dut
    self.clk = getattr(dut, clock_name)
    self.rst_n = getattr(dut, reset_name)
    self.prefix = prefix
    self.sig = {}
    for name in AXI4S_SIGNALS:
      handle = getattr(dut, prefix + name, None)
      if handle is not None:
        self.sig[name] = handle

  def has(self, name):
    return name in self.sig

  def present_signals(self):
    return sorted(self.sig)

  def drive(self, **values):
    for name, value in values.items():
      if name not in self.sig:
        raise KeyError(f"Axi4sBus: signal '{name}' not present")
      self.sig[name].value = int(value)

  def drive_opt(self, **values):
    for name, value in values.items():
      if name in self.sig:
        self.sig[name].value = int(value)

  def park(self, names, value=0):
    for name in names:
      if name in self.sig:
        self.sig[name].value = value

  def reset_master(self):
    self.park(MASTER_OUTPUTS, 0)

  def reset_slave(self):
    self.park(SLAVE_OUTPUTS, 0)

  def get(self, name):
    return int(self.sig[name].value)

  def get_or(self, name, default=0):
    h = self.sig.get(name)
    return int(h.value) if h is not None else default

  async def rising(self):
    await RisingEdge(self.clk)

  async def falling(self):
    await FallingEdge(self.clk)

  async def sample_edge(self):
    await RisingEdge(self.clk)
    await ReadOnly()

  def get_rst(self):
    return int(self.rst_n.value)

  def in_reset(self):
    return self.get_rst() == 0
