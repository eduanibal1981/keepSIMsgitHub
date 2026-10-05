import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keep_sims/core/fx/fx_provider.dart';
import 'package:keep_sims/core/providers/locale_provider.dart';
import 'package:keep_sims/core/result.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/auth/model/auth_model.dart';
import 'package:keep_sims/features/dashboard/presentation/controller/perspective_drawer_controller.dart';
import 'package:keep_sims/features/notifications/data/models/channel_destination.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:keep_sims/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:keep_sims/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:keep_sims/features/profile/presentation/controller/profile_controller.dart';
import 'package:keep_sims/features/settings/presentation/widgets/regional_preferences_sheets.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/l10n/app_localizations.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
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
    if (state == AppLifecycleState.resumed) _refreshContacts();
  }

  void _refreshContacts() {
    ref.invalidate(profileNotificationEmailStatusProvider);
    ref.invalidate(notificationChannelsControllerProvider);
  }

  Future<void> _editContact(String type) async {
    await NotificationSettingsScreen.showChannelSheet(context, type);
    if (mounted) _refreshContacts();
  }

  Future<void> _editProfile(UserProfile profile) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.cardColor,
    builder: (_) => _EditProfileSheet(profile: profile),
  );

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: SafeArea(
        child: ref
            .watch(authControllerProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _LoadError(
                onRetry: () => ref.invalidate(authControllerProvider),
              ),
              data: (profile) => profile == null
                  ? _LoadError(onRetry: () => context.go(AppRoutes.login))
                  : _content(profile, loc),
            ),
      ),
    );
  }

  Widget _content(UserProfile profile, AppLocalizations loc) {
    final channels = ref.watch(notificationChannelsControllerProvider);
    final emailStatus = ref.watch(profileNotificationEmailStatusProvider);
    final email = emailStatus.value;
    final notificationEmail =
        email?.currentEmail ?? email?.accountEmail ?? profile.email;
    final emailVerified =
        email?.currentEmail?.isNotEmpty == true &&
        (email?.alternateEmail != null || email?.accountEmailVerified == true);
    final whatsappRows = channels.value?.where(
      (c) => c['channel_type'] == 'whatsapp',
    );
    final whatsapp = whatsappRows != null && whatsappRows.isNotEmpty
        ? channelDestination(
            'whatsapp',
            Map<String, dynamic>.from(whatsappRows.first['config'] ?? {}),
          )
        : '';
    final locale = ref.watch(localeControllerProvider);
    final fx = ref.watch(fxControllerProvider);
    final sims = ref.watch(simLinesControllerProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final currency = fx.value;
    // This label describes the saved preference, not a converted money value.
    final code = profile.preferredCurrency;
    final matching = currency?.available.where((option) => option.code == code);
    final currencyName = matching != null && matching.isNotEmpty
        ? '${matching.first.name} ($code)'
        : code;
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final timezone =
        '${now.timeZoneName} (GMT${offset.isNegative ? '-' : '+'}'
        '${offset.inHours.abs().toString().padLeft(2, '0')}:'
        '${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')})';

    return RefreshIndicator(
      onRefresh: () async {
        _refreshContacts();
        ref.invalidate(authControllerProvider);
        ref.invalidate(simLinesControllerProvider);
        ref.invalidate(fxControllerProvider);
        try {
          await ref.read(authControllerProvider.future);
        } catch (_) {
          // The watched auth state presents a retry action on refresh failure.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.profileTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: loc.profileNotifications,
                onPressed: () => context.push(AppRoutes.notifications),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 9 ? '9+' : '$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
              IconButton(
                tooltip: loc.navMore,
                onPressed: () => ref
                    .read(perspectiveDrawerControllerProvider.notifier)
                    .toggle(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Group(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _editProfile(profile),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _ProfileAvatar(profile: profile),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName?.trim().isNotEmpty == true
                                  ? profile.fullName!
                                  : loc.keepSIMsUser,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              loc.profilePersonalAccount,
                              style: TextStyle(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _Section(loc.profileContactDetails),
          _Group(
            children: [
              _ProfileRow(
                icon: Icons.mail_outline,
                title: loc.profileNotificationEmail,
                subtitle: emailStatus.isLoading ? '…' : notificationEmail,
                status: emailStatus.hasError
                    ? loc.profileCheckStatus
                    : emailStatus.isLoading
                    ? null
                    : emailVerified
                    ? loc.profileVerified
                    : loc.profileVerify,
                confirmed:
                    emailVerified &&
                    !emailStatus.hasError &&
                    !emailStatus.isLoading,
                onTap: () => _editContact('email'),
              ),
              const _RowDivider(),
              _ProfileRow(
                icon: Icons.chat_bubble_outline,
                title: loc.profileWhatsAppNumber,
                subtitle: channels.isLoading
                    ? '…'
                    : channels.hasError
                    ? loc.profileLoadFailed
                    : whatsapp.isEmpty
                    ? loc.profileAddNumber
                    : whatsapp,
                status: whatsapp.isNotEmpty ? loc.profileSavedStatus : null,
                onTap: () => _editContact('whatsapp'),
              ),
              if (emailStatus.hasError || channels.hasError)
                TextButton.icon(
                  onPressed: _refreshContacts,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(loc.retry),
                ),
            ],
          ),
          _Section(loc.profilePreferences),
          _Group(
            children: [
              _ProfileRow(
                icon: Icons.language,
                title: loc.profilePreferredLanguage,
                subtitle:
                    profileLanguages[locale.languageCode] ??
                    locale.languageCode,
                onTap: () => showProfileLanguageSheet(context),
              ),
              const _RowDivider(),
              _ProfileRow(
                icon: Icons.schedule,
                title: loc.profileTimeZone,
                subtitle: timezone,
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  useSafeArea: true,
                  backgroundColor: context.cardColor,
                  builder: (_) => SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.profileTimeZone,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(timezone),
                          const SizedBox(height: 12),
                          Text(loc.profileDeviceTimeZoneHint),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const _RowDivider(),
              _ProfileRow(
                icon: Icons.currency_exchange,
                title: loc.profileCurrency,
                subtitle: fx.isLoading ? '…' : currencyName,
                onTap: () => showDisplayCurrencySheet(context),
              ),
              if (currency?.isFallingBack == true ||
                  (!fx.isLoading &&
                      code != 'USD' &&
                      currency?.currency != code))
                Padding(
                  padding: const EdgeInsets.fromLTRB(64, 0, 16, 14),
                  child: Text(
                    loc.profileCurrencyUnavailable,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          _Section(loc.profileAccount),
          _Group(
            children: [
              _ProfileRow(
                icon: Icons.sim_card_outlined,
                title: loc.profileSavedSims,
                subtitle: sims.when(
                  loading: () => '…',
                  error: (_, _) => loc.profileLoadFailed,
                  data: (lines) => loc.dashboardSimLineCount(lines.length),
                ),
                onTap: () => context.push(AppRoutes.simLines),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => _editProfile(profile),
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: Text(loc.profileEdit),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.profile});
  final UserProfile profile;
  @override
  Widget build(BuildContext context) {
    final country = profile.homeCountryCode?.toUpperCase() ?? '';
    final flag = RegExp(r'^[A-Z]{2}$').hasMatch(country)
        ? String.fromCharCodes(country.codeUnits.map((c) => c + 127397))
        : '🌐';
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.primaryColor.withValues(alpha: .06),
        border: Border.all(color: context.primaryColor.withValues(alpha: .18)),
      ),
      child: ClipOval(
        child: profile.avatarUrl?.isNotEmpty == true
            ? Image.network(
                profile.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(flag, style: const TextStyle(fontSize: 32)),
                ),
              )
            : Center(child: Text(flag, style: const TextStyle(fontSize: 32))),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: context.isDarkMode ? context.colorScheme.surfaceContainerLow : Colors.white,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 64,
    endIndent: 16,
    color: context.colorScheme.outlineVariant.withValues(alpha: .5),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.status,
    this.confirmed = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final String? status;
  final bool confirmed;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Icon(icon, size: 25),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: context.primaryColor.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (confirmed) ...[
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: context.primaryColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    status!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 21),
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(AppLocalizations.of(context)!.profileLoadFailed),
        TextButton(
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context)!.retry),
        ),
      ],
    ),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});
  final UserProfile profile;
  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  String? _country;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName ?? '');
    final country = widget.profile.homeCountryCode?.toUpperCase();
    _country = country != null && RegExp(r'^[A-Z]{2}$').hasMatch(country)
        ? country
        : null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    final loc = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(profileControllerProvider.notifier)
        .updateDetails(fullName: _name.text, homeCountryCode: _country ?? '');
    if (!mounted) return;
    switch (result) {
      case Success():
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text(loc.profileSaved)));
      case Failure():
        setState(() {
          _saving = false;
          _error = loc.profileSaveFailed;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(profileControllerProvider);
    final loc = AppLocalizations.of(context)!;
    final countries = ref.watch(supportedCountriesProvider);
    final countryNames = {
      for (final c in countries.value ?? []) c.isoCode.toUpperCase(): c.name,
    };
    if (_country != null && !countryNames.containsKey(_country)) {
      countryNames[_country!] = _country!;
    }
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.profileEdit,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: loc.profileFullName),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? loc.profileNameRequired
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _country,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: loc.profileHomeCountry,
                    ),
                    items: [
                      for (final c in countryNames.entries)
                        DropdownMenuItem(
                          value: c.key,
                          child: Text(c.value, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _country = value),
                    validator: (value) =>
                        value == null ? loc.profileCountryRequired : null,
                  ),
                  if (countries.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (countries.hasError)
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(supportedCountriesProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text(loc.retry),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: context.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(loc.saveChanges),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
