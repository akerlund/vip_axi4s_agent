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

class tc_axi4s_optional_extras extends axi4s_base_test;

  `uvm_component_utils(tc_axi4s_optional_extras)

  function new(string name = "tc_axi4s_optional_extras", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    axi4s_mst_cfg0.zero_delays_enable = TRUE;
    axi4s_slv_cfg0.zero_delays_enable = TRUE;

    axi4s_mst_cfg0.trace_enable = 1'b1;
    axi4s_mst_cfg0.trace_format = "jsonl";
    axi4s_mst_cfg0.trace_path = "axi4s_optional_mst.jsonl";
    axi4s_mst_cfg0.performance_enable = 1'b1;
    axi4s_mst_cfg0.drive_idle_values_enable = 1'b1;
    axi4s_mst_cfg0.idle_tdata = 32'hdead_beef;
    axi4s_mst_cfg0.idle_tstrb = '0;
    axi4s_mst_cfg0.idle_tkeep = '0;
    axi4s_mst_cfg0.idle_tlast = 1'b0;
    axi4s_mst_cfg0.idle_tid = '0;
    axi4s_mst_cfg0.idle_tdest = '0;
    axi4s_mst_cfg0.idle_tuser = '0;
    axi4s_mst_cfg0.tlast_idle_toggle_enable = 1'b1;
    axi4s_mst_cfg0.tdata_only_fast_path_enable = 1'b1;

    axi4s_slv_cfg0.trace_enable = 1'b1;
    axi4s_slv_cfg0.trace_format = "jsonl";
    axi4s_slv_cfg0.trace_path = "axi4s_optional_slv.jsonl";
    axi4s_slv_cfg0.performance_enable = 1'b1;
    axi4s_slv_cfg0.tready_idle_toggle_enable = 1'b1;
  endfunction

  task run_phase(uvm_phase phase);

    logic [31:0]  custom_tdata [$];
    int unsigned  tvalid_delay [$];

    super.run_phase(phase);
    phase.raise_objection(this);

    custom_tdata.push_back(32'h1000_0000);
    custom_tdata.push_back(32'h1000_0001);
    custom_tdata.push_back(32'h1000_0002);
    tvalid_delay.push_back(0);
    tvalid_delay.push_back(0);
    tvalid_delay.push_back(0);

    vip_axi4s_seq0.set_verbose(FALSE);
    vip_axi4s_seq0.set_tdata_type(VIP_AXI4S_TDATA_CUSTOM_E);
    vip_axi4s_seq0.set_tdata(custom_tdata);
    vip_axi4s_seq0.set_tstrb_type(VIP_AXI4S_TSTRB_ALL_E);
    vip_axi4s_seq0.set_tvalid_delay(tvalid_delay);
    vip_axi4s_seq0.start(v_sqr.mst_sequencer);

    for (int i = 0; i < 1000 && tb_env.scoreboard0.number_of_compared < 1; i++) begin
      this.clk_delay(1);
    end

    if (tb_env.scoreboard0.number_of_failed != 0) begin
      `uvm_error(get_name(), "Optional extras transfer should pass scoreboard compare")
    end
    if (axi4s_mst_cfg0.get_performance_beats() < 3) begin
      `uvm_error(get_name(), "Master performance counters did not record three beats")
    end
    if (axi4s_slv_cfg0.get_performance_packets() < 1) begin
      `uvm_error(get_name(), "Slave performance counters did not record one packet")
    end
    if (axi4s_mst_cfg0.get_performance_data_bytes() < 12) begin
      `uvm_error(get_name(), "Master performance counters did not record data bytes")
    end

    this.check_trace_file("axi4s_optional_mst.jsonl");
    this.check_trace_file("axi4s_optional_slv.jsonl");

    `uvm_info(get_name(), "Done!", UVM_LOW)
    phase.drop_objection(this);
  endtask

  function void check_trace_file(input string path);
    int    fd;
    string line;
    bit    saw_beat;
    bit    saw_packet;

    fd = $fopen(path, "r");
    if (fd == 0) begin
      `uvm_error(get_name(), $sformatf("Failed to open trace file '%s'", path))
      return;
    end

    while (!$feof(fd)) begin
      void'($fgets(line, fd));
      if (this.string_contains(line, "\"event\":\"beat\"")) begin
        saw_beat = 1'b1;
      end
      if (this.string_contains(line, "\"event\":\"packet\"")) begin
        saw_packet = 1'b1;
      end
    end
    $fclose(fd);

    if (!saw_beat || !saw_packet) begin
      `uvm_error(get_name(), $sformatf(
        "Trace file '%s' did not contain both beat and packet events",
        path
      ))
    end
  endfunction

  function bit string_contains(input string text, input string needle);
    if (needle.len() == 0) begin
      return 1'b1;
    end
    if (text.len() < needle.len()) begin
      return 1'b0;
    end
    for (int i = 0; i <= text.len() - needle.len(); i++) begin
      if (text.substr(i, i + needle.len() - 1) == needle) begin
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction
endclass
