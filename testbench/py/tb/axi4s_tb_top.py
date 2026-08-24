################################################################################
# cocotb testbench top for the AXI4-Stream pyUVM example.
################################################################################

from __future__ import annotations

import os
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from pyuvm import ConfigDB, uvm_root

_HERE = os.path.dirname(os.path.abspath(__file__))
_PY_ROOT = os.path.dirname(_HERE)


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
_LOCAL_PYS = [_HERE, os.path.join(_PY_ROOT, "tc")]
for p in _COMPONENT_PYS + _LOCAL_PYS:
  if os.path.isdir(p) and p not in sys.path:
    sys.path.insert(0, p)
  elif not os.path.isdir(p):
    raise RuntimeError(
      f"axi4s_tb_top: expected source dir not found: {p}\n"
      f"  (VIP root resolved to {_ROOT}; set $VIP_ROOT to override)")

from vip_axi4s_if import Axi4sBus                         # noqa: E402
from vip_axi4s_types_pkg import Axi4sCfgT                 # noqa: E402
from tc_axi4s_demonstration import tc_axi4s_demonstration # noqa: E402,F401
from tc_axi4s_backpressure import tc_axi4s_backpressure   # noqa: E402,F401
from tc_axi4s_active_slave_response import tc_axi4s_active_slave_response # noqa: E402,F401
from tc_axi4s_neg_checkers import (                       # noqa: E402,F401
  tc_axi4s_interleaved_streams,
  tc_axi4s_master_self_check,
  tc_axi4s_packet_start_back_to_back,
  tc_axi4s_neg_byte_qualifier,
  tc_axi4s_neg_disable_controls,
  tc_axi4s_neg_max_length,
  tc_axi4s_neg_packet_boundary,
  tc_axi4s_neg_reset,
  tc_axi4s_neg_stream_tracking,
  tc_axi4s_neg_stability,
  tc_axi4s_neg_tvalid_drop,
  tc_axi4s_neg_xz,
)
from tc_axi4s_sparse_qualifiers import tc_axi4s_sparse_qualifiers # noqa: E402,F401
from tc_axi4s_optional_extras import tc_axi4s_optional_extras # noqa: E402,F401
from tc_axi4s_random import tc_axi4s_random           # noqa: E402,F401


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


@cocotb.test(name="tc_axi4s_demonstration", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_demonstration(dut):
  await _run(dut, "tc_axi4s_demonstration")


@cocotb.test(name="tc_axi4s_backpressure", timeout_time=10, timeout_unit="ms")
async def tc_axi4s_backpressure(dut):
  await _run(dut, "tc_axi4s_backpressure")


@cocotb.test(name="tc_axi4s_active_slave_response", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_active_slave_response(dut):
  await _run(dut, "tc_axi4s_active_slave_response")


@cocotb.test(name="tc_axi4s_neg_xz", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_neg_xz(dut):
  await _run(dut, "tc_axi4s_neg_xz")


@cocotb.test(name="tc_axi4s_neg_stability", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_neg_stability(dut):
  await _run(dut, "tc_axi4s_neg_stability")


@cocotb.test(name="tc_axi4s_neg_tvalid_drop", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_neg_tvalid_drop(dut):
  await _run(dut, "tc_axi4s_neg_tvalid_drop")


@cocotb.test(name="tc_axi4s_neg_reset", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_neg_reset(dut):
  await _run(dut, "tc_axi4s_neg_reset")


@cocotb.test(name="tc_axi4s_neg_byte_qualifier", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_neg_byte_qualifier(dut):
  await _run(dut, "tc_axi4s_neg_byte_qualifier")


@cocotb.test(name="tc_axi4s_neg_packet_boundary", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_neg_packet_boundary(dut):
  await _run(dut, "tc_axi4s_neg_packet_boundary")


@cocotb.test(name="tc_axi4s_neg_max_length", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_neg_max_length(dut):
  await _run(dut, "tc_axi4s_neg_max_length")


@cocotb.test(name="tc_axi4s_neg_stream_tracking", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_neg_stream_tracking(dut):
  await _run(dut, "tc_axi4s_neg_stream_tracking")


@cocotb.test(name="tc_axi4s_neg_disable_controls", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_neg_disable_controls(dut):
  await _run(dut, "tc_axi4s_neg_disable_controls")


@cocotb.test(name="tc_axi4s_interleaved_streams", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_interleaved_streams(dut):
  await _run(dut, "tc_axi4s_interleaved_streams")


@cocotb.test(name="tc_axi4s_master_self_check", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_master_self_check(dut):
  await _run(dut, "tc_axi4s_master_self_check")


@cocotb.test(name="tc_axi4s_packet_start_back_to_back", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_packet_start_back_to_back(dut):
  await _run(dut, "tc_axi4s_packet_start_back_to_back")


@cocotb.test(name="tc_axi4s_sparse_qualifiers", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_sparse_qualifiers(dut):
  await _run(dut, "tc_axi4s_sparse_qualifiers")


@cocotb.test(name="tc_axi4s_optional_extras", timeout_time=5, timeout_unit="ms")
async def tc_axi4s_optional_extras(dut):
  await _run(dut, "tc_axi4s_optional_extras")


@cocotb.test(name="tc_axi4s_random", timeout_time=60, timeout_unit="ms")
async def tc_axi4s_random(dut):
  await _run(dut, "tc_axi4s_random")
