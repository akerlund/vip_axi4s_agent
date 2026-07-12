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

class vip_axi4s_agent #(
  vip_axi4s_cfg_t CFG_P = '{default: '0}
  ) extends uvm_agent;

  protected virtual vip_axi4s_if #(CFG_P) vif;
  protected int                           id;

  vip_axi4s_monitor   #(CFG_P) monitor;
  vip_axi4s_driver    #(CFG_P) driver;
  vip_axi4s_sequencer #(CFG_P) sequencer;
  vip_axi4s_config             cfg;

  `uvm_component_param_utils_begin(vip_axi4s_agent #(CFG_P))
    `uvm_field_int(id, UVM_DEFAULT)
    `uvm_field_object(cfg, UVM_DEFAULT | UVM_REFERENCE)
  `uvm_component_utils_end


  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    if (!uvm_config_db #(virtual vip_axi4s_if #(CFG_P))::get(this, "", "vif", vif)) begin

      `uvm_fatal(get_name(), $sformatf(
      "FATAL [%s] Virtual interface must be set for: %s.vif",
      get_name(), get_full_name()))
    end

    if (!uvm_config_db #(vip_axi4s_config)::get(this, "", "cfg", cfg)) begin

      `uvm_info(get_name(), "Agent has no config, creating a default config", UVM_LOW)
      cfg = vip_axi4s_config::type_id::create({"default_config_", get_name()}, this);
    end

    monitor = vip_axi4s_monitor #(CFG_P)::type_id::create({"vip_axi4s_monitor_", get_name()}, this);

    if (cfg.is_active == UVM_ACTIVE) begin

      cfg.rebuild_gauss_cdfs();
      driver     = vip_axi4s_driver #(CFG_P)::type_id::create({"vip_axi4s_driver_", get_name()}, this);
      driver.cfg = cfg;
      sequencer  = vip_axi4s_sequencer #(CFG_P)::type_id::create({"vip_axi4s_sequencer_", get_name()}, this);
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void connect_phase(uvm_phase phase);

    if (cfg.is_active == UVM_ACTIVE) begin

      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);

    forever begin

      @(negedge vif.rst_n);
      `uvm_info(get_name(), $sformatf(
      "[rst_n] Calling reset handler"),
      UVM_LOW)

      this.handle_reset(phase);
    end
 endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void handle_reset(uvm_phase phase);

    monitor.handle_reset();

    if (cfg.is_active == UVM_ACTIVE) begin

      sequencer.handle_reset(phase);
    end
  endfunction
endclass
