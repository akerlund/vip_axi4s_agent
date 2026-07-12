# AXI4-Stream cocotb Example

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
COCOTB_TEST_FILTER=tb_backpressure ./run_fusesoc.sh
```

The example runs a pure VIP loopback with no RTL DUT. It is meant to validate
the cocotb/pyUVM AXI4-Stream agent in the same spirit as the SystemVerilog UVM
example under `../sv`.
