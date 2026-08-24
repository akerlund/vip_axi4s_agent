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

`ifndef VIP_AXI4S_TYPES_PKG
`define VIP_AXI4S_TYPES_PKG

package vip_axi4s_types_pkg;

  typedef enum bit {
    FALSE,
    TRUE
  } bool_t;

  typedef enum {
    VIP_AXI4S_MASTER_AGENT_E,
    VIP_AXI4S_SLAVE_AGENT_E
  } vip_axi4s_agent_type_t;

  typedef struct packed {
    int VIP_AXI4S_TDATA_BYTES_P;
    int VIP_AXI4S_TID_WIDTH_P;
    int VIP_AXI4S_TDEST_WIDTH_P;
    int VIP_AXI4S_TUSER_WIDTH_P;
  } vip_axi4s_cfg_t;

  typedef enum {
    VIP_AXI4S_TID_COUNTER_E,
    VIP_AXI4S_TID_RANDOM_E
  } vip_axi4s_tid_type_t;

  typedef enum {
    VIP_AXI4S_TDATA_COUNTER_E,
    VIP_AXI4S_TDATA_RANDOM_E,
    VIP_AXI4S_TDATA_ZEROS_E,
    VIP_AXI4S_TDATA_ONES_E,
    VIP_AXI4S_TDATA_CUSTOM_E
  } vip_axi4s_tdata_type_t;

  typedef enum {
    VIP_AXI4S_TUSER_COUNTER_E,
    VIP_AXI4S_TUSER_RANDOM_E,
    VIP_AXI4S_TUSER_ZEROS_E,
    VIP_AXI4S_TUSER_ONES_E,
    VIP_AXI4S_TUSER_CUSTOM_E
  } vip_axi4s_tuser_type_t;

  typedef enum {
    VIP_AXI4S_TDEST_INCR_E,
    VIP_AXI4S_TDEST_RANDOM_E,
    VIP_AXI4S_TDEST_CUSTOM_E
  } vip_axi4s_tdest_type_t;

  typedef enum {
    VIP_AXI4S_TSTRB_ALL_E,
    VIP_AXI4S_TSTRB_RANDOM_E
  } vip_axi4s_tstrb_t;

  typedef enum {
    VIP_AXI4S_TKEEP_ALL_E,
    VIP_AXI4S_TKEEP_RANDOM_E,
    VIP_AXI4S_TKEEP_CUSTOM_E,
    VIP_AXI4S_TKEEP_SPARSE_E
  } vip_axi4s_tkeep_t;

  typedef enum {
    VIP_AXI4S_BYTE_STREAM_E,
    VIP_AXI4S_CONTINUOUS_ALIGNED_STREAM_E,
    VIP_AXI4S_CONTINUOUS_UNALIGNED_STREAM_E,
    VIP_AXI4S_SPARSE_STREAM_E,
    VIP_AXI4S_USER_STREAM_E
  } vip_axi4s_stream_xact_type_t;

  typedef enum {
    VIP_AXI4S_TVALID_DELAY_PREV_TVALID_E,
    VIP_AXI4S_TVALID_DELAY_PREV_TVALID_TREADY_HANDSHAKE_E
  } vip_axi4s_tvalid_delay_ref_t;

  typedef enum int {
    VIP_AXI4S_CHECK_SIGNAL_VALID_TVALID_E,
    VIP_AXI4S_CHECK_SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_VALID_TSTRB_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_VALID_TKEEP_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_VALID_TLAST_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_VALID_TID_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_VALID_TDEST_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_VALID_TUSER_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_STABLE_TSTRB_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_STABLE_TKEEP_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_STABLE_TLAST_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_STABLE_TID_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_STABLE_TDEST_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH_E,
    VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E,
    VIP_AXI4S_CHECK_TVALID_LOW_WHEN_RESET_IS_ACTIVE_E,
    VIP_AXI4S_CHECK_TSTRB_LOW_WHEN_TKEEP_LOW_E,
    VIP_AXI4S_CHECK_TID_OR_TDEST_CHANGE_BEFORE_TLAST_E,
    VIP_AXI4S_CHECK_MAX_STREAM_BURST_LENGTH_EXCEEDED_E,
    VIP_AXI4S_CHECK_PACKET_TRUNCATED_BY_RESET_E,
    VIP_AXI4S_CHECK_STREAM_INTERLEAVE_DEPTH_EXCEEDED_E,
    VIP_AXI4S_CHECK_SINGLE_OUTSTANDING_PER_TDEST_E,
    VIP_AXI4S_CHECK_ZERO_WIDTH_TID_IS_ZERO_E,
    VIP_AXI4S_CHECK_ZERO_WIDTH_TDEST_IS_ZERO_E,
    VIP_AXI4S_CHECK_ZERO_WIDTH_TUSER_IS_ZERO_E,
    VIP_AXI4S_CHECK_NUM_E
  } vip_axi4s_check_t;

  function automatic string vip_axi4s_check_name(input vip_axi4s_check_t check);
    case (check)
      VIP_AXI4S_CHECK_SIGNAL_VALID_TVALID_E:
        return "signal_valid_tvalid";
      VIP_AXI4S_CHECK_SIGNAL_VALID_TREADY_WHEN_TVALID_HIGH_E:
        return "signal_valid_tready_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_VALID_TDATA_WHEN_TVALID_HIGH_E:
        return "signal_valid_tdata_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_VALID_TSTRB_WHEN_TVALID_HIGH_E:
        return "signal_valid_tstrb_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_VALID_TKEEP_WHEN_TVALID_HIGH_E:
        return "signal_valid_tkeep_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_VALID_TLAST_WHEN_TVALID_HIGH_E:
        return "signal_valid_tlast_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_VALID_TID_WHEN_TVALID_HIGH_E:
        return "signal_valid_tid_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_VALID_TDEST_WHEN_TVALID_HIGH_E:
        return "signal_valid_tdest_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_VALID_TUSER_WHEN_TVALID_HIGH_E:
        return "signal_valid_tuser_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH_E:
        return "signal_stable_tdata_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_STABLE_TSTRB_WHEN_TVALID_HIGH_E:
        return "signal_stable_tstrb_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_STABLE_TKEEP_WHEN_TVALID_HIGH_E:
        return "signal_stable_tkeep_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_STABLE_TLAST_WHEN_TVALID_HIGH_E:
        return "signal_stable_tlast_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_STABLE_TID_WHEN_TVALID_HIGH_E:
        return "signal_stable_tid_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_STABLE_TDEST_WHEN_TVALID_HIGH_E:
        return "signal_stable_tdest_when_tvalid_high";
      VIP_AXI4S_CHECK_SIGNAL_STABLE_TUSER_WHEN_TVALID_HIGH_E:
        return "signal_stable_tuser_when_tvalid_high";
      VIP_AXI4S_CHECK_TVALID_INTERRUPTED_E:
        return "tvalid_interrupted";
      VIP_AXI4S_CHECK_TVALID_LOW_WHEN_RESET_IS_ACTIVE_E:
        return "tvalid_low_when_reset_is_active";
      VIP_AXI4S_CHECK_TSTRB_LOW_WHEN_TKEEP_LOW_E:
        return "tstrb_low_when_tkeep_low";
      VIP_AXI4S_CHECK_TID_OR_TDEST_CHANGE_BEFORE_TLAST_E:
        return "tid_or_tdest_change_before_tlast";
      VIP_AXI4S_CHECK_MAX_STREAM_BURST_LENGTH_EXCEEDED_E:
        return "max_stream_burst_length_exceeded";
      VIP_AXI4S_CHECK_PACKET_TRUNCATED_BY_RESET_E:
        return "packet_truncated_by_reset";
      VIP_AXI4S_CHECK_STREAM_INTERLEAVE_DEPTH_EXCEEDED_E:
        return "stream_interleave_depth_exceeded";
      VIP_AXI4S_CHECK_SINGLE_OUTSTANDING_PER_TDEST_E:
        return "single_outstanding_per_tdest";
      VIP_AXI4S_CHECK_ZERO_WIDTH_TID_IS_ZERO_E:
        return "zero_width_tid_is_zero";
      VIP_AXI4S_CHECK_ZERO_WIDTH_TDEST_IS_ZERO_E:
        return "zero_width_tdest_is_zero";
      VIP_AXI4S_CHECK_ZERO_WIDTH_TUSER_IS_ZERO_E:
        return "zero_width_tuser_is_zero";
      default:
        return "unknown_axi4s_check";
    endcase
  endfunction
endpackage

`endif
