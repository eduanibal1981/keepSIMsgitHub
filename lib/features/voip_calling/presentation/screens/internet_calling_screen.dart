import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import 'package:keep_sims/core/router/app_router.dart';
import 'package:keep_sims/features/auth/controller/auth_controller.dart';
import 'package:keep_sims/features/calling/data/services/device_contact_picker.dart';
import 'package:keep_sims/features/household/presentation/controllers/household_controller.dart';
import 'package:keep_sims/features/sim_lines/presentation/controllers/sim_lines_controller.dart';
import 'package:keep_sims/features/voip_calling/data/models/voip_call_session_model.dart';
import 'package:keep_sims/features/voip_calling/data/services/free_call_invitation_service.dart';
import 'package:keep_sims/features/voip_calling/domain/free_call_recipient.dart';
import 'package:keep_sims/features/voip_calling/domain/free_call_identity.dart';
import 'package:keep_sims/features/voip_calling/domain/free_call_history_group.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/free_call_review_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/controllers/voip_calling_controller.dart';
import 'package:keep_sims/features/voip_calling/presentation/widgets/free_call_review_sheet.dart';
import 'package:keep_sims/features/voip_calling/presentation/widgets/free_call_identity_card.dart';

/// Browsing is separate from account resolution; every action opens a review.
class InternetCallingScreen extends ConsumerStatefulWidget {
  final String? initialNumber;
  const InternetCallingScreen({super.key, this.initialNumber});
  @override
  ConsumerState<InternetCallingScreen> createState() =>
      _InternetCallingScreenState();
}

