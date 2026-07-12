# cocotb/pyUVM VIP

Python port of the AXI4-Stream VIP. See the [top-level
README](../README.md) for an overview of the agent, and [`sv/`](../sv/README.md)
for the original SystemVerilog UVM implementation.

Typical test setup:

```python
from pyuvm import ConfigDB

from vip_axi4s_if import Axi4sBus
from vip_axi4s_types_pkg import Axi4sCfgT, Axi4sAgentType
from vip_axi4s_config import vip_axi4s_config

bus = Axi4sBus(dut)
cfg_t = Axi4sCfgT(TDATA_BYTES_P=4, TID_WIDTH_P=1, TDEST_WIDTH_P=1)
cfg = vip_axi4s_config()
cfg.vip_axi4s_agent_type = Axi4sAgentType.MASTER

ConfigDB().set(None, "uvm_test_top.env.agent", "vif", bus)
ConfigDB().set(None, "uvm_test_top.env.agent", "cfg_t", cfg_t)
ConfigDB().set(None, "uvm_test_top.env.agent", "cfg", cfg)
```

The port intentionally keeps the SV names available as aliases
(`VIP_AXI4S_MASTER_AGENT_E`, `VIP_AXI4S_TDATA_COUNTER_E`, and so on) so existing
test intent can be translated with minimal friction.
