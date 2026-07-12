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

class vip_axi4s_driver #(
  vip_axi4s_cfg_t CFG_P = '{default: '0}
  ) extends uvm_driver #(vip_axi4s_item #(CFG_P));

  protected virtual vip_axi4s_if #(CFG_P) _vif;
  protected int                           _id;
  vip_axi4s_config                        cfg;


  `uvm_component_param_utils_begin(vip_axi4s_driver #(CFG_P))
    `uvm_field_int(_id, UVM_DEFAULT)
  `uvm_component_utils_end

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    // Fatal check: VIF
    if (!uvm_config_db #(virtual vip_axi4s_if #(CFG_P))::get(this, "", "vif", _vif)) begin

      `uvm_fatal(get_name(), $sformatf(
      "FATAL [%s] Virtual interface must be set for: %s.vif",
      get_name(), get_full_name()))
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);

    forever begin

      fork

        begin

          @(posedge _vif.rst_n);
          this.driver_start();
        end
      join_none

      @(negedge _vif.rst_n);
      disable fork;
      this.reset_vif();
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  task driver_start();

    if (cfg.vip_axi4s_agent_type == VIP_AXI4S_MASTER_AGENT_E) begin

      fork

        this.master_drive();
      join
    end
    else begin

      fork

        this.slave_drive();
      join
    end
  endtask

  // ---------------------------------------------------------------------------
  // Reset VIF
  // ---------------------------------------------------------------------------
  protected task reset_vif();

    if (cfg.vip_axi4s_agent_type == VIP_AXI4S_MASTER_AGENT_E) begin

      _vif.tvalid <= '0;
      _vif.tdata  <= '0;
      _vif.tstrb  <= '0;
      _vif.tkeep  <= '0;
      _vif.tlast  <= '0;
      _vif.tid    <= '0;
      _vif.tdest  <= '0;
      _vif.tuser  <= '0;
    end
    else begin

      _vif.tready <= '0;
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task master_drive();

    forever begin

      seq_item_port.get_next_item(req);
      this.drive_axi4s_item();
      seq_item_port.item_done();
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task drive_axi4s_item();

    int beat_counter = 0;
    int burst_length = req.tdata.size();

    _vif.tlast <= '0;
    _vif.tid   <= req.tid;
    _vif.tdest <= req.tdest;

    // Driving tvalid
    if (cfg.tvalid_delay_enabled) begin

      fork

        begin

          this.drive_tvalid();
        end
      join_none
    end
    else begin

      _vif.tvalid <= '1;
    end

    // Driving the data
    while (beat_counter != burst_length) begin

      // Drive all data
      _vif.tdata <= req.tdata[beat_counter];
      _vif.tstrb <= req.tstrb[beat_counter];
      _vif.tkeep <= req.tkeep[beat_counter];
      _vif.tuser <= req.tuser[beat_counter];

      // Set tlast
      beat_counter++;
      if (beat_counter == burst_length) begin

        _vif.tlast <= '1;
      end

      // Wait for the handshake
      @(posedge _vif.clk);
      while (!((_vif.tvalid === '1) && (_vif.tready === '1))) begin

        @(posedge _vif.clk);
      end

      // Check if this was the last beat
      if (beat_counter == burst_length) begin

        if (cfg.tvalid_delay_enabled) begin

          disable fork;
        end

        _vif.tvalid <= '0;
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task drive_tvalid();

    int clock_counter       = 0;
    int tvalid_delay_time   = 0;
    int tvalid_delay_period = cfg.get_delay(
      .delay_enabled ( cfg.tvalid_delay_enabled       ),
      .gauss_enabled ( cfg.tvalid_delay_gauss_enabled ),
      .gauss         ( cfg.g_tvalid_period            ),
      .min           ( cfg.min_tvalid_delay_period    ),
      .max           ( cfg.max_tvalid_delay_period    )
    );

    _vif.tvalid <= '1;

    while (1) begin

      @(posedge _vif.clk);
      if ((_vif.tvalid === '1) && (_vif.tready === '1) && (_vif.tlast === '1)) begin

        @(posedge _vif.clk);
        _vif.tvalid <= '0;
        break;
      end

      clock_counter++;

      if ((clock_counter >= tvalid_delay_period) && (_vif.tvalid === '1) && (_vif.tready === '1)) begin

        _vif.tvalid         <= '0;

        clock_counter       = 0;
        tvalid_delay_time   = cfg.get_delay(
          .delay_enabled ( cfg.tvalid_delay_enabled       ),
          .gauss_enabled ( cfg.tvalid_delay_gauss_enabled ),
          .gauss         ( cfg.g_tvalid_time              ),
          .min           ( cfg.min_tvalid_delay_time      ),
          .max           ( cfg.max_tvalid_delay_time      )
        );
        tvalid_delay_period = cfg.get_delay(
          .delay_enabled ( cfg.tvalid_delay_enabled       ),
          .gauss_enabled ( cfg.tvalid_delay_gauss_enabled ),
          .gauss         ( cfg.g_tvalid_period            ),
          .min           ( cfg.min_tvalid_delay_period    ),
          .max           ( cfg.max_tvalid_delay_period    )
        );

        repeat (tvalid_delay_time) begin

          @(posedge _vif.clk);
        end
      end
      else begin

        _vif.tvalid <= '1;
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task slave_drive();
    this.drive_tready();
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  protected task drive_tready;

    int clock_counter       = 0;
    int tready_delay_time   = 0;
    int tready_delay_period = cfg.get_delay(
      .delay_enabled ( cfg.tready_delay_enabled       ),
      .gauss_enabled ( cfg.tready_delay_gauss_enabled ),
      .gauss         ( cfg.g_tready_period            ),
      .min           ( cfg.min_tready_delay_period    ),
      .max           ( cfg.max_tready_delay_period    )
    );

    if (!cfg.tready_delay_enabled) begin

      _vif.tready <= '1;
      return;
    end

    _vif.tready <= '1;
    forever begin

      @(posedge _vif.clk);

      clock_counter++;
      if (clock_counter >= tready_delay_period) begin

        _vif.tready <= '0;

        clock_counter       = 0;
        tready_delay_time   = cfg.get_delay(
          .delay_enabled ( cfg.tready_delay_enabled       ),
          .gauss_enabled ( cfg.tready_delay_gauss_enabled ),
          .gauss         ( cfg.g_tready_time              ),
          .min           ( cfg.min_tready_delay_time      ),
          .max           ( cfg.max_tready_delay_time      )
        );
        tready_delay_period = cfg.get_delay(
          .delay_enabled ( cfg.tready_delay_enabled       ),
          .gauss_enabled ( cfg.tready_delay_gauss_enabled ),
          .gauss         ( cfg.g_tready_period            ),
          .min           ( cfg.min_tready_delay_period    ),
          .max           ( cfg.max_tready_delay_period    )
        );

        repeat (tready_delay_time) begin

          clock_counter++;
          @(posedge _vif.clk);
        end

        _vif.tready <= '1;
      end
    end
  endtask
endclass
