import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Test builds only (`--dart-define=VERIXA_PERF=true`): logs frame times
/// every few seconds so smoothness can be measured on a phone or emulator.
const _enabled = bool.fromEnvironment('VERIXA_PERF');

void startPerfProbe() {
  if (!_enabled) return;
  final build = <int>[], raster = <int>[];
  var last = DateTime.now();
  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    for (final t in timings) {
      build.add(t.buildDuration.inMicroseconds);
      raster.add(t.rasterDuration.inMicroseconds);
    }
    if (DateTime.now().difference(last).inSeconds < 4 || build.isEmpty) return;
    last = DateTime.now();
    String p(List<int> v, double q) {
      final s = [...v]..sort();
      return (s[((s.length - 1) * q).round()] / 1000).toStringAsFixed(1);
    }
    final janky = [
      for (var i = 0; i < build.length; i++)
        if (build[i] > 16667 || raster[i] > 16667) i,
    ].length;
    debugPrint('PERF frames=${build.length} janky=$janky '
        'build p50=${p(build, .5)} p90=${p(build, .9)} max=${p(build, 1)} | '
        'raster p50=${p(raster, .5)} p90=${p(raster, .9)} max=${p(raster, 1)} ms');
    build.clear();
    raster.clear();
  });
}
