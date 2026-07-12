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

class tc_axi4s_backpressure extends axi4s_base_test;

  `uvm_component_utils(tc_axi4s_backpressure)

  function new(string name = "tc_axi4s_backpressure", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    axi4s_mst_cfg0.tvalid_delay_gauss_enabled = FALSE;
    axi4s_mst_cfg0.min_tvalid_delay_period    = 1;
    axi4s_mst_cfg0.max_tvalid_delay_period    = 3;
    axi4s_mst_cfg0.min_tvalid_delay_time      = 1;
    axi4s_mst_cfg0.max_tvalid_delay_time      = 2;

    axi4s_slv_cfg0.tready_delay_gauss_enabled = FALSE;
    axi4s_slv_cfg0.min_tready_delay_period    = 1;
    axi4s_slv_cfg0.max_tready_delay_period    = 2;
    axi4s_slv_cfg0.min_tready_delay_time      = 3;
    axi4s_slv_cfg0.max_tready_delay_time      = 6;
  endfunction

  task run_phase(uvm_phase phase);

    logic [31:0] custom_tdata [$];

    super.run_phase(phase);
    phase.raise_objection(this);

    for (int i = 0; i < 32; i++) begin
      custom_tdata.push_back(32'hca50_0000 + i);
    end

    vip_axi4s_seq0.set_verbose(FALSE);
    vip_axi4s_seq0.set_tdata_type(VIP_AXI4S_TDATA_CUSTOM_E);
    vip_axi4s_seq0.set_tdata(custom_tdata);
    vip_axi4s_seq0.set_tstrb_type(VIP_AXI4S_TSTRB_RANDOM_E);
    vip_axi4s_seq0.start(v_sqr.mst_sequencer);

    vip_axi4s_seq0.set_verbose(TRUE);
    vip_axi4s_seq0.set_nr_of_bursts(8);
    vip_axi4s_seq0.set_tdata_type(VIP_AXI4S_TDATA_COUNTER_E);
    vip_axi4s_seq0.set_burst_length(9);
    vip_axi4s_seq0.set_tstrb_type(VIP_AXI4S_TSTRB_RANDOM_E);
    vip_axi4s_seq0.start(v_sqr.mst_sequencer);

    `uvm_info(get_name(), $sformatf("Done!"), UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
