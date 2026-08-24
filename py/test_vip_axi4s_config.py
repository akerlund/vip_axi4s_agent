import pytest

from vip_axi4s_config import vip_axi4s_config
from vip_axi4s_types_pkg import Axi4sCheck, Axi4sStreamXactType


def test_rebuild_gauss_cdfs_builds_requested_generators():
  cfg = vip_axi4s_config()
  cfg.rebuild_gauss_cdfs()

  assert cfg.g_tvalid_time is not None
  assert cfg.g_tvalid_period is not None
  assert cfg.g_tready_time is not None
  assert cfg.g_tready_period is not None


def test_delay_ranges_are_validated():
  cfg = vip_axi4s_config()
  cfg.min_tvalid_delay_time = 5
  cfg.max_tvalid_delay_time = 4

  with pytest.raises(ValueError):
    cfg.rebuild_gauss_cdfs()


def test_uniform_delay_is_inclusive():
  cfg = vip_axi4s_config()
  values = {cfg.get_delay(True, False, None, 2, 2) for _ in range(8)}

  assert values == {2}


def test_checker_defaults_are_enabled():
  cfg = vip_axi4s_config()

  assert cfg.protocol_checks_enable is True
  assert cfg.per_clock_checks_enable is True
  assert cfg.max_stream_burst_length == 256
  assert cfg.stream_interleave_depth == 1
  assert cfg.single_outstanding_per_tdest_enable is False
  assert cfg.coverage_enable is True
  assert cfg.trace_enable is False
  assert cfg.trace_format == "jsonl"
  assert cfg.trace_path == ""
  assert cfg.performance_enable is False
  assert cfg.drive_idle_values_enable is False
  assert cfg.tlast_idle_toggle_enable is False
  assert cfg.tready_idle_toggle_enable is False
  assert cfg.tdata_only_fast_path_enable is False
  assert cfg.zero_delays_enable is False
  for check in Axi4sCheck:
    assert cfg.is_check_enabled(check)
    assert cfg.get_check_severity(check) == "ERROR"
    assert cfg.get_check_executed(check) == 0
    assert cfg.get_check_violations(check) == 0


def test_checker_master_switches_disable_expected_checks():
  cfg = vip_axi4s_config()

  cfg.per_clock_checks_enable = False
  assert not cfg.is_check_enabled(Axi4sCheck.SIGNAL_VALID_TVALID)
  assert not cfg.is_check_enabled(Axi4sCheck.SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH)
  assert cfg.is_check_enabled(Axi4sCheck.MAX_STREAM_BURST_LENGTH_EXCEEDED)

  cfg.per_clock_checks_enable = True
  cfg.protocol_checks_enable = False
  for check in Axi4sCheck:
    assert not cfg.is_check_enabled(check)


def test_checker_per_check_enable_and_severity():
  cfg = vip_axi4s_config()

  cfg.set_check_enable(Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW, False)
  cfg.set_check_severity(Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW, "UVM_WARNING")

  assert not cfg.is_check_enabled(Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW)
  assert cfg.get_check_severity(Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW) == "WARNING"

  with pytest.raises(ValueError):
    cfg.set_check_severity(Axi4sCheck.TSTRB_LOW_WHEN_TKEEP_LOW, "NOTE")


def test_checker_stats_recording_and_formatting():
  cfg = vip_axi4s_config()

  cfg.record_check(Axi4sCheck.SIGNAL_VALID_TVALID)
  cfg.record_violation(Axi4sCheck.SIGNAL_VALID_TVALID)

  assert cfg.has_checker_activity()
  assert cfg.get_check_executed(Axi4sCheck.SIGNAL_VALID_TVALID) == 1
  assert cfg.get_check_violations(Axi4sCheck.SIGNAL_VALID_TVALID) == 1
  assert "signal_valid_tvalid,1,0,1,1,error" in cfg.checker_stats_s()


def test_suppressed_checks_are_reported_apart_from_executed():
  # A check that never ran must not look like a check that ran and passed
  cfg = vip_axi4s_config()

  for _ in range(3):
    cfg.record_suppressed_check(Axi4sCheck.SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH)

  assert cfg.has_checker_activity()
  assert cfg.get_check_suppressed(Axi4sCheck.SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH) == 3
  assert cfg.get_check_executed(Axi4sCheck.SIGNAL_STABLE_TDATA_WHEN_TVALID_HIGH) == 0
  assert "signal_stable_tdata_when_tvalid_high,0,3,0,1,error" in cfg.checker_stats_s()


def test_coverage_recording_and_formatting():
  cfg = vip_axi4s_config()

  cfg.record_coverage_beat(
    tkeep=0xF,
    tstrb=0x7,
    keep_mask=0xF,
    tvalid_delay=2,
    stall_cycles=4)
  cfg.record_coverage_packet(
    packet_length=4,
    stream_xact_type=Axi4sStreamXactType.SPARSE_STREAM,
    tid=1,
    tdest=0,
    has_nonzero_tuser=True,
    backpressure_cycles=4)
  cfg.record_coverage_reset_during_packet()

  summary = cfg.coverage_summary_s()
  assert cfg.has_coverage_activity()
  assert "beats,1" in summary
  assert "packets,1" in summary
  assert "stream_sparse_stream,1" in summary
  assert "packet_backpressure_long,1" in summary
  assert "tready_stall_long,1" in summary
  assert "reset_during_packet,1" in summary


def test_packet_length_bins_do_not_follow_max_stream_burst_length():
  # The bins must match the SV covergroup, which cannot depend on a runtime
  # value, so the same packet always lands in the same bin
  for max_burst in (4, 256, 1024):
    cfg = vip_axi4s_config()
    cfg.max_stream_burst_length = max_burst
    for length in (1, 8, 200, 512):
      cfg.record_coverage_packet(
        packet_length=length,
        stream_xact_type=Axi4sStreamXactType.CONTINUOUS_ALIGNED_STREAM,
        tid=0,
        tdest=0,
        has_nonzero_tuser=False,
        backpressure_cycles=0)

    summary = cfg.coverage_summary_s()
    assert "packet_length_one,1" in summary
    assert "packet_length_small,1" in summary
    assert "packet_length_medium,1" in summary
    assert "packet_length_large,1" in summary


def test_performance_recording_and_formatting():
  cfg = vip_axi4s_config()
  cfg.performance_enable = True

  cfg.record_performance_cycle(tvalid=True, tready=False)
  cfg.record_performance_cycle(tvalid=True, tready=True)
  cfg.record_performance_beat(data_bytes=4, stall_cycles=1)
  cfg.record_performance_packet(packet_latency_cycles=2)
  cfg.record_performance_reset_during_packet()

  summary = cfg.performance_summary_s()
  assert cfg.has_performance_activity()
  assert cfg.get_performance_packets() == 1
  assert cfg.get_performance_beats() == 1
  assert cfg.get_performance_data_bytes() == 4
  assert "packets,1" in summary
  assert "beats,1" in summary
  assert "data_bytes,4" in summary
  assert "beat_latency_mean_cycles,2.000" in summary
  assert "packet_latency_mean_cycles,2.000" in summary
  assert "bus_utilization_percent,50.000" in summary
