# vip_axi4s_agent

AXI4-Stream verification agent with both implementations kept side by side:

- [`sv/`](sv/README.md): the original SystemVerilog UVM VIP. Its FuseSoC
  descriptor, [`vip_axi4s_agent.core`](vip_axi4s_agent.core), is kept at the
  repository root so this repo can be added directly to a FuseSoC search path.
- [`py/`](py/README.md): a cocotb/pyUVM port.

The Python port mirrors the SV agent structure: configuration objects, sequence
items, active master/slave driver behavior, monitor collection/protocol checks,
and a reset-aware agent wrapper.

The SV agent depends on [`vip_gauss`](https://github.com/akerlund/vip_gauss)
(Gaussian-distributed delays); the Python port only uses it optionally, at
runtime, if it's importable. [`testbench/`](testbench/README.md) additionally
depends on [`vip_clk_rst_agent`](https://github.com/akerlund/vip_clk_rst_agent)
and [`vip_report_server`](https://github.com/akerlund/vip_report_server)
(SV only). All three are checked out as git submodules under
[`submodules/`](submodules); run `git submodule update --init` to fetch
them, then point FuseSoC's `--cores-root` at both the repository root and
whichever submodules the target you're building needs.

## Feature Snapshot

| Area | Status |
| --- | --- |
| Active master, active slave, passive monitor | SV and Python |
| Per-beat TVALID/TREADY timing | Explicit arrays plus Gaussian/uniform fallback |
| Transaction-aware active slave response | Monitor packet-start request path with zero-time response contract |
| TKEEP/TSTRB stream shapes | Aligned, unaligned, sparse, byte-stream, and user patterns |
| Protocol checks | Named, configurable, severity-controlled, with end-of-test stats |
| Stream tracking | Open packets tracked by `{tid, tdest}` with interleave-depth and single-outstanding-per-TDEST checks |
| Functional coverage | SV covergroups plus mirrored Python counter summaries |
| Hooks | Driver and monitor callback base classes; packet, beat, violation, and stats analysis ports |
| Trace export | Optional JSONL/CSV beat, packet, and checker-event trace files |
| Performance metrics | Optional packet/beat latency, throughput, duty-cycle, stall, and reset-interruption counters |
| Idle and speed controls | Deterministic idle bus values, optional idle toggles, and a gated TDATA-only fast path |

## Key Controls

- `protocol_checks_enable`, `per_clock_checks_enable`, per-check enable, and per-check severity control checker behavior.
- An active agent does not re-check the signals it drives itself, so those checks are
  counted in the `suppressed` column of the checker statistics rather than in
  `executed` — a check that never ran never looks like a check that passed. The stream
  tracking checks are exempt: they test the legality of the stimulus, not the integrity
  of a driven signal, so an active master still applies them to itself.
- `max_stream_burst_length` limits observed packet length.
- `stream_interleave_depth` limits the number of simultaneously open `{tid, tdest}` streams.
  Leaving it at `1` also enables the `tid_or_tdest_change_before_tlast` check; raising it
  above `1` makes interleaving legal and that check is then not applied.
- `single_outstanding_per_tdest_enable` reports multiple open packets targeting the same TDEST.
- `coverage_enable` enables the coverage summary and SV covergroup sampling.
- `zero_delays_enable`, `tvalid_delay[]`, `tready_delay[]`, and `reference_event_for_tvalid_delay` control timing.
- `trace_enable`, `trace_format`, `trace_path`, and `trace_flush_enable` control text trace export.
- `performance_enable` enables end-of-test performance summaries.
- `drive_idle_values_enable` and the `idle_*` fields drive deterministic master-side idle values while TVALID is low.
- `tlast_idle_toggle_enable` and `tready_idle_toggle_enable` optionally toggle idle TLAST/TREADY.
- `tdata_only_fast_path_enable` enables the zero-delay, all-qualified, zero-TUSER TDATA-only driver path.

## Limitations

- AXI5-Stream TWAKEUP and parity-sideband checks are not modeled.
- The VIP exports JSONL/CSV text traces, but not FSDB/XML/protocol-analyzer databases.
- Interleaved stream generation is not provided yet; interleaved observation and checking are supported.
- The SV and Python example testbenches are not identical: the SV one wires two
  interfaces through a loopback DUT and uses `TID=11, TDEST=0, TUSER=0`, while
  the Python one shares a single bus between both agents and uses `4/4/4`. The
  zero-width qualifier checks are therefore only exercised by the SV flow.
- Python coverage is counter-based rather than simulator-native functional coverage.
- The included DUT is a loopback-style example, not a full system environment.

## Examples

Build the SV simulator from [`testbench/sv`](testbench/sv) with `refuse vcs`,
then run individual SV tests with `refuse simv --tc <testcase>`. Run Python
cocotb tests from [`testbench/py`](testbench/py) with
`refuse verilator --tc <testcase>`.

| Scenario | SV testcase / Python testcase |
| --- | --- |
| DUT as sink, VIP active master | `tc_axi4s_demonstration` / `tc_axi4s_demonstration` |
| DUT as source, VIP active slave with targeted response | `tc_axi4s_active_slave_response` / `tc_axi4s_active_slave_response` |
| Passive monitor-only checking | Negative checker tests configure both agents passive |
| Sparse TKEEP/TSTRB traffic | `tc_axi4s_sparse_qualifiers` / `tc_axi4s_sparse_qualifiers` |
| Reset during packet | `tc_axi4s_neg_reset` / `tc_axi4s_neg_reset` |
| Two independent observed streams | `tc_axi4s_neg_stream_tracking` / `tc_axi4s_neg_stream_tracking` |
| Optional trace/performance/idle/fast-path controls | `tc_axi4s_optional_extras` / `tc_axi4s_optional_extras` |
| Legal interleaving raises no stream violations and keeps packet-start notifications keyed by stream | `tc_axi4s_interleaved_streams` / `tc_axi4s_interleaved_streams` |
| Back-to-back packets still announce a packet start | (covered by the random test) / `tc_axi4s_packet_start_back_to_back` |
| Randomized soak run over several thousand clocks | `tc_axi4s_random` / `tc_axi4s_random` |

The randomized run picks a fresh seed each time and prints it. Reproduce a
failure with `refuse simv --tc tc_axi4s_random --seed <n>` on the SV side, or
`AXI4S_RANDOM_SEED=<n> refuse verilator --tc tc_axi4s_random` on the Python
side.
