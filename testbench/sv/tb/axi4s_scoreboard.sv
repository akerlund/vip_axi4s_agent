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

  localparam int TDATA_BYTES_C = VIP_AXI4S_CFG_C.VIP_AXI4S_TDATA_BYTES_P;

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

  bit byte_exact_compare = 1'b0;

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
    void'(uvm_config_db #(bit)::get(this, "", "byte_exact_compare", byte_exact_compare));
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

    current_phase = phase;
    super.check_phase(current_phase);

    this.compare_ready_items();

    if (mst_items.size() || slv_items.size()) begin
      number_of_failed += mst_items.size() + slv_items.size();
      `uvm_error(get_name(), $sformatf(
        "Unmatched packets: mst=%0d slv=%0d",
        mst_items.size(),
        slv_items.size()
      ))
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
  virtual function void compare_ready_items();

    vip_axi4s_item #(VIP_AXI4S_CFG_C) mst_item;
    vip_axi4s_item #(VIP_AXI4S_CFG_C) slv_item;

    while (mst_items.size() && slv_items.size()) begin
      mst_item = mst_items.pop_front();
      slv_item = slv_items.pop_front();
      if (mst_item == null) begin `uvm_fatal(get_name(), $sformatf("Fetched mst_item NULL object")) end
      if (slv_item == null) begin `uvm_fatal(get_name(), $sformatf("Fetched slv_item NULL object")) end
      begin
        string mismatch;
        if (!this.compare_items(mst_item, slv_item, mismatch)) begin
          number_of_failed++;
          `uvm_error(get_name(), $sformatf(
            "compare_read1: Packet number (%0d) mismatches: %s",
            number_of_compared,
            mismatch
          ))
        end else begin
          number_of_passed++;
        end
      end
      number_of_compared++;
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
  //
  //----------------------------------------------------------------------------
  virtual function bit compare_items(
    input vip_axi4s_item #(VIP_AXI4S_CFG_C) mst_item,
    input vip_axi4s_item #(VIP_AXI4S_CFG_C) slv_item,
    output string mismatch
  );

    if (byte_exact_compare) begin
      return this.compare_items_byte_exact(mst_item, slv_item, mismatch);
    end

    return this.compare_items_qualified(mst_item, slv_item, mismatch);
  endfunction

  //----------------------------------------------------------------------------
  //
  //----------------------------------------------------------------------------
  protected function bit compare_items_byte_exact(
    input vip_axi4s_item #(VIP_AXI4S_CFG_C) mst_item,
    input vip_axi4s_item #(VIP_AXI4S_CFG_C) slv_item,
    output string mismatch
  );

    mismatch = "";

    if (mst_item.tid !== slv_item.tid) begin
      mismatch = $sformatf("TID mismatch mst=0x%0h slv=0x%0h", mst_item.tid, slv_item.tid);
      return 1'b0;
    end
    if (mst_item.tdest !== slv_item.tdest) begin
      mismatch = $sformatf("TDEST mismatch mst=0x%0h slv=0x%0h", mst_item.tdest, slv_item.tdest);
      return 1'b0;
    end
    if (mst_item.tdata.size() != slv_item.tdata.size()) begin
      mismatch = $sformatf("TDATA size mismatch mst=%0d slv=%0d", mst_item.tdata.size(), slv_item.tdata.size());
      return 1'b0;
    end
    if ((mst_item.tstrb.size() != slv_item.tstrb.size()) ||
        (mst_item.tkeep.size() != slv_item.tkeep.size()) ||
        (mst_item.tuser.size() != slv_item.tuser.size())) begin
      mismatch = "qualifier or TUSER array size mismatch";
      return 1'b0;
    end

    foreach (mst_item.tdata[beat]) begin
      if (mst_item.tdata[beat] !== slv_item.tdata[beat]) begin
        mismatch = $sformatf(
          "TDATA[%0d] mismatch mst=0x%0h slv=0x%0h",
          beat,
          mst_item.tdata[beat],
          slv_item.tdata[beat]
        );
        return 1'b0;
      end
      if (mst_item.tstrb[beat] !== slv_item.tstrb[beat]) begin
        mismatch = $sformatf(
          "TSTRB[%0d] mismatch mst=0x%0h slv=0x%0h",
          beat,
          mst_item.tstrb[beat],
          slv_item.tstrb[beat]
        );
        return 1'b0;
      end
      if (mst_item.tkeep[beat] !== slv_item.tkeep[beat]) begin
        mismatch = $sformatf(
          "TKEEP[%0d] mismatch mst=0x%0h slv=0x%0h",
          beat,
          mst_item.tkeep[beat],
          slv_item.tkeep[beat]
        );
        return 1'b0;
      end
      if (mst_item.tuser[beat] !== slv_item.tuser[beat]) begin
        mismatch = $sformatf(
          "TUSER[%0d] mismatch mst=0x%0h slv=0x%0h",
          beat,
          mst_item.tuser[beat],
          slv_item.tuser[beat]
        );
        return 1'b0;
      end
    end

    return 1'b1;
  endfunction

  //----------------------------------------------------------------------------
  //
  //----------------------------------------------------------------------------
  protected function bit compare_items_qualified(
    input vip_axi4s_item #(VIP_AXI4S_CFG_C) mst_item,
    input vip_axi4s_item #(VIP_AXI4S_CFG_C) slv_item,
    output string mismatch
  );

    mismatch = "";

    if (mst_item.tid !== slv_item.tid) begin
      mismatch = $sformatf("TID mismatch mst=0x%0h slv=0x%0h", mst_item.tid, slv_item.tid);
      return 1'b0;
    end
    if (mst_item.tdest !== slv_item.tdest) begin
      mismatch = $sformatf("TDEST mismatch mst=0x%0h slv=0x%0h", mst_item.tdest, slv_item.tdest);
      return 1'b0;
    end
    if (mst_item.tdata.size() != slv_item.tdata.size()) begin
      mismatch = $sformatf("TDATA size mismatch mst=%0d slv=%0d", mst_item.tdata.size(), slv_item.tdata.size());
      return 1'b0;
    end
    if ((mst_item.tstrb.size() != slv_item.tstrb.size()) ||
        (mst_item.tkeep.size() != slv_item.tkeep.size()) ||
        (mst_item.tuser.size() != slv_item.tuser.size())) begin
      mismatch = "qualifier or TUSER array size mismatch";
      return 1'b0;
    end

    foreach (mst_item.tdata[beat]) begin
      if (mst_item.tstrb[beat] !== slv_item.tstrb[beat]) begin
        mismatch = $sformatf(
          "TSTRB[%0d] mismatch mst=0x%0h slv=0x%0h",
          beat,
          mst_item.tstrb[beat],
          slv_item.tstrb[beat]
        );
        return 1'b0;
      end
      if (mst_item.tkeep[beat] !== slv_item.tkeep[beat]) begin
        mismatch = $sformatf(
          "TKEEP[%0d] mismatch mst=0x%0h slv=0x%0h",
          beat,
          mst_item.tkeep[beat],
          slv_item.tkeep[beat]
        );
        return 1'b0;
      end
      if (mst_item.tuser[beat] !== slv_item.tuser[beat]) begin
        mismatch = $sformatf(
          "TUSER[%0d] mismatch mst=0x%0h slv=0x%0h",
          beat,
          mst_item.tuser[beat],
          slv_item.tuser[beat]
        );
        return 1'b0;
      end

      for (int lane = 0; lane < TDATA_BYTES_C; lane++) begin
        if (mst_item.tkeep[beat][lane] && mst_item.tstrb[beat][lane]) begin
          if (mst_item.tdata[beat][8*lane +: 8] !== slv_item.tdata[beat][8*lane +: 8]) begin
            mismatch = $sformatf(
              "TDATA[%0d] byte %0d mismatch mst=0x%0h slv=0x%0h",
              beat,
              lane,
              mst_item.tdata[beat][8*lane +: 8],
              slv_item.tdata[beat][8*lane +: 8]
            );
            return 1'b0;
          end
        end
      end
    end

    return 1'b1;
  endfunction

  //----------------------------------------------------------------------------
  // Master Agent
  //----------------------------------------------------------------------------
  virtual function void write_mst_port(vip_axi4s_item #(VIP_AXI4S_CFG_C) trans);
    number_of_mst_items++;
    mst_items.push_back(trans);
    this.compare_ready_items();
  endfunction

  //----------------------------------------------------------------------------
  // Slave Agent
  //----------------------------------------------------------------------------
  virtual function void write_slv_port(vip_axi4s_item #(VIP_AXI4S_CFG_C) trans);
    number_of_slv_items++;
    slv_items.push_back(trans);
    this.compare_ready_items();
  endfunction

endclass
