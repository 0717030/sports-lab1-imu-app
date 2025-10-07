import 'dart:ui' show Offset;
import '../models/sample.dart';

class IntegrationService {
  List<Offset> integrateOnce(List<Sample> buf, double Function(Sample) pick) {
    final result = <Offset>[];
    if (buf.isEmpty) return result;

    final double t0 = buf.first.t;
    final double a0 = pick(buf.first);
    final double v0 = a0 * t0;
    double prevA = a0;
    double prevT = t0;
    double integ = v0;

    result.add(Offset(buf.first.t, integ));
    for (int i = 1; i < buf.length; i++) {
      final s = buf[i];
      final double a = pick(s);
      final double dt = s.t - prevT;
      if (dt < 0) continue;
      integ += 0.5 * (a + prevA) * dt;
      result.add(Offset(s.t, integ));
      prevA = a; prevT = s.t;
    }
    return result;
  }

  List<Offset> integrateTwice(List<Sample> buf, double Function(Sample) pick) {
    if (buf.isEmpty) return const <Offset>[];

    final vel = <double>[];
    final double t0 = buf.first.t;
    final double a0 = pick(buf.first);
    final double v0 = a0 * t0;
    double prevA = a0;
    double prevT = t0;
    double v = v0;
    vel.add(v);
    for (int i = 1; i < buf.length; i++) {
      final s = buf[i];
      final double a = pick(s);
      final double dt = s.t - prevT;
      if (dt < 0) { vel.add(v); continue; }
      v += 0.5 * (a + prevA) * dt;
      vel.add(v);
      prevA = a; prevT = s.t;
    }

    final out = <Offset>[];
    double prevV = vel.first;
    prevT = buf.first.t;
    double x = prevV * prevT;
    out.add(Offset(buf.first.t, x));
    for (int i = 1; i < buf.length; i++) {
      final s = buf[i];
      final double dt = s.t - prevT;
      if (dt < 0) { out.add(Offset(s.t, x)); continue; }
      final double vi = vel[i];
      x += 0.5 * (vi + prevV) * dt;
      out.add(Offset(s.t, x));
      prevV = vi; prevT = s.t;
    }
    return out;
  }
}
