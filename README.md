# vip_axi4s_agent

AXI4-Stream verification agent with both implementations kept side by side:

- [`sv/`](sv/README.md): the original SystemVerilog UVM VIP. Its FuseSoC
  descriptor, [`vip_axi4s_agent.core`](vip_axi4s_agent.core), is kept at the
  repository root so this repo can be added directly to a FuseSoC search path.
- [`py/`](py/README.md): a cocotb/pyUVM port.

The Python port mirrors the SV agent structure: configuration objects, sequence
items, active master/slave driver behavior, monitor collection/protocol checks,
and a reset-aware agent wrapper.