class _InternetCallingScreenState extends ConsumerState<InternetCallingScreen> {
  final _number = TextEditingController();
  bool _reviewing = false;
  bool _picking = false;
  String? _searchError;
  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String en, String ar) => _ar ? ar : en;
  @override
  void initState() {
    super.initState();
    _number.text = widget.initialNumber ?? '';
    if (_number.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final identifier = FreeCallIdentifier.parse(_number.text);
          _review(
            identifier == null
                ? FreeCallSelection(rawNumber: _number.text)
                : FreeCallSelection(identifier: identifier),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _review(FreeCallSelection selection) async {
    if (_reviewing) return;
    _reviewing = true;
    try {
      await FreeCallReviewSheet.showAndCall(
        context,
        ref,
        selection: selection,
        suggestedCountryIso: ref
            .read(authControllerProvider)
            .asData
            ?.value
            ?.homeCountryCode,
      );
    } finally {
      _reviewing = false;
    }
  }

  void _search() {
    if (_reviewing) return;
    final identifier = FreeCallIdentifier.parse(_number.text);
    if (identifier == null) {
      setState(
        () =>
            _searchError = freeCallStrings(context).freeCallCompleteIdentifier,
      );
      return;
    }
    setState(() => _searchError = null);
    _review(FreeCallSelection(identifier: identifier));
  }

  Future<void> _contacts() async {
    if (_picking || _reviewing) return;
    _picking = true;
    try {
      final number = await const DeviceContactPicker().pickPhoneNumber();
      if (!mounted || number == null || number.isEmpty) return;
      _number.text = number;
      await _review(FreeCallSelection(rawNumber: number));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Contacts are unavailable. Enter a number instead.',
                'جهات الاتصال غير متاحة. أدخل رقماً بدلاً من ذلك.',
              ),
            ),
          ),
        );
      }
    } finally {
      _picking = false;
    }
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await Share.share(
        ref.read(freeCallInvitationServiceProvider).message(arabic: _ar),
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Sharing is unavailable on this device.',
                'المشاركة غير متاحة على هذا الجهاز.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_t('Free Call', 'اتصال مجاني')),
          leading: BackButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.calling),
          ),
          actions: [
            IconButton(
              tooltip: _t('Invite a friend', 'دعوة صديق'),
              onPressed: _share,
              icon: const Icon(Icons.person_add_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FreeCallIdentityCard(),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _number,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.search,
                            autocorrect: false,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: MediaQuery.sizeOf(context).width < 380
                                  ? freeCallStrings(context).freeCallSearchShort
                                  : freeCallStrings(context).freeCallSearchHint,
                              errorText: _searchError,
                              errorMaxLines: 3,
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: freeCallStrings(
                                  context,
                                ).freeCallSearch,
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: _search,
                              ),
                            ),
                            onChanged: (_) =>
                                setState(() => _searchError = null),
                            onSubmitted: (_) => _search(),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _t(
                                    'Both of you need the KeepSIMs app for free calls.',
                                    'يجب أن يكون تطبيق KeepSIMs لدى كليكما لإجراء مكالمات مجانية.',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              IconButton(
                                onPressed: _contacts,
                                icon: const Icon(Icons.contacts_outlined),
                                tooltip: _t('Contacts', 'جهات الاتصال'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    TabBar(
                      tabs: [
                        Tab(text: _t('Recent', 'الأخيرة')),
                        Tab(text: _t('People', 'الأشخاص')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            body: TabBarView(children: [_recent(), _people()]),
          ),
        ),
      ),
    );
  }

  String _time(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    if (day == DateTime(now.year, now.month, now.day)) {
      return _t('Today', 'اليوم');
    }
    if (day ==
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 1))) {
      return _t('Yesterday', 'أمس');
    }
    return DateFormat.yMMMd(_ar ? 'ar' : 'en').format(local);
  }

  String _status(VoipCallSession session) {
    return switch (session.status) {
      'missed' || 'timeout' => _t('Missed', 'فائتة'),
      'declined' => _t('Declined', 'مرفوضة'),
      'busy' => _t('Busy', 'مشغول'),
      'failed' => _t('Failed', 'فشلت'),
      'completed' =>
        session.connectedAt == null
            ? _t('Not connected', 'لم تتصل')
            : '${_t(session.isOutgoing ? 'Outgoing' : 'Incoming', session.isOutgoing ? 'صادرة' : 'واردة')} ${session.formattedDuration}',
      _ => _t('Not connected', 'لم تتصل'),
    };
  }

  Widget _recent() => ref
      .watch(voipCallHistoryProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(voipCallHistoryProvider),
            child: Text(_t('Retry call history', 'إعادة تحميل سجل المكالمات')),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        _t(
                          'No recent free calls',
                          'لا توجد مكالمات مجانية حديثة',
                        ),
                      ),
                      TextButton(
                        onPressed: _share,
                        child: Text(_t('Invite a friend', 'دعوة صديق')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final filtered = filterFreeCallHistory(sessions, _number.text);
          if (filtered.isEmpty) {
            return Center(
              child: Text(freeCallStrings(context).freeCallNoRecentMatches),
            );
          }
          final groups = groupFreeCallHistory(filtered);
          return RefreshIndicator(
            onRefresh: () async {
              final _ = await ref.refresh(voipCallHistoryProvider.future);
            },
            child: ListView.separated(
              itemCount: groups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final group = groups[index];
                final latest = group.calls.first;
                final title = latest.peerName?.isNotEmpty == true
                    ? latest.peerName!
                    : latest.peerPublicId ??
                          latest.peerPhone ??
                          _t('KeepSIMs user', 'مستخدم KeepSIMs');
                final summary = group.calls.length == 1
                    ? _status(latest)
                    : '${group.calls.length} ${group.allMissed ? _t('missed calls', 'مكالمات فائتة') : _t('calls', 'مكالمات')}';
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(title),
                  subtitle: Text('$summary · ${_time(latest.startedAt)}'),
                  onTap: () => _historyDetails(group, title),
                  trailing: IconButton(
                    tooltip: _t('Review free call', 'مراجعة مكالمة مجانية'),
                    icon: const Icon(Icons.call_outlined),
                    onPressed: latest.peerId.isEmpty
                        ? null
                        : () => _review(
                            FreeCallSelection(knownUserId: latest.peerId),
                          ),
                  ),
                );
              },
            ),
          );
        },
      );

  void _historyDetails(FreeCallHistoryGroup group, String title) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView(
                  children: group.calls
                      .map(
                        (call) => ListTile(
                          leading: Icon(
                            call.isOutgoing
                                ? Icons.call_made
                                : Icons.call_received,
                          ),
                          title: Text(_status(call)),
                          subtitle: Text(
                            DateFormat.yMMMd(
                              _ar ? 'ar' : 'en',
                            ).add_jm().format(call.startedAt.toLocal()),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _people() {
    final household = ref.watch(householdControllerProvider);
    final lines = ref.watch(simLinesControllerProvider);
    final ownId = ref.watch(freeCallAccountProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_t('Family', 'العائلة')),
          trailing: TextButton(
            onPressed: () => context.push(AppRoutes.household),
            child: Text(_t('Manage', 'إدارة')),
          ),
        ),
        household.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(householdControllerProvider),
            child: Text(_t('Retry family', 'إعادة تحميل العائلة')),
          ),
          data: (state) {
            final members = state.members
                .where(
                  (m) =>
                      m.inviteStatus == 'accepted' &&
                      m.memberId != null &&
                      m.memberId != ownId,
                )
                .toList();
            if (members.isEmpty) {
              return Text(
                _t(
                  'No linked KeepSIMs contacts yet.',
                  'لا توجد جهات اتصال KeepSIMs مرتبطة بعد.',
                ),
              );
            }
            return Column(
              children: members
                  .map(
                    (member) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(member.memberName ?? member.memberEmail),
                      subtitle: Text(_t('On KeepSIMs', 'على KeepSIMs')),
                      trailing: const Icon(Icons.call_outlined),
                      onTap: () => _review(
                        FreeCallSelection(knownUserId: member.memberId),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (lines.asData?.value.isNotEmpty == true) ...[
          const SizedBox(height: 24),
          Text(
            _t('Managed numbers', 'الأرقام المُدارة'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            _t(
              'A SIM number does not necessarily identify another KeepSIMs account.',
              'رقم الشريحة لا يحدد بالضرورة حساب KeepSIMs آخر.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ...lines.asData!.value.map(
            (line) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.nickname ?? line.phoneNumber),
              subtitle: Text(
                line.phoneNumber,
                textDirection: TextDirection.ltr,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  _review(FreeCallSelection(rawNumber: line.phoneNumber)),
            ),
          ),
        ],
      ],
    );
  }
}
