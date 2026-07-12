################################################################################
# cocotb entry point for the AXI4-Stream pyUVM example.
################################################################################

from __future__ import annotations

import os
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from pyuvm import ConfigDB, uvm_root

_HERE = os.path.dirname(os.path.abspath(__file__))


def _find_vip_root(start):
  env = os.environ.get("VIP_ROOT")
  if env:
    return os.path.abspath(env)
  d = start
  while True:
    if os.path.exists(os.path.join(d, ".git")):
      return d
    parent = os.path.dirname(d)
    if parent == d:
      return os.path.abspath(os.path.join(start, "..", ".."))
    d = parent


_ROOT = _find_vip_root(_HERE)
_COMPONENT_PYS = [
  os.path.join(_ROOT, "py"),
  os.path.join(_ROOT, "submodules", "vip_gauss", "py"),
]
_LOCAL_PYS = [os.path.join(_HERE, "tb"), os.path.join(_HERE, "tc")]
for p in _COMPONENT_PYS + _LOCAL_PYS:
  if os.path.isdir(p) and p not in sys.path:
    sys.path.insert(0, p)
  elif not os.path.isdir(p):
    raise RuntimeError(
      f"axi4s_tc_top: expected source dir not found: {p}\n"
      f"  (VIP root resolved to {_ROOT}; set $VIP_ROOT to override)")

from vip_axi4s_if import Axi4sBus                         # noqa: E402
from vip_axi4s_types_pkg import Axi4sCfgT                 # noqa: E402
from tc_axi4s_demonstration import tc_axi4s_demonstration # noqa: E402,F401
from tc_axi4s_backpressure import tc_axi4s_backpressure   # noqa: E402,F401


CFG_T = Axi4sCfgT(TDATA_BYTES_P=4, TID_WIDTH_P=4,
                  TDEST_WIDTH_P=4, TUSER_WIDTH_P=4)


async def _run(dut, test_name):
  cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
  bus = Axi4sBus(dut)
  bus.reset_master()
  bus.reset_slave()

  dut.rst_n.value = 0
  for _ in range(5):
    await RisingEdge(dut.clk)
  dut.rst_n.value = 1
  await RisingEdge(dut.clk)

  ConfigDB().set(None, "*", "vif", bus)
  ConfigDB().set(None, "*", "cfg_t", CFG_T)
  await uvm_root().run_test(test_name, keep_set={ConfigDB})


@cocotb.test(timeout_time=5, timeout_unit="ms")
async def tb_demonstration(dut):
  await _run(dut, "tc_axi4s_demonstration")


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def tb_backpressure(dut):
  await _run(dut, "tc_axi4s_backpressure")
