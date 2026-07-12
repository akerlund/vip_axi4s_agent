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

`uvm_analysis_imp_decl(_mst_port)
`uvm_analysis_imp_decl(_slv_port)

class axi4s_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(axi4s_scoreboard)

  // Master (Write) Agent
  uvm_analysis_imp_mst_port #(vip_axi4s_item #(VIP_AXI4S_CFG_C), axi4s_scoreboard) mst_port;
  uvm_analysis_imp_slv_port #(vip_axi4s_item #(VIP_AXI4S_CFG_C), axi4s_scoreboard) slv_port;

  // Storage for comparison
  vip_axi4s_item #(VIP_AXI4S_CFG_C) mst_items [$];
  vip_axi4s_item #(VIP_AXI4S_CFG_C) slv_items [$];
  // For raising objections
  uvm_phase current_phase;

  // Transaction counters
  int number_of_mst_items = 0;
  int number_of_slv_items = 0;

  // Test counters
  int number_of_compared    = 0;
  int number_of_passed      = 0;
  int number_of_failed      = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mst_port = new("mst_port", this);
    slv_port = new("slv_port", this);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void start_of_simulation_phase(uvm_phase phase);
    current_phase = phase;
    super.start_of_simulation_phase(phase);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);
    current_phase = phase;
    super.connect_phase(current_phase);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    current_phase = phase;
    super.run_phase(current_phase);
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void check_phase(uvm_phase phase);

    vip_axi4s_item #(VIP_AXI4S_CFG_C) mst_item;
    vip_axi4s_item #(VIP_AXI4S_CFG_C) slv_item;

    current_phase = phase;
    super.check_phase(current_phase);

    while (mst_items.size()) begin
      mst_item = mst_items.pop_front();
      slv_item = slv_items.pop_front();
      if (mst_item == null) begin `uvm_fatal(get_name(), $sformatf("Fetched mst_item NULL object")) end
      if (slv_item == null) begin `uvm_fatal(get_name(), $sformatf("Fetched slv_item NULL object")) end
      if (!mst_item.compare(slv_item)) begin
        number_of_failed++;
        `uvm_error(get_name(), $sformatf("compare_read1: Packet number (%0d) mismatches", number_of_compared))
      end else begin
        number_of_passed++;
      end
      number_of_compared++;
    end

    if (number_of_failed != 0) begin
      `uvm_error(get_name(), $sformatf("Test failed! (%0d) mismatches", number_of_failed))
    end
    else begin
      `uvm_info(get_name(), $sformatf("Test passed (%0d/%0d) finished transfers", number_of_passed, number_of_compared), UVM_LOW)
    end

  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  virtual function void handle_reset();
    mst_items.delete();
    slv_items.delete();
  endfunction

  //----------------------------------------------------------------------------
  // Master Agent
  //----------------------------------------------------------------------------
  virtual function void write_mst_port(vip_axi4s_item #(VIP_AXI4S_CFG_C) trans);
    number_of_mst_items++;
    mst_items.push_back(trans);
  endfunction

  //----------------------------------------------------------------------------
  // Slave Agent
  //----------------------------------------------------------------------------
  virtual function void write_slv_port(vip_axi4s_item #(VIP_AXI4S_CFG_C) trans);
    number_of_slv_items++;
    slv_items.push_back(trans);
  endfunction

endclass
