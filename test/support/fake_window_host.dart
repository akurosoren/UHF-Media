import 'dart:async';
import 'dart:ui';

import 'package:uhf_media/features/shell/window_host.dart';

class FakeWindowHost implements WindowHost {
  final calls = <String>[];
  Rect bounds = const Rect.fromLTWH(100, 50, 1100, 780);
  final _events = StreamController<WindowEvent>.broadcast();

  void emit(WindowEvent e) => _events.add(e);

  @override
  Stream<WindowEvent> get events => _events.stream;
  @override
  Future<void> maximize() async => calls.add('maximize');
  @override
  Future<void> unmaximize() async => calls.add('unmaximize');
  @override
  Future<void> minimize() async => calls.add('minimize');
  @override
  Future<void> close() async => calls.add('close');
  @override
  Future<void> setFullScreen(bool value) async => calls.add('fullscreen $value');
  @override
  Future<void> setAlwaysOnTop(bool value) async => calls.add('top $value');
  @override
  Future<void> setTitle(String title) async => calls.add('title $title');
  @override
  Future<void> startDragging() async => calls.add('drag');
  @override
  Future<void> bringToFront() async => calls.add('front');
  @override
  Future<Rect> getBounds() async => bounds;
}
