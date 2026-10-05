import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/device_alarm_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/providers/sim_line_alert_clock_provider.dart';

/// Keep the local, opted-in alarm synchronized while the signed-in app runs.
class DeviceAlarmSync extends ConsumerStatefulWidget {
  const DeviceAlarmSync({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<DeviceAlarmSync> createState() => _DeviceAlarmSyncState();
}

class _DeviceAlarmSyncState extends ConsumerState<DeviceAlarmSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(simLinesControllerProvider);
      ref.invalidate(simLineAlertClockForLineProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(deviceAlarmControllerProvider);
    return widget.child;
  }
}
