import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keep_sims/core/fx/fx_context.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/core/providers/locale_provider.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

const profileLanguages = <String, String>{
  'en': 'English',
  'es': 'Español',
  'hi': 'हिन्दी',
  'ur': 'اردو',
  'tr': 'Türkçe',
  'si': 'සිංහල',
  'ne': 'नेपाली',
  'bn': 'বাংলা',
  'ar': 'العربية',
};

Future<void> showDisplayCurrencySheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.cardColor,
      builder: (_) => const _RegionalPicker(currency: true),
    );

Future<void> showProfileLanguageSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.cardColor,
      builder: (_) => const _RegionalPicker(currency: false),
    );

class _RegionalPicker extends ConsumerStatefulWidget {
  const _RegionalPicker({required this.currency});
  final bool currency;
  @override
  ConsumerState<_RegionalPicker> createState() => _RegionalPickerState();
}

class _RegionalPickerState extends ConsumerState<_RegionalPicker> {
  bool _saving = false;
  String? _error;

  Future<void> _select(String code) async {
    if (_saving) return;
    final loc = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.currency) {
        final saved = await ref
            .read(fxControllerProvider.notifier)
            .setDisplayCurrency(code);
        if (!saved) throw StateError(loc.fxCurrencySaveFailed);
      } else {
        await ref
            .read(userPreferencesControllerProvider.notifier)
            .updateLanguage(code);
        if (!mounted) return;
        final saved = ref.read(userPreferencesControllerProvider);
        if (saved.hasError || saved.value?.language != code) {
          throw StateError(loc.profileSaveFailed);
        }
        await ref
            .read(localeControllerProvider.notifier)
            .setLocale(Locale(code));
        if (!mounted) return;
        ref.invalidate(userPreferencesControllerProvider);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = widget.currency
              ? loc.fxCurrencySaveFailed
              : loc.profileSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final fx = ref.watch(fxControllerProvider);
    final prefs = ref.watch(userPreferencesControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final isLoading = widget.currency
        ? fx.isLoading && !fx.hasValue
        : prefs.isLoading && !prefs.hasValue;
    final hasError = widget.currency ? fx.hasError : prefs.hasError;
    final options = fx.value?.available;
    final currencies = options != null && options.isNotEmpty
        ? options
        : const [
            FxCurrencyOption(code: 'USD', name: 'US Dollar', symbol: r'$'),
          ];
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.currency ? loc.profileCurrency : loc.selectAppLanguage,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.currency) ...[
                  const SizedBox(height: 8),
                  Text(
                    loc.profileCurrencyHint,
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_saving) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.colorScheme.error),
                    ),
                  ),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : hasError
                      ? Center(
                          child: TextButton.icon(
                            onPressed: () => widget.currency
                                ? ref.invalidate(fxControllerProvider)
                                : ref.invalidate(
                                    userPreferencesControllerProvider,
                                  ),
                            icon: const Icon(Icons.refresh),
                            label: Text(loc.retry),
                          ),
                        )
                      : ListView(
                          children: widget.currency
                              ? [
                                  for (final option in currencies)
                                    ListTile(
                                      enabled: !_saving,
                                      leading: SizedBox(
                                        width: 40,
                                        child: Text(option.symbol),
                                      ),
                                      title: Text(
                                        '${option.name} (${option.code})',
                                      ),
                                      trailing:
                                          option.code ==
                                              fx.value?.requestedCurrency
                                          ? Icon(
                                              Icons.check_circle,
                                              color: context.primaryColor,
                                            )
                                          : null,
                                      onTap: () => _select(option.code),
                                    ),
                                ]
                              : [
                                  for (final language
                                      in profileLanguages.entries)
                                    ListTile(
                                      enabled: !_saving,
                                      title: Text(language.value),
                                      trailing:
                                          language.key == locale.languageCode
                                          ? Icon(
                                              Icons.check_circle,
                                              color: context.primaryColor,
                                            )
                                          : null,
                                      onTap: () => _select(language.key),
                                    ),
                                ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
