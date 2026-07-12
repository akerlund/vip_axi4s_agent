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

class vip_axi4s_config extends uvm_object;

  uvm_active_passive_enum is_active            = UVM_ACTIVE;
  vip_axi4s_agent_type_t  vip_axi4s_agent_type = VIP_AXI4S_MASTER_AGENT_E;

  bool_t    tvalid_delay_enabled       = TRUE;
  bool_t    tvalid_delay_gauss_enabled = TRUE;
  int       min_tvalid_delay_time      = 1;
  int       max_tvalid_delay_time      = 10;
  int       tvalid_delay_time_mean     = 4;
  real      tvalid_delay_time_stddev   = 2.0;
  int       min_tvalid_delay_period    = 10;
  int       max_tvalid_delay_period    = 256;
  int       tvalid_delay_period_mean   = 64;
  real      tvalid_delay_period_stddev = 32.0;
  vip_gauss g_tvalid_time;
  vip_gauss g_tvalid_period;

  bool_t    tready_delay_enabled       = TRUE;
  bool_t    tready_delay_gauss_enabled = TRUE;
  int       min_tready_delay_time      = 1;
  int       max_tready_delay_time      = 10;
  int       tready_delay_time_mean     = 4;
  real      tready_delay_time_stddev   = 2.0;
  int       min_tready_delay_period    = 10;
  int       max_tready_delay_period    = 256;
  int       tready_delay_period_mean   = 64;
  real      tready_delay_period_stddev = 32.0;
  vip_gauss g_tready_time;
  vip_gauss g_tready_period;

  `uvm_object_utils_begin(vip_axi4s_config);
    `uvm_field_enum(uvm_active_passive_enum, is_active,                  UVM_PRINT)
    `uvm_field_enum(vip_axi4s_agent_type_t,  vip_axi4s_agent_type,       UVM_PRINT)
    `uvm_field_enum(bool_t,                  tvalid_delay_enabled,       UVM_PRINT)
    `uvm_field_enum(bool_t,                  tvalid_delay_gauss_enabled, UVM_PRINT)
    `uvm_field_int(min_tvalid_delay_time,                                UVM_PRINT | UVM_DEC)
    `uvm_field_int(max_tvalid_delay_time,                                UVM_PRINT | UVM_DEC)
    `uvm_field_int(tvalid_delay_time_mean,                               UVM_PRINT | UVM_DEC)
    `uvm_field_real(tvalid_delay_time_stddev,                            UVM_PRINT | UVM_DEC)
    `uvm_field_int(min_tvalid_delay_period,                              UVM_PRINT | UVM_DEC)
    `uvm_field_int(max_tvalid_delay_period,                              UVM_PRINT | UVM_DEC)
    `uvm_field_int(tvalid_delay_period_mean,                             UVM_PRINT | UVM_DEC)
    `uvm_field_real(tvalid_delay_period_stddev,                          UVM_PRINT | UVM_DEC)
    `uvm_field_enum(bool_t,                  tready_delay_enabled,       UVM_PRINT)
    `uvm_field_enum(bool_t,                  tready_delay_gauss_enabled, UVM_PRINT)
    `uvm_field_int(min_tready_delay_time,                                UVM_PRINT | UVM_DEC)
    `uvm_field_int(max_tready_delay_time,                                UVM_PRINT | UVM_DEC)
    `uvm_field_int(tready_delay_time_mean,                               UVM_PRINT | UVM_DEC)
    `uvm_field_real(tready_delay_time_stddev,                            UVM_PRINT | UVM_DEC)
    `uvm_field_int(min_tready_delay_period,                              UVM_PRINT | UVM_DEC)
    `uvm_field_int(max_tready_delay_period,                              UVM_PRINT | UVM_DEC)
    `uvm_field_int(tready_delay_period_mean,                             UVM_PRINT | UVM_DEC)
    `uvm_field_real(tready_delay_period_stddev,                          UVM_PRINT | UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "vip_axi4s_config");
    super.new(name);
  endfunction

  protected function void validate_range(
    input string name,
    input int    min,
    input int    max
  );
    if (min < 0) begin

      `uvm_fatal(get_name(), $sformatf(
      "%s min (%0d) must be non-negative", name, min))
    end

    if (max < min) begin

      `uvm_fatal(get_name(), $sformatf(
      "%s max (%0d) must be >= min (%0d)", name, max, min))
    end
  endfunction

  protected function void build_gauss(
    ref   vip_gauss g,
    input string    name,
    input int       min,
    input int       max,
    input int       mean,
    input real      stddev
  );
    this.validate_range(name, min, max);

    if (g == null) begin

      g = vip_gauss::type_id::create(name);
    end

    g.gen_cdf(min, max, mean, stddev);
  endfunction

  function void rebuild_gauss_cdfs();

    this.validate_range("tvalid_delay_time", min_tvalid_delay_time, max_tvalid_delay_time);
    this.validate_range("tvalid_delay_period", min_tvalid_delay_period, max_tvalid_delay_period);
    this.validate_range("tready_delay_time", min_tready_delay_time, max_tready_delay_time);
    this.validate_range("tready_delay_period", min_tready_delay_period, max_tready_delay_period);

    if (tvalid_delay_gauss_enabled == TRUE) begin

      this.build_gauss(
        g_tvalid_time,
        "g_tvalid_time",
        min_tvalid_delay_time,
        max_tvalid_delay_time,
        tvalid_delay_time_mean,
        tvalid_delay_time_stddev
      );

      this.build_gauss(
        g_tvalid_period,
        "g_tvalid_period",
        min_tvalid_delay_period,
        max_tvalid_delay_period,
        tvalid_delay_period_mean,
        tvalid_delay_period_stddev
      );
    end

    if (tready_delay_gauss_enabled == TRUE) begin

      this.build_gauss(
        g_tready_time,
        "g_tready_time",
        min_tready_delay_time,
        max_tready_delay_time,
        tready_delay_time_mean,
        tready_delay_time_stddev
      );

      this.build_gauss(
        g_tready_period,
        "g_tready_period",
        min_tready_delay_period,
        max_tready_delay_period,
        tready_delay_period_mean,
        tready_delay_period_stddev
      );
    end
  endfunction

  function int unsigned get_delay(
    input bool_t    delay_enabled,
    input bool_t    gauss_enabled,
          vip_gauss gauss,
    input int       min,
    input int       max
  );
    this.validate_range("delay", min, max);

    if (delay_enabled == FALSE) begin

      return 0;
    end

    if (gauss_enabled == TRUE) begin

      if (gauss == null) begin

        `uvm_fatal(get_name(), "Gaussian delay requested before CDF was built")
      end

      return gauss.get_r_cdf_int();
    end

    return $urandom_range(max, min);
  endfunction
endclass
