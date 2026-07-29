/// SIM Shield — "Pin to Lock Screen" action (G4)
///
/// The only way a Live Activity ever starts. Nothing auto-pins itself: a Lock
/// Screen is the most intrusive surface the app can reach, so it takes a tap.
///
/// Renders nothing at all unless the platform can actually show one, which
/// means it is invisible on Android, on the desktop targets and in tests — no
/// dead button anywhere it cannot work.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/widgets/haptic_helper.dart';
import 'package:keep_sims/features/home_widget/data/live_activity_service.dart';
import 'package:keep_sims/features/home_widget/domain/widget_snapshot.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/data/models/usage_forecast_model.dart';

class LiveActivityPinButton extends ConsumerStatefulWidget {
  final SimLine line;
  final UsageForecast? forecast;

  const LiveActivityPinButton({
    super.key,
    required this.line,
    this.forecast,
  });

  @override
  ConsumerState<LiveActivityPinButton> createState() =>
      _LiveActivityPinButtonState();
}

class _LiveActivityPinButtonState extends ConsumerState<LiveActivityPinButton> {
  bool _pinned = false;
  bool _busy = false;

  /// Resolved once. Asking the platform on every rebuild would fire a channel
  /// call per frame of the detail screen's animations.
  late final Future<bool> _supported = ref
      .read(liveActivityServiceProvider)
      .isSupported();

  /// Reuses the same builder the home-screen widget publishes through, so the
  /// Lock Screen can never disagree with the widget about the same line.
  WidgetSubject? get _subject {
    final snapshot = buildWidgetSnapshot(
      signedIn: true,
      now: DateTime.now(),
      lines: [widget.line],
      forecasts: [if (widget.forecast != null) widget.forecast!],
    );
    return snapshot.subjects.isEmpty ? null : snapshot.subjects.first;
  }

  Future<void> _toggle() async {
    final subject = _subject;
    if (subject == null || _busy) return;

    setState(() => _busy = true);
    final service = ref.read(liveActivityServiceProvider);
    final bool ok = _pinned
        ? await service.end(subject.id)
        : await service.start(subject);

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _pinned = !_pinned;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _supported,
      builder: (context, snapshot) {
        if (snapshot.data != true || _subject == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    HapticHelper.lightTick();
                    _toggle();
                  },
            icon: Icon(
              _pinned ? Icons.lock_clock : Icons.push_pin_outlined,
              size: 18,
            ),
            label: Text(
              _pinned ? 'Unpin from Lock Screen' : 'Pin to Lock Screen',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }
}
