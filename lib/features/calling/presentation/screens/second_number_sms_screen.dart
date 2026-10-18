import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:keep_sims/l10n/app_localizations.dart';
import '../../data/models/second_number_models.dart';
import '../../data/models/virtual_did_model.dart';
import '../controllers/second_number_controller.dart';

class SecondNumberSmsScreen extends ConsumerStatefulWidget {
  final VirtualDidNumber did;
  const SecondNumberSmsScreen({super.key, required this.did});
  @override
  ConsumerState<SecondNumberSmsScreen> createState() =>
      _SecondNumberSmsScreenState();
}

class _SecondNumberSmsScreenState extends ConsumerState<SecondNumberSmsScreen>
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
      ref.invalidate(didMessagesProvider(widget.did.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.snMessages),
            Text(
              widget.did.phoneNumber,
              textDirection: TextDirection.ltr,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: ref
          .watch(didMessagesProvider(widget.did.id))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.snInboxUnavailable),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(didMessagesProvider(widget.did.id)),
                      child: Text(l.snRetry),
                    ),
                  ],
                ),
              ),
            ),
            data: (messages) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(l.snReceiveOnly, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                if (messages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Center(child: Text(l.snNoMessages)),
                  ),
                ...messages.map(
                  (message) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Icon(
                        message.isRead
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(message.senderNumber),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            message.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat.yMMMd(
                              Localizations.localeOf(context).toLanguageTag(),
                            ).add_jm().format(message.receivedAt.toLocal()),
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      onTap: () => _open(message),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.snVerification, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
    );
  }

  Future<void> _open(SecondNumberMessage message) async {
    final l = AppLocalizations.of(context)!;
    if (!message.isRead) {
      await ref
          .read(secondNumberActionsProvider.notifier)
          .readMessage(message.id);
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message.senderNumber,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              l.snUnverifiedSender,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            SelectableText(message.body),
            const SizedBox(height: 22),
            if (message.extractedOtp != null)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(l.snCodeCandidate),
                      const SizedBox(height: 10),
                      SelectableText(
                        message.extractedOtp!,
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: message.extractedOtp!),
                          );
                          HapticFeedback.selectionClick();
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(
                              sheetContext,
                            ).showSnackBar(SnackBar(content: Text(l.snCopied)));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: Text(l.snCopyCode),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              l.snPrivateNotifications,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
