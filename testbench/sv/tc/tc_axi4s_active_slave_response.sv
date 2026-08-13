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

class axi4s_second_beat_stall_seq extends vip_axi4s_slave_response_seq #(VIP_AXI4S_CFG_C);

  int seen_tid;
  int seen_tdest;

  `uvm_object_utils(axi4s_second_beat_stall_seq)

  function new(string name = "axi4s_second_beat_stall_seq");
    super.new(name);
    this.set_max_responses(1);
  endfunction

  virtual function void configure_response(ref vip_axi4s_item #(VIP_AXI4S_CFG_C) rsp);
    int unsigned tready_delay [$];

    seen_tid   = rsp.tid;
    seen_tdest = rsp.tdest;
    tready_delay.push_back(0);
    tready_delay.push_back(3);
    tready_delay.push_back(0);
    rsp.set_tready_delay(tready_delay);
  endfunction
endclass

class tc_axi4s_active_slave_response extends axi4s_base_test;

  virtual clk_rst_if                      clk_vif;
  virtual vip_axi4s_if #(VIP_AXI4S_CFG_C) mst_vif;

  int second_beat_stall_cycles;

  `uvm_component_utils(tc_axi4s_active_slave_response)

  function new(string name = "tc_axi4s_active_slave_response", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    axi4s_mst_cfg0.zero_delays_enable = TRUE;
    axi4s_slv_cfg0.zero_delays_enable = TRUE;

    if (!uvm_config_db #(virtual clk_rst_if)::get(this, "tb_env", "vif", clk_vif)) begin
      `uvm_fatal(get_name(), "Failed to get clk_rst_if")
    end

    if (!uvm_config_db #(virtual vip_axi4s_if #(VIP_AXI4S_CFG_C))::get(this, "tb_env.mst_agent0", "vif", mst_vif)) begin
      `uvm_fatal(get_name(), "Failed to get mst AXI4S vif")
    end
  endfunction

  task run_phase(uvm_phase phase);

    axi4s_second_beat_stall_seq response_seq;
    vip_axi4s_zero_delay_seq #(VIP_AXI4S_CFG_C) zero_seq;
    logic [31:0] custom_tdata [$];

    super.run_phase(phase);
    phase.raise_objection(this);

    response_seq = axi4s_second_beat_stall_seq::type_id::create("response_seq");
    zero_seq     = vip_axi4s_zero_delay_seq #(VIP_AXI4S_CFG_C)::type_id::create("zero_seq");

    custom_tdata.push_back(32'h0000_0000);
    custom_tdata.push_back(32'h0000_0001);
    custom_tdata.push_back(32'h0000_0002);

    fork
      response_seq.start(v_sqr.slv_sequencer);
      this.count_second_beat_stalls();
    join_none

    zero_seq.set_verbose(FALSE);
    zero_seq.set_tdata_type(VIP_AXI4S_TDATA_CUSTOM_E);
    zero_seq.set_tdata(custom_tdata);
    zero_seq.start(v_sqr.mst_sequencer);

    for (int i = 0; i < 1000 && tb_env.scoreboard0.number_of_compared < 1; i++) begin
      this.clk_delay(1);
    end

    if (tb_env.scoreboard0.number_of_compared != 1) begin
      `uvm_error(get_name(), $sformatf(
        "Expected one compared transfer, got %0d",
        tb_env.scoreboard0.number_of_compared
      ))
    end

    this.clk_delay(2);

    if (response_seq.seen_tid != 0 || response_seq.seen_tdest != 0) begin
      `uvm_error(get_name(), $sformatf(
        "Unexpected packet-start request tid=%0d tdest=%0d",
        response_seq.seen_tid,
        response_seq.seen_tdest
      ))
    end

    if (second_beat_stall_cycles < 3) begin
      `uvm_error(get_name(), $sformatf(
        "Expected at least 3 second-beat stall cycles, got %0d",
        second_beat_stall_cycles
      ))
    end

    if (tb_env.scoreboard0.number_of_failed != 0) begin
      `uvm_error(get_name(), "Active slave response test should not create scoreboard mismatches")
    end

    `uvm_info(get_name(), "Done!", UVM_LOW)
    phase.drop_objection(this);
  endtask

  task count_second_beat_stalls();
    int handshakes;

    handshakes = 0;
    second_beat_stall_cycles = 0;
    while (handshakes < 3) begin
      @(posedge clk_vif.clk);
      #1;
      if ((mst_vif.tvalid === 1'b1) && (mst_vif.tready !== 1'b1) && (mst_vif.tdata == 32'h0000_0001)) begin
        second_beat_stall_cycles++;
      end
      if ((mst_vif.tvalid === 1'b1) && (mst_vif.tready === 1'b1)) begin
        handshakes++;
      end
    end
  endtask
endclass
