import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/sample.dart';

class SensorService {
  double ax = 0, ay = 0, az = 0;
  double gx = 0, gy = 0, gz = 0;
  double mx = 0, my = 0, mz = 0;

  final List<Sample> buffer = [];

  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  Timer? _timer;
  DateTime? _startAt;

  void init() {
    try {
      _accSub = accelerometerEventStream().listen(
        (e) { ax = e.x; ay = e.y; az = e.z; },
        onError: (err, st) { /* 某些裝置可能不支援，加個 log 即可 */ },
        cancelOnError: false,
      );
    } catch (_) {
      // 模擬器可能沒有加速度計
    }

    try {
      _gyroSub = gyroscopeEventStream().listen(
        (g) { gx = g.x; gy = g.y; gz = g.z; },
        onError: (err, st) {},
        cancelOnError: false,
      );
    } catch (_) {
      // 可能沒有陀螺儀
    }

    try {
      _magSub = magnetometerEventStream().listen(
        (m) { mx = m.x; my = m.y; mz = m.z; },
        onError: (err, st) {},
        cancelOnError: false,
      );
    } catch (_) {
      // 很多模擬器沒有磁力計
    }
  }


  void dispose() {
    _timer?.cancel();
    _accSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
  }

  void pauseStreams() { _accSub?.pause(); _gyroSub?.pause(); _magSub?.pause(); }
  void resumeStreams() { _accSub?.resume(); _gyroSub?.resume(); _magSub?.resume(); }

  void startRecording(int hz) {
    stopRecording();
    buffer.clear();
    _startAt = DateTime.now();
    final intervalMs = (1000 / hz).round().clamp(1, 1000);
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (t) {
      final elapsed = DateTime.now().difference(_startAt!).inMicroseconds / 1e6;
      buffer.add(Sample(
        t: elapsed,
        ax: ax, ay: ay, az: az,
        gx: gx, gy: gy, gz: gz,
        mx: mx, my: my, mz: mz,
      ));
    });
  }

  void stopRecording() {
    _timer?.cancel();
    _timer = null;
  }
}
