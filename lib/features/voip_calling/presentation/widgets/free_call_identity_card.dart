import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/features/calling/presentation/widgets/verify_caller_id_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:keep_sims/l10n/app_localizations.dart';
import 'package:keep_sims/l10n/app_localizations_en.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/free_call_identity_controller.dart';

AppLocalizations freeCallStrings(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

class FreeCallIdentityCard extends ConsumerWidget {
  const FreeCallIdentityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = freeCallStrings(context);
    return ref
        .watch(freeCallIdentityProvider)
        .when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (_, _) => TextButton.icon(
            onPressed: () => ref.invalidate(freeCallIdentityProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l.freeCallIdentityRetry),
          ),
          data: (identity) => Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '${l.freeCallMyId}: ${identity.publicId}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.freeCallMyId,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        identity.publicId,
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: l.freeCallCopyId,
                icon: const Icon(Icons.copy_outlined, size: 20),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: identity.publicId),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l.freeCallIdCopied)));
                  }
                },
              ),
              IconButton(
                tooltip: l.freeCallShareId,
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: () async {
                  final box = context.findRenderObject() as RenderBox?;
                  try {
                    await Share.share(
                      '${l.freeCallMyId}: ${identity.publicId}',
                      sharePositionOrigin: box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.freeCallPrivacyError)),
                      );
                    }
                  }
                },
              ),
              IconButton(
                tooltip: l.freeCallPrivacy,
                icon: const Icon(Icons.tune, size: 20),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const FreeCallPrivacySheet(),
                ),
              ),
            ],
          ),
        );
  }
}

class FreeCallPrivacySheet extends ConsumerStatefulWidget {
  const FreeCallPrivacySheet({super.key});
  @override
  ConsumerState<FreeCallPrivacySheet> createState() =>
      _FreeCallPrivacySheetState();
}

class _FreeCallPrivacySheetState extends ConsumerState<FreeCallPrivacySheet> {
  bool _saving = false;
  String? _error;
  Future<void> _save(Future<void> Function() action) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _error = freeCallStrings(context).freeCallPrivacyError);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = freeCallStrings(context);
    final controller = ref.read(freeCallIdentityProvider.notifier);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.freeCallPrivacy,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ref
                  .watch(freeCallIdentityProvider)
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => TextButton(
                      onPressed: () => ref.invalidate(freeCallIdentityProvider),
                      child: Text(l.freeCallIdentityRetry),
                    ),
                    data: (identity) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.freeCallIdDiscovery),
                          value: identity.discoverById,
                          onChanged: _saving
                              ? null
                              : (value) => _save(
                                  () => controller.setDiscovery(
                                    byId: value,
                                    byEmail: identity.discoverByEmail,
                                  ),
                                ),
                        ),
                        Text(
                          l.freeCallIdMeaning,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.freeCallEmailDiscovery),
                          subtitle: Text(l.freeCallEmailConsent),
                          value: identity.discoverByEmail,
                          onChanged: _saving || !identity.emailVerified
                              ? null
                              : (value) => _save(
                                  () => controller.setDiscovery(
                                    byId: identity.discoverById,
                                    byEmail: value,
                                  ),
                                ),
                        ),
                        const Divider(),
                        Text(l.freeCallPhoneConsent),
                        if (identity.phones.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(l.freeCallNoVerifiedPhones),
                          ),
                        for (final phone in identity.phones)
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              phone.phone,
                              textDirection: TextDirection.ltr,
                            ),
                            value: phone.enabled,
                            onChanged: _saving
                                ? null
                                : (value) => _save(
                                    () =>
                                        controller.setPhone(phone.phone, value),
                                  ),
                          ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (_) => const VerifyCallerIdSheet(),
                                  ).then((_) {
                                    if (mounted) {
                                      ref.invalidate(freeCallIdentityProvider);
                                    }
                                  });
                                },
                          child: Text(l.freeCallVerifyPhone),
                        ),
                        if (identity.blocked.isNotEmpty) ...[
                          const Divider(),
                          Text(l.freeCallBlockedAccounts),
                          for (final blocked in identity.blocked)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(blocked.name),
                              trailing: TextButton(
                                onPressed: _saving
                                    ? null
                                    : () => _save(
                                        () => controller.setBlocked(
                                          blocked.userId,
                                          false,
                                        ),
                                      ),
                                child: Text(l.freeCallUnblock),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
              if (_saving) const LinearProgressIndicator(),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
