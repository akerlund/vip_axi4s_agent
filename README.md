# vip_axi4s_agent

AXI4-Stream verification agent with both implementations kept side by side:

- [`sv/`](sv/README.md): the original SystemVerilog UVM VIP. Its FuseSoC
  descriptor, [`vip_axi4s_agent.core`](vip_axi4s_agent.core), is kept at the
  repository root so this repo can be added directly to a FuseSoC search path.
- [`py/`](py/README.md): a cocotb/pyUVM port.

The Python port mirrors the SV agent structure: configuration objects, sequence
items, active master/slave driver behavior, monitor collection/protocol checks,
and a reset-aware agent wrapper.

The SV agent depends on [`vip_gauss`](https://github.com/akerlund/vip_gauss)
(Gaussian-distributed delays); the Python port only uses it optionally, at
runtime, if it's importable. [`testbench/`](testbench/README.md) additionally
depends on [`vip_clk_rst_agent`](https://github.com/akerlund/vip_clk_rst_agent)
and [`vip_report_server`](https://github.com/akerlund/vip_report_server)
(SV only). All three are checked out as git submodules under
[`submodules/`](submodules); run `git submodule update --init` to fetch
them, then point FuseSoC's `--cores-root` at both the repository root and
whichever submodules the target you're building needs.
