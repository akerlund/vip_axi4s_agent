# vip_axi4s_agent example

AXI4-Stream VIP example in two forms:

- `sv/`: original SystemVerilog UVM example.
- `py/`: cocotb/pyUVM example using the Python AXI4-Stream VIP.

The Python flow uses a pure loopback top: the master VIP drives `TVALID` and
payload, the slave VIP drives `TREADY`, and both monitors observe the same bus.
