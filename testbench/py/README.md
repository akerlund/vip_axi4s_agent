# AXI4-Stream Python Testbench

Depends on the `vip_gauss` submodule checked out under
[`submodules/`](../../submodules). Run `git submodule update --init` from
the repository root first.

Run through FuseSoC:

```sh
./run_fusesoc.sh
```

Python dependencies:

```sh
python3 -m pip install --user cocotb==2.0.1 pyuvm==4.0.1 pytest
```

Select one test with cocotb filtering:

```sh
COCOTB_TEST_FILTER=tc_axi4s_backpressure ./run_fusesoc.sh
```

The example runs a pure VIP loopback with no RTL DUT. `tb/axi4s_hdl_top.sv`
exposes the Verilator-visible nets, while `tb/axi4s_tb_top.py` is the Python
cocotb/pyUVM testbench top. The public cocotb test names match the testcase
files: `tc_axi4s_demonstration` and `tc_axi4s_backpressure`.
