import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/calling/data/models/call_record_model.dart';
import 'package:keep_sims/features/calling/presentation/controllers/calling_controller.dart';
import 'package:keep_sims/features/calling/presentation/controllers/smart_call_dialer_controller.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_history_tile.dart';
import 'package:keep_sims/features/calling/presentation/widgets/call_review_sheet.dart';

/// International call history. Every redial first opens the shared review.
class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  bool _reviewingCall = false;

  String _text(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  Future<void> _review(CallRecord record) async {
    if (_reviewingCall) return;
    _reviewingCall = true;
    ref
        .read(smartCallDialerProvider.notifier)
        .setNumber(record.destinationNumber);
    try {
      await CallReviewSheet.showAndCall(
        context,
        ref,
        suggestedCountryIso: ref
            .read(authControllerProvider)
            .asData
            ?.value
            ?.homeCountryCode,
      );
    } finally {
      _reviewingCall = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(callHistoryStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_text('Recent calls', 'المكالمات الأخيرة')),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.calling);
            }
          },
        ),
      ),
      body: history.when(
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _text('No recent calls', 'لا توجد مكالمات أخيرة'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _text(
                        'Your international calls will appear here.',
                        'ستظهر مكالماتك الدولية هنا.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) => CallHistoryTile(
              record: records[index],
              onRedial: () => _review(records[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _text(
                    'Could not load recent calls.',
                    'تعذر تحميل المكالمات الأخيرة.',
                  ),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => ref.invalidate(callHistoryStreamProvider),
                  child: Text(_text('Retry', 'إعادة المحاولة')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
