////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2026 Fredrik Åkerlund
// https://github.com/akerlund/VIP
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////

class tc_axi4s_sparse_qualifiers extends axi4s_base_test;

  `uvm_component_utils(tc_axi4s_sparse_qualifiers)

  function new(string name = "tc_axi4s_sparse_qualifiers", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);

    logic [31:0] custom_tdata [$];
    logic  [3:0] custom_tkeep [$];

    super.run_phase(phase);
    phase.raise_objection(this);

    custom_tdata.push_back(32'haabb_ccdd);
    custom_tdata.push_back(32'h1122_3344);
    custom_tkeep.push_back(4'hb);
    custom_tkeep.push_back(4'h7);

    vip_axi4s_seq0.set_verbose(FALSE);
    vip_axi4s_seq0.set_tdata_type(VIP_AXI4S_TDATA_CUSTOM_E);
    vip_axi4s_seq0.set_tdata(custom_tdata);
    vip_axi4s_seq0.set_tkeep_type(VIP_AXI4S_TKEEP_CUSTOM_E);
    vip_axi4s_seq0.set_tkeep(custom_tkeep);
    vip_axi4s_seq0.set_tstrb_type(VIP_AXI4S_TSTRB_ALL_E);
    vip_axi4s_seq0.start(v_sqr.mst_sequencer);

    for (int i = 0; i < 1000 && tb_env.scoreboard0.number_of_compared < 1; i++) begin
      this.clk_delay(1);
    end

    if (tb_env.scoreboard0.number_of_compared != 1) begin
      `uvm_error(get_name(), $sformatf(
        "Expected one sparse transfer, got %0d",
        tb_env.scoreboard0.number_of_compared
      ))
    end
    if (tb_env.scoreboard0.number_of_failed != 0) begin
      `uvm_error(get_name(), "Sparse transfer should pass qualified scoreboard compare")
    end

    this.check_scoreboard_compare_modes();

    `uvm_info(get_name(), "Done!", UVM_LOW)
    phase.drop_objection(this);
  endtask

  function void check_scoreboard_compare_modes();

    vip_axi4s_item #(VIP_AXI4S_CFG_C) mst_item;
    vip_axi4s_item #(VIP_AXI4S_CFG_C) slv_item;
    string mismatch;

    mst_item = new("mst_item");
    slv_item = new("slv_item");

    mst_item.tid = 'h1;
    slv_item.tid = 'h1;
    mst_item.tdest = '0;
    slv_item.tdest = '0;
    mst_item.burst_length = 1;
    slv_item.burst_length = 1;

    mst_item.tdata = new[1];
    slv_item.tdata = new[1];
    mst_item.tstrb = new[1];
    slv_item.tstrb = new[1];
    mst_item.tkeep = new[1];
    slv_item.tkeep = new[1];
    mst_item.tuser = new[1];
    slv_item.tuser = new[1];

    mst_item.tdata[0] = 32'h4433_2211;
    slv_item.tdata[0] = 32'h44bb_aa11;
    mst_item.tstrb[0] = 4'h9;
    slv_item.tstrb[0] = 4'h9;
    mst_item.tkeep[0] = 4'hb;
    slv_item.tkeep[0] = 4'hb;
    mst_item.tuser[0] = '0;
    slv_item.tuser[0] = '0;

    tb_env.scoreboard0.byte_exact_compare = 1'b0;
    if (!tb_env.scoreboard0.compare_items(mst_item, slv_item, mismatch)) begin
      `uvm_error(get_name(), $sformatf(
        "Qualified compare should ignore null and position byte data: %s",
        mismatch
      ))
    end

    tb_env.scoreboard0.byte_exact_compare = 1'b1;
    if (tb_env.scoreboard0.compare_items(mst_item, slv_item, mismatch)) begin
      `uvm_error(get_name(), "Byte-exact compare should reject null/position byte data changes")
    end
    tb_env.scoreboard0.byte_exact_compare = 1'b0;
  endfunction
endclass
