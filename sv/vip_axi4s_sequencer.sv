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

`uvm_analysis_imp_decl(_axi4s_packet_start)

class vip_axi4s_sequencer #(
  vip_axi4s_cfg_t CFG_P = '{default: '0}
  ) extends uvm_sequencer #(vip_axi4s_item #(CFG_P));

  uvm_analysis_imp_axi4s_packet_start #(vip_axi4s_item #(CFG_P), vip_axi4s_sequencer #(CFG_P)) packet_start_export;

  protected vip_axi4s_item #(CFG_P) _packet_start_q [$];
  protected vip_axi4s_item #(CFG_P) _packet_response_q [$];
  protected vip_axi4s_item #(CFG_P) _active_packet_request;
  protected int unsigned            _packet_start_waiters;
  protected bit                     _response_expected;
  protected event                   _packet_start_event;

  `uvm_component_param_utils(vip_axi4s_sequencer #(CFG_P))

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function new(string name, uvm_component parent);

    super.new(name, parent);
    packet_start_export = new("packet_start_export", this);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void write_axi4s_packet_start(vip_axi4s_item #(CFG_P) trans);

    _active_packet_request = trans;
    _response_expected     = (_packet_start_waiters != 0);

    // Only queue the request when a response sequence is actually waiting for
    // it. The response contract is zero time, so a request that nobody is
    // waiting for is stale by the time anyone could pop it and would otherwise
    // accumulate for the whole test
    if (_response_expected) begin

      _packet_start_q.push_back(trans);
      -> _packet_start_event;
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  task get_packet_start(output vip_axi4s_item #(CFG_P) trans);

    _packet_start_waiters++;
    while (_packet_start_q.size() == 0) begin
      @(_packet_start_event);
    end
    trans = _packet_start_q.pop_front();
    _packet_start_waiters--;
  endtask

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function bit response_expected_for_active_packet();

    return _response_expected;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function bit is_expected_packet_response(input vip_axi4s_item #(CFG_P) rsp);

    return (rsp != null) && (rsp == _active_packet_request);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void put_packet_response(input vip_axi4s_item #(CFG_P) rsp);

    if (!this.is_expected_packet_response(rsp)) begin
      `uvm_fatal(get_name(), "Slave response sequence must return the packet-start request object handle")
    end
    _packet_response_q.push_back(rsp);
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function bit try_get_packet_response(output vip_axi4s_item #(CFG_P) rsp);

    if (_packet_response_q.size() == 0) begin
      rsp = null;
      return 1'b0;
    end
    rsp = _packet_response_q.pop_front();
    return 1'b1;
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void clear_active_packet_request(input vip_axi4s_item #(CFG_P) rsp);

    if (rsp == _active_packet_request) begin
      _active_packet_request = null;
      _response_expected     = 1'b0;
    end
  endfunction

  // ---------------------------------------------------------------------------
  //
  // ---------------------------------------------------------------------------
  function void handle_reset(uvm_phase phase);

    uvm_objection objection = phase.get_objection();
    int           objections_count;

    super.stop_sequences();
    _packet_start_q.delete();
    _packet_response_q.delete();
    _active_packet_request = null;
    _packet_start_waiters  = 0;
    _response_expected     = 1'b0;

    objections_count = objection.get_objection_count(this);
    if (objections_count > 0) begin

      objection.drop_objection(this, $sformatf(
      "Dropping %0d objections at reset", objections_count), objections_count);
    end

    super.start_phase_sequence(phase);
  endfunction
endclass
