# SystemVerilog VIP

Original UVM implementation of `vip_axi4s_agent`. See the [top-level
README](../README.md) for an overview of the agent, and [`py/`](../py/README.md)
for the cocotb/pyUVM port.

The `vip_axi4s_agent.core` FuseSoC descriptor lives in the repository root;
add the repository root to the FuseSoC search path to use it. It depends on
`vip_gauss`, checked out as a git submodule under
[`../submodules/vip_gauss`](../submodules); add that path to the search
path too (`--cores-root . --cores-root submodules/vip_gauss`).
