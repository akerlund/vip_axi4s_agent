////////////////////////////////////////////////////////////////////////////////
//
// AXI4-Stream HDL shell for the cocotb/pyUVM loopback testbench.
//
// No RTL DUT is instantiated. The Python master agent drives TVALID and payload
// signals, the Python slave agent drives TREADY, and both monitors observe the
// same top-level nets. Build with --public-flat-rw so cocotb can read/write the
// nets through Verilator.
//
////////////////////////////////////////////////////////////////////////////////

`default_nettype none

module axi4s_hdl_top #(
    parameter int TDATA_BYTES = 4,
    parameter int TDATA_W     = 8 * TDATA_BYTES,
    parameter int TSTRB_W     = TDATA_BYTES,
    parameter int TKEEP_W     = TDATA_BYTES,
    parameter int TID_W       = 4,
    parameter int TDEST_W     = 4,
    parameter int TUSER_W     = 4
  )(
    input wire clk,
    input wire rst_n
  );

  // verilator lint_off UNDRIVEN
  logic                tvalid;
  logic                tready;
  logic [TDATA_W-1:0]  tdata;
  logic [TSTRB_W-1:0]  tstrb;
  logic [TKEEP_W-1:0]  tkeep;
  logic                tlast;
  logic [TID_W-1:0]    tid;
  logic [TDEST_W-1:0]  tdest;
  logic [TUSER_W-1:0]  tuser;
  // verilator lint_on UNDRIVEN

endmodule

`default_nettype wire
