import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/series_bundle.dart';
import '../services/sensor_service.dart';
import '../services/integration_service.dart';
import '../widgets/imu_chart.dart';

enum SensorKind { accelerometer, gyroscope, magnetometer, velocity, displacement, orientation }

const _xColor = Colors.red;
const _yColor = Colors.green;
const _zColor = Colors.blue;

class SensorRecorderPage extends StatefulWidget {
  const SensorRecorderPage({super.key});
  @override
  State<SensorRecorderPage> createState() => _SensorRecorderPageState();
}

class _SensorRecorderPageState extends State<SensorRecorderPage> with WidgetsBindingObserver {
  final _hzCtrl = TextEditingController(text: '60');
  final _secCtrl = TextEditingController(text: '6');
  final ScrollController _verticalScrollCtrl = ScrollController();
  bool _isRecording = false;
  SensorKind _chartKind = SensorKind.accelerometer;
  final _chartKey = GlobalKey();

  String? _lastCsvPath;
  final List<String> _allPngPaths = []; // 停止後一次存好的 6 張圖

  final _sensor = SensorService();
  final _integrator = IntegrationService();
  Timer? _uiTicker; // UI refresh ticker

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sensor.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTicker?.cancel();
    _sensor.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _sensor.pauseStreams();
    } else if (state == AppLifecycleState.resumed) {
      _sensor.resumeStreams();
    }
  }

  void _start() {
    final hz = int.tryParse(_hzCtrl.text.trim());
    final sec = double.tryParse(_secCtrl.text.trim());
    if (hz == null || hz <= 0 || sec == null || sec <= 0) {
      _snack('請輸入有效的 X(Hz) / Y(秒)');
      return;
    }
    _allPngPaths.clear(); // 這次錄製重新累積
    _sensor.startRecording(hz);
    setState(() { _isRecording = true; _lastCsvPath = null; });

    // UI 每 100ms 刷一次，達成即時畫圖
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && _isRecording) setState(() {});
    });

    // 自動停止並存檔
    Timer(Duration(milliseconds: (sec * 1000).round()), () { if (mounted) _stop(save: true); });
  }

  Future<void> _stop({bool save = true}) async {
    _sensor.stopRecording();
    _uiTicker?.cancel();
    setState(() { _isRecording = false; });
    if (save && _sensor.buffer.isNotEmpty) {
      await _saveCsv();                   // 先存 CSV
      await _saveAllChartsPngOffscreen(); // 再一次產生六張圖
      setState(() {});                    // 讓 Share All 按鈕亮起
    }
  }

  SeriesBundle _buildOffsetSeriesForKind(SensorKind kind) {
    final buf = _sensor.buffer;
    switch (kind) {
      case SensorKind.accelerometer:
        return SeriesBundle(
          x: [for (final s in buf) Offset(s.t, s.ax)],
          y: [for (final s in buf) Offset(s.t, s.ay)],
          z: [for (final s in buf) Offset(s.t, s.az)],
          label: 'a (m/s²)',
        );
      case SensorKind.velocity:
        return SeriesBundle(
          x: _integrator.integrateOnce(buf, (s) => s.ax),
          y: _integrator.integrateOnce(buf, (s) => s.ay),
          z: _integrator.integrateOnce(buf, (s) => s.az),
          label: 'v (m/s)',
        );
      case SensorKind.displacement:
        return SeriesBundle(
          x: _integrator.integrateTwice(buf, (s) => s.ax),
          y: _integrator.integrateTwice(buf, (s) => s.ay),
          z: _integrator.integrateTwice(buf, (s) => s.az),
          label: 'x (m)',
        );
      case SensorKind.gyroscope:
        return SeriesBundle(
          x: [for (final s in buf) Offset(s.t, s.gx)],
          y: [for (final s in buf) Offset(s.t, s.gy)],
          z: [for (final s in buf) Offset(s.t, s.gz)],
          label: 'ω (rad/s)',
        );
      case SensorKind.orientation:
        return SeriesBundle(
          x: _integrator.integrateOnce(buf, (s) => s.gx),
          y: _integrator.integrateOnce(buf, (s) => s.gy),
          z: _integrator.integrateOnce(buf, (s) => s.gz),
          label: 'θ (rad)',
        );
      case SensorKind.magnetometer:
        return SeriesBundle(
          x: [for (final s in buf) Offset(s.t, s.mx)],
          y: [for (final s in buf) Offset(s.t, s.my)],
          z: [for (final s in buf) Offset(s.t, s.mz)],
          label: 'B (µT)',
        );
    }
  }

  // ====== 離屏輸出（單張） ======
  Future<String> _saveOneChartPngOffscreen(SensorKind kind) async {
    final built = _buildOffsetSeriesForKind(kind);
    final ui.Image img = await ImuChart.renderLinesToImage(
      series: [built.x, built.y, built.z],
      colors: const [_xColor, _yColor, _zColor],
      size: _currentPngSize(),
      bgColor: Theme.of(context).colorScheme.surface,
      xLabel: 't (sec)',
      yLabel: built.label,
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');

    String nameOf(SensorKind k) => switch (k) {
      SensorKind.accelerometer => 'acc',
      SensorKind.velocity      => 'vel',
      SensorKind.displacement  => 'disp',
      SensorKind.gyroscope     => 'gyro',
      SensorKind.orientation   => 'angle',
      SensorKind.magnetometer  => 'mag',
    };

    final file = File('${dir.path}/imu_${nameOf(kind)}_$ts.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ====== 離屏輸出（六張） ======
  Future<void> _saveAllChartsPngOffscreen() async {
    final buf = _sensor.buffer;
    if (buf.isEmpty) { _snack('沒有資料可輸出'); return; }

    _allPngPaths.clear();
    final kinds = <SensorKind>[
      SensorKind.accelerometer,
      SensorKind.velocity,
      SensorKind.displacement,
      SensorKind.gyroscope,
      SensorKind.orientation,
      SensorKind.magnetometer,
    ];
    for (final k in kinds) {
      final p = await _saveOneChartPngOffscreen(k);
      _allPngPaths.add(p);
    }
    _snack('已儲存 ${_allPngPaths.length} 張圖檔');
  }

  Size _currentPngSize() => const Size(1280, 720);

  Future<void> _shareCsv() async {
    if (_lastCsvPath == null) return;
    await Share.shareXFiles([XFile(_lastCsvPath!)], text: 'IMU CSV');
  }

  Future<void> _shareAllPngs() async {
    if (_allPngPaths.isEmpty) { _snack('尚未有圖檔'); return; }
    await Share.shareXFiles(_allPngPaths.map((p) => XFile(p)).toList(),
        text: 'IMU Charts');
  }

  Future<void> _saveCsv() async {
    final buf = _sensor.buffer;
    final vX = _integrator.integrateOnce(buf, (s) => s.ax);
    final vY = _integrator.integrateOnce(buf, (s) => s.ay);
    final vZ = _integrator.integrateOnce(buf, (s) => s.az);

    final pX = _integrator.integrateTwice(buf, (s) => s.ax);
    final pY = _integrator.integrateTwice(buf, (s) => s.ay);
    final pZ = _integrator.integrateTwice(buf, (s) => s.az);

    final rX = _integrator.integrateOnce(buf, (s) => s.gx);
    final rY = _integrator.integrateOnce(buf, (s) => s.gy);
    final rZ = _integrator.integrateOnce(buf, (s) => s.gz);

    final dir = await getApplicationDocumentsDirectory();
    final fname = 'imu_${DateTime.now().toIso8601String().replaceAll(":", "-")}.csv';
    final file = File('${dir.path}/$fname');
    final sb = StringBuffer();
    sb.writeln([
      't_sec',
      'acc_x','acc_y','acc_z',
      'gyro_x','gyro_y','gyro_z',
      'mag_x','mag_y','mag_z',
      'vel_x','vel_y','vel_z',
      'disp_x','disp_y','disp_z',
      'rad_x','rad_y','rad_z',
    ].join(','));
    final n = buf.length;
    for (int i = 0; i < n; i++) {
      final s = buf[i];
      String f(double x) => x.toStringAsFixed(6);
      sb.writeln([
        f(s.t),
        f(s.ax), f(s.ay), f(s.az),
        f(s.gx), f(s.gy), f(s.gz),
        f(s.mx), f(s.my), f(s.mz),
        f(vX[i].dy), f(vY[i].dy), f(vZ[i].dy),
        f(pX[i].dy), f(pY[i].dy), f(pZ[i].dy),
        f(rX[i].dy), f(rY[i].dy), f(rZ[i].dy),
      ].join(','));
    }
    await file.writeAsString(sb.toString(), flush: true);
    setState(() => _lastCsvPath = file.path);
    _snack('已儲存 CSV：$fname');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final latest = [
      ('ACC (m/s²)', _sensor.ax, _sensor.ay, _sensor.az),
      ('GYRO (rad/s)', _sensor.gx, _sensor.gy, _sensor.gz),
      ('MAG (µT)', _sensor.mx, _sensor.my, _sensor.mz),
    ];
    final built = _buildOffsetSeriesForKind(_chartKind);
    final buffer = _sensor.buffer;
    final viewportWidth = MediaQuery.of(context).size.width;

    Widget coloredDot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

    return Scaffold(
      appBar: AppBar(title: const Text('IMU Recorder')),
      body: Scrollbar(
        controller: _verticalScrollCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalScrollCtrl,
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: viewportWidth, maxWidth: viewportWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 控制列
                Wrap(
                  spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _NumBox(controller: _hzCtrl, label: 'X (Hz)'),
                    _NumBox(controller: _secCtrl, label: 'Y (秒)'),
                    ElevatedButton.icon(
                      onPressed: _isRecording ? null : _start,
                      icon: const Icon(Icons.fiber_manual_record),
                      label: const Text('Start'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isRecording ? () => _stop(save: true) : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _lastCsvPath == null ? null : _shareCsv,
                      icon: const Icon(Icons.share),
                      label: const Text('Share CSV'),
                    ),
                    // 用 Share All PNGs 取代單張存/單張分享
                    ElevatedButton.icon(
                      onPressed: _allPngPaths.isEmpty ? null : _shareAllPngs,
                      icon: const Icon(Icons.collections),
                      label: const Text('Share All PNGs'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 即時數值（有彩色點、有外框）
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: latest.map((row) {
                    final title = row.$1; final x = row.$2; final y = row.$3; final z = row.$4;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          coloredDot(_xColor), const SizedBox(width: 6), Text('x=${x.toStringAsFixed(3)}'),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          coloredDot(_yColor), const SizedBox(width: 6), Text('y=${y.toStringAsFixed(3)}'),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          coloredDot(_zColor), const SizedBox(width: 6), Text('z=${z.toStringAsFixed(3)}'),
                        ]),
                      ]),
                    );
                  }).toList(),
                ),

                // 圖表選擇器 + 圖例 + 樣本數
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Wrap(
                    spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('t:'),
                      DropdownButton<SensorKind>(
                        value: _chartKind,
                        items: const [
                          DropdownMenuItem(value: SensorKind.accelerometer, child: Text('Accelerometer (a)')),
                          DropdownMenuItem(value: SensorKind.velocity, child: Text('Velocity (m/s)(∫a dt)')),
                          DropdownMenuItem(value: SensorKind.displacement, child: Text('Displacement(m)(∫∫a dt²)')),
                          DropdownMenuItem(value: SensorKind.gyroscope, child: Text('Gyroscope (ω)')),
                          DropdownMenuItem(value: SensorKind.orientation, child: Text('Angle (rad)(∫ω dt)')),
                          DropdownMenuItem(value: SensorKind.magnetometer, child: Text('Magnetometer (B)')),
                        ],
                        onChanged: (v) => setState(() => _chartKind = v!),
                      ),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        coloredDot(_xColor), const SizedBox(width: 6), const Text('x'),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        coloredDot(_yColor), const SizedBox(width: 6), const Text('y'),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        coloredDot(_zColor), const SizedBox(width: 6), const Text('z'),
                      ]),
                      Text('樣本數: ${buffer.length}'),
                    ],
                  ),
                ),

                // 圖表
                SizedBox(
                  width: viewportWidth, height: 350,
                  child: RepaintBoundary(
                    key: _chartKey,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ImuChart(
                        seriesX: built.x,
                        seriesY: built.y,
                        seriesZ: built.z,
                        yLabel: built.label,
                        maxX: buffer.isEmpty ? 1 : buffer.last.t,
                        colorX: _xColor,
                        colorY: _yColor,
                        colorZ: _zColor,
                      ),
                    ),
                  ),
                ),

                if (_lastCsvPath != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(_lastCsvPath!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    )),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _shareCsv,
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Share', style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 小元件
class _NumBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _NumBox({required this.controller, required this.label});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'X (Hz)',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}
