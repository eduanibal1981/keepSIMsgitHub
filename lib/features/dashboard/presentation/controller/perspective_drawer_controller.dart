/// SIM Shield — Perspective Drawer Controller
///
/// Controls the open/closed state of the 3D cascading perspective drawer.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'perspective_drawer_controller.g.dart';

@riverpod
class PerspectiveDrawerController extends _$PerspectiveDrawerController {
  @override
  bool build() => false;

  void open() => state = true;
  void close() => state = false;
  void toggle() => state = !state;
}
