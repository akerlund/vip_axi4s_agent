# AXI4-Stream SystemVerilog Example

Original UVM example for `vip_axi4s_agent`. Depends on the sibling VIPs
checked out under [`submodules/`](../../submodules): `vip_gauss`,
`vip_clk_rst_agent`, and `vip_report_server`. Run `git submodule update
--init` from the repository root first.

Run with the repository root and each submodule as a FuseSoC cores root:

```sh
fusesoc \
  --cores-root ../.. \
  --cores-root ../../submodules/vip_gauss \
  --cores-root ../../submodules/vip_clk_rst_agent \
  --cores-root ../../submodules/vip_report_server \
  run --tool vcs akerlund::vip_axi4s_agent_example:0
```
