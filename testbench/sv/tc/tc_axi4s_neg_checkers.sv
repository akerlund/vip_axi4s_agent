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

class axi4s_neg_base_test extends axi4s_base_test;

  virtual clk_rst_if                      clk_vif;
  virtual vip_axi4s_if #(VIP_AXI4S_CFG_C) mst_vif;
  virtual vip_axi4s_if #(VIP_AXI4S_CFG_C) slv_vif;

  `uvm_component_utils(axi4s_neg_base_test)

  function new(string name = "axi4s_neg_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    axi4s_mst_cfg0.is_active = UVM_PASSIVE;
    axi4s_slv_cfg0.is_active = UVM_PASSIVE;

    for (int i = 0; i < int'(VIP_AXI4S_CHECK_NUM_E); i++) begin
      vip_axi4s_check_t check;
      void'($cast(check, i));
      axi4s_mst_cfg0.set_check_severity(check, UVM_WARNING);
      axi4s_slv_cfg0.set_check_severity(check, UVM_WARNING);
    end

    if (!uvm_config_db #(virtual clk_rst_if)::get(this, "tb_env", "vif", clk_vif)) begin
      `uvm_fatal(get_name(), "Failed to get clk_rst_if")
    end

    if (!uvm_config_db #(virtual vip_axi4s_if #(VIP_AXI4S_CFG_C))::get(this, "tb_env.mst_agent0", "vif", mst_vif)) begin
      `uvm_fatal(get_name(), "Failed to get mst AXI4S vif")
    end

    if (!uvm_config_db #(virtual vip_axi4s_if #(VIP_AXI4S_CFG_C))::get(this, "tb_env.slv_agent0", "vif", slv_vif)) begin
      `uvm_fatal(get_name(), "Failed to get slv AXI4S vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    this.park_bus();
    super.run_phase(phase);
    phase.raise_objection(this);
    this.park_bus();
    this.clk_delay(2);
    this.run_negative_body();
    this.clk_delay(3);
    phase.drop_objection(this);
  endtask

  virtual task run_negative_body();
  endtask

  task park_bus();
    mst_vif.tvalid <= 1'b0;
    mst_vif.tdata  <= '0;
    mst_vif.tstrb  <= '0;
    mst_vif.tkeep  <= '0;
    mst_vif.tlast  <= 1'b0;
    mst_vif.tid    <= '0;
    mst_vif.tdest  <= '0;
    mst_vif.tuser  <= '0;
    slv_vif.tready <= 1'b0;
  endtask

  task drive_beat(
    input logic [31:0] tdata,
    input logic  [3:0] tstrb,
    input logic  [3:0] tkeep,
    input logic        tlast,
    input logic [10:0] tid,
    input logic        tdest,
    input logic        tuser,
    input logic        tready = 1'b1
  );
    mst_vif.tvalid <= 1'b1;
    mst_vif.tdata  <= tdata;
    mst_vif.tstrb  <= tstrb;
    mst_vif.tkeep  <= tkeep;
    mst_vif.tlast  <= tlast;
    mst_vif.tid    <= tid;
    mst_vif.tdest  <= tdest;
    mst_vif.tuser  <= tuser;
    slv_vif.tready <= tready;
    @(posedge clk_vif.clk);
    #1;
  endtask

  function int unsigned total_violations(input vip_axi4s_check_t check);
    return axi4s_mst_cfg0.get_check_violations(check) +
           axi4s_slv_cfg0.get_check_violations(check);
  endfunction

  function void expect_violation(input vip_axi4s_check_t check);
    if (this.total_violations(check) == 0) begin
      `uvm_error(get_name(), $sformatf("Expected violation for %s", vip_axi4s_check_name(check)))
    end
  endfunction

  function void expect_no_violation(input vip_axi4s_check_t check);
    if (this.total_violations(check) != 0) begin
      `uvm_error(get_name(), $sformatf(
        "Unexpected violation for %s (%0d)",
        vip_axi4s_check_name(check),
        this.total_violations(check)
      ))
    end
  endfunction
endclass

class tc_axi4s_neg_xz extends axi4s_neg_base_test;

  `uvm_component_utils(tc_axi4s_neg_xz)

  function new(string name = "tc_axi4s_neg_xz", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_negative_body();
    mst_vif.tvalid <= 1'bx;
    slv_vif.tready <= 1'b1;
    @(posedge clk_vif.clk);
    #1;

    mst_vif.tvalid <= 1'b1;
    slv_vif.tready <= 1'bx;
    mst_vif.tdata  <= 'x;
    mst_vif.tstrb  <= 'x;
    mst_vif.tkeep  <= 'x;
    mst_vif.tlast  <= 1'bx;
    mst_vif.tid    <= 'x;
    mst_vif.tdest  <= 'x;
    mst_vif.tuser  <= 'x;
    @(posedge clk_vif.clk);
    #1;

    this.park_bus();
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_VALID_TVALID_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_VALID_TSTRB_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_VALID_TKEEP_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_VALID_TLAST_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_VALID_TID_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_VALID_TDEST_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_VALID_TUSER_WHEN_TVALID_HIGH_E);
  endtask
endclass

class tc_axi4s_neg_stability extends axi4s_neg_base_test;

  `uvm_component_utils(tc_axi4s_neg_stability)

  function new(string name = "tc_axi4s_neg_stability", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_negative_body();
    this.drive_beat(32'h1111_0000, 4'hf, 4'hf, 1'b0, 11'h1, 1'b0, 1'b0, 1'b0);

    mst_vif.tdata  <= 32'h2222_0000;
    mst_vif.tstrb  <= 4'he;
    mst_vif.tkeep  <= 4'h7;
    mst_vif.tlast  <= 1'b1;
    mst_vif.tid    <= 11'h2;
    mst_vif.tdest  <= 1'b1;
    mst_vif.tuser  <= 1'b1;
    @(posedge clk_vif.clk);
    #1;

    this.park_bus();
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_STABLE_TSTRB_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_STABLE_TKEEP_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_STABLE_TLAST_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_STABLE_TID_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_STABLE_TDEST_WHEN_TVALID_HIGH_E);
    this.expect_violation(VIP_AXI4S_CHECK_SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH_E);
  endtask
endclass

class tc_axi4s_neg_tvalid_drop extends axi4s_neg_base_test;

  `uvm_component_utils(tc_axi4s_neg_tvalid_drop)

  function new(string name = "tc_axi4s_neg_tvalid_drop", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_negative_body();
    this.drive_beat(32'h3333_0000, 4'hf, 4'hf, 1'b0, 11'h3, 1'b0, 1'b0, 1'b0);
    mst_vif.tvalid <= 1'b0;
    @(posedge clk_vif.clk);
    #1;

    this.park_bus();
    this.expect_violation(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E);
  endtask
endclass

class tc_axi4s_neg_reset extends axi4s_neg_base_test;

  `uvm_component_utils(tc_axi4s_neg_reset)

  function new(string name = "tc_axi4s_neg_reset", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_negative_body();
    this.drive_beat(32'h4444_0000, 4'hf, 4'hf, 1'b0, 11'h4, 1'b0, 1'b0, 1'b1);

    mst_vif.tvalid <= 1'b1;
    clk_vif.rst    <= 1'b1;
    clk_vif.rst_n  <= 1'b0;
    @(posedge clk_vif.clk);
    #1;

    this.park_bus();
    @(posedge clk_vif.clk);
    #1;
    clk_vif.rst   <= 1'b0;
    clk_vif.rst_n <= 1'b1;
    this.clk_delay(2);

    this.expect_violation(VIP_AXI4S_CHECK_TVALID_LOW_WHEN_RESET_IS_ACTIVE_E);
    this.expect_violation(VIP_AXI4S_CHECK_PACKET_TRUNCATED_BY_RESET_E);
  endtask
endclass

class tc_axi4s_neg_byte_qualifier extends axi4s_neg_base_test;

  `uvm_component_utils(tc_axi4s_neg_byte_qualifier)

  function new(string name = "tc_axi4s_neg_byte_qualifier", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_negative_body();
    this.drive_beat(32'h5555_0000, 4'hf, 4'ha, 1'b1, 11'h5, 1'b0, 1'b0, 1'b1);
    this.park_bus();
    this.expect_violation(VIP_AXI4S_CHECK_TSTRB_LOW_WHEN_TKEEP_LOW_E);
  endtask
endclass

class tc_axi4s_neg_packet_boundary extends axi4s_neg_base_test;

  `uvm_component_utils(tc_axi4s_neg_packet_boundary)

  function new(string name = "tc_axi4s_neg_packet_boundary", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_negative_body();
    this.drive_beat(32'h6666_0000, 4'hf, 4'hf, 1'b0, 11'h6, 1'b0, 1'b0, 1'b1);
    this.drive_beat(32'h6666_0001, 4'hf, 4'hf, 1'b1, 11'h7, 1'b1, 1'b0, 1'b1);
    this.park_bus();
    this.expect_violation(VIP_AXI4S_CHECK_TID_OR_TDEST_CHANGE_BEFORE_TLAST_E);
  endtask
endclass

class tc_axi4s_neg_max_length extends axi4s_neg_base_test;

  `uvm_component_utils(tc_axi4s_neg_max_length)

  function new(string name = "tc_axi4s_neg_max_length", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axi4s_mst_cfg0.max_stream_burst_length = 1;
    axi4s_slv_cfg0.max_stream_burst_length = 1;
  endfunction

  task run_negative_body();
    this.drive_beat(32'h7777_0000, 4'hf, 4'hf, 1'b0, 11'h7, 1'b0, 1'b0, 1'b1);
    this.drive_beat(32'h7777_0001, 4'hf, 4'hf, 1'b1, 11'h7, 1'b0, 1'b0, 1'b1);
    this.park_bus();
    this.expect_violation(VIP_AXI4S_CHECK_MAX_STREAM_BURST_LENGTH_EXCEEDED_E);
  endtask
endclass

class tc_axi4s_neg_stream_tracking extends axi4s_neg_base_test;

  `uvm_component_utils(tc_axi4s_neg_stream_tracking)

  function new(string name = "tc_axi4s_neg_stream_tracking", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axi4s_mst_cfg0.stream_interleave_depth = 1;
    axi4s_slv_cfg0.stream_interleave_depth = 1;
    axi4s_mst_cfg0.single_outstanding_per_tdest_enable = 1'b1;
    axi4s_slv_cfg0.single_outstanding_per_tdest_enable = 1'b1;
  endfunction

  task run_negative_body();
    this.drive_beat(32'h9999_0000, 4'hf, 4'hf, 1'b0, 11'h1, 1'b1, 1'b0, 1'b1);
    this.drive_beat(32'haaaa_0000, 4'hf, 4'hf, 1'b0, 11'h2, 1'b1, 1'b0, 1'b1);
    this.drive_beat(32'haaaa_0001, 4'hf, 4'hf, 1'b1, 11'h2, 1'b1, 1'b0, 1'b1);
    this.drive_beat(32'h9999_0001, 4'hf, 4'hf, 1'b1, 11'h1, 1'b1, 1'b0, 1'b1);
    this.park_bus();
    this.expect_violation(VIP_AXI4S_CHECK_STREAM_INTERLEAVE_DEPTH_EXCEEDED_E);
    this.expect_violation(VIP_AXI4S_CHECK_SINGLE_OUTSTANDING_PER_TDEST_E);

    // With interleaving not permitted, switching stream mid packet is also a
    // TID/TDEST change before TLAST
    this.expect_violation(VIP_AXI4S_CHECK_TID_OR_TDEST_CHANGE_BEFORE_TLAST_E);
  endtask
endclass

// An active master must still check the legality of its own stimulus. Signal
// integrity checks stay suppressed there, because the agent would only be
// checking its own driver, but the stream tracking checks are the only
// protocol checking a master-only environment ever gets
class tc_axi4s_master_self_check extends axi4s_base_test;

  `uvm_component_utils(tc_axi4s_master_self_check)

  function new(string name = "tc_axi4s_master_self_check", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    axi4s_mst_cfg0.zero_delays_enable = TRUE;
    axi4s_slv_cfg0.zero_delays_enable = TRUE;
    axi4s_mst_cfg0.max_stream_burst_length = 4;
    axi4s_mst_cfg0.set_check_severity(
      VIP_AXI4S_CHECK_MAX_STREAM_BURST_LENGTH_EXCEEDED_E, UVM_WARNING);
    axi4s_slv_cfg0.set_check_severity(
      VIP_AXI4S_CHECK_MAX_STREAM_BURST_LENGTH_EXCEEDED_E, UVM_WARNING);
  endfunction

  task run_phase(uvm_phase phase);

    logic [31:0] custom_tdata [$];

    super.run_phase(phase);
    phase.raise_objection(this);

    for (int i = 0; i < 8; i++) begin
      custom_tdata.push_back(32'h1000_0000 + i);
    end

    vip_axi4s_seq0.set_verbose(FALSE);
    vip_axi4s_seq0.set_tdata_type(VIP_AXI4S_TDATA_CUSTOM_E);
    vip_axi4s_seq0.set_tdata(custom_tdata);
    vip_axi4s_seq0.start(v_sqr.mst_sequencer);

    for (int i = 0; i < 1000 && tb_env.scoreboard0.number_of_compared < 1; i++) begin
      this.clk_delay(1);
    end

    // The eight beat packet exceeds the master's max_stream_burst_length of 4
    if (axi4s_mst_cfg0.get_check_violations(
        VIP_AXI4S_CHECK_MAX_STREAM_BURST_LENGTH_EXCEEDED_E) == 0) begin

      `uvm_error(get_name(), $sformatf(
      "ERROR [%s] The active master did not check its own stimulus length",
      get_name()))
    end

    // A signal the master drives itself is still not re-checked by it, and the
    // statistics must show that as suppressed rather than as executed
    if (axi4s_mst_cfg0.get_check_suppressed(
        VIP_AXI4S_CHECK_SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH_E) == 0) begin

      `uvm_error(get_name(), $sformatf(
      "ERROR [%s] The master did not record its locally driven checks as suppressed",
      get_name()))
    end

    if (axi4s_mst_cfg0.get_check_executed(
        VIP_AXI4S_CHECK_SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH_E) != 0) begin

      `uvm_error(get_name(), $sformatf(
      "ERROR [%s] The master re-checked a signal it drives itself",
      get_name()))
    end

    // The slave agent observes the same signal and does check it
    if (axi4s_slv_cfg0.get_check_executed(
        VIP_AXI4S_CHECK_SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH_E) == 0) begin

      `uvm_error(get_name(), $sformatf(
      "ERROR [%s] The slave agent did not check the master driven TDATA",
      get_name()))
    end

    `uvm_info(get_name(), "Done!", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// Interleaved observation is legal once stream_interleave_depth allows it
class tc_axi4s_interleaved_streams extends axi4s_neg_base_test;

  `uvm_component_utils(tc_axi4s_interleaved_streams)

  function new(string name = "tc_axi4s_interleaved_streams", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axi4s_mst_cfg0.stream_interleave_depth = 2;
    axi4s_slv_cfg0.stream_interleave_depth = 2;
  endfunction

  task run_negative_body();
    this.drive_beat(32'h9999_0000, 4'hf, 4'hf, 1'b0, 11'h1, 1'b0, 1'b0, 1'b1);
    this.drive_beat(32'haaaa_0000, 4'hf, 4'hf, 1'b0, 11'h2, 1'b0, 1'b0, 1'b1);
    this.drive_beat(32'haaaa_0001, 4'hf, 4'hf, 1'b1, 11'h2, 1'b0, 1'b0, 1'b1);
    this.drive_beat(32'h9999_0001, 4'hf, 4'hf, 1'b1, 11'h1, 1'b0, 1'b0, 1'b1);
    this.park_bus();
    this.clk_delay(2);

    this.expect_no_violation(VIP_AXI4S_CHECK_TID_OR_TDEST_CHANGE_BEFORE_TLAST_E);
    this.expect_no_violation(VIP_AXI4S_CHECK_STREAM_INTERLEAVE_DEPTH_EXCEEDED_E);
    this.expect_no_violation(VIP_AXI4S_CHECK_PACKET_TRUNCATED_BY_RESET_E);
  endtask
endclass

class tc_axi4s_neg_disable_controls extends axi4s_neg_base_test;

  `uvm_component_utils(tc_axi4s_neg_disable_controls)

  function new(string name = "tc_axi4s_neg_disable_controls", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_negative_body();
    int unsigned before_count;

    axi4s_mst_cfg0.protocol_checks_enable = 1'b0;
    axi4s_slv_cfg0.protocol_checks_enable = 1'b0;
    before_count = this.total_violations(VIP_AXI4S_CHECK_TSTRB_LOW_WHEN_TKEEP_LOW_E);
    this.drive_beat(32'h8888_0000, 4'hf, 4'h0, 1'b1, 11'h8, 1'b0, 1'b0, 1'b1);
    this.park_bus();
    this.clk_delay(2);
    if (this.total_violations(VIP_AXI4S_CHECK_TSTRB_LOW_WHEN_TKEEP_LOW_E) != before_count) begin
      `uvm_error(get_name(), "protocol_checks_enable failed to silence TSTRB/TKEEP check")
    end

    axi4s_mst_cfg0.protocol_checks_enable = 1'b1;
    axi4s_slv_cfg0.protocol_checks_enable = 1'b1;
    axi4s_mst_cfg0.set_check_enable(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E, 1'b0);
    axi4s_slv_cfg0.set_check_enable(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E, 1'b0);
    before_count = this.total_violations(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E);
    this.drive_beat(32'h8888_0001, 4'hf, 4'hf, 1'b0, 11'h8, 1'b0, 1'b0, 1'b0);
    mst_vif.tvalid <= 1'b0;
    @(posedge clk_vif.clk);
    #1;
    this.park_bus();
    this.clk_delay(2);
    if (this.total_violations(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E) != before_count) begin
      `uvm_error(get_name(), "set_check_enable failed to silence TVALID interrupted check")
    end

    axi4s_mst_cfg0.set_check_enable(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E, 1'b1);
    axi4s_slv_cfg0.set_check_enable(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E, 1'b1);
    axi4s_mst_cfg0.set_check_severity(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E, UVM_INFO);
    axi4s_slv_cfg0.set_check_severity(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E, UVM_INFO);
    before_count = this.total_violations(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E);
    this.drive_beat(32'h8888_0002, 4'hf, 4'hf, 1'b0, 11'h8, 1'b0, 1'b0, 1'b0);
    mst_vif.tvalid <= 1'b0;
    @(posedge clk_vif.clk);
    #1;
    this.park_bus();
    this.clk_delay(2);
    if (this.total_violations(VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E) <= before_count) begin
      `uvm_error(get_name(), "Severity demotion check did not record TVALID interrupted violation")
    end
  endtask
endclass
