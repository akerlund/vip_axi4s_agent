# vip_axi4s_agent example

AXI4-Stream VIP example in two forms:

- `sv/`: original SystemVerilog UVM example.
- `py/`: cocotb/pyUVM example using the Python AXI4-Stream VIP.

The Python flow uses a pure loopback HDL shell plus a Python testbench top:

- `py/tb/axi4s_hdl_top.sv` exposes the Verilator-visible AXI4-Stream nets.
- `py/tb/axi4s_tb_top.py` starts the clock/reset, publishes the bus through
  pyUVM `ConfigDB`, and runs the selected `tc_axi4s_*` testcase.

The master VIP drives `TVALID` and payload, the slave VIP drives `TREADY`, and
both monitors observe the same bus.
