// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SupportTicketsNotifier)
final supportTicketsProvider = SupportTicketsNotifierProvider._();

final class SupportTicketsNotifierProvider
    extends
        $AsyncNotifierProvider<SupportTicketsNotifier, List<SupportTicket>> {
  SupportTicketsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportTicketsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportTicketsNotifierHash();

  @$internal
  @override
  SupportTicketsNotifier create() => SupportTicketsNotifier();
}

String _$supportTicketsNotifierHash() =>
    r'd8e2daaafdbe8c1cae734bd4d2991f97722758b5';

abstract class _$SupportTicketsNotifier
    extends $AsyncNotifier<List<SupportTicket>> {
  FutureOr<List<SupportTicket>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<SupportTicket>>, List<SupportTicket>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<SupportTicket>>, List<SupportTicket>>,
              AsyncValue<List<SupportTicket>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ticketMessagesStream)
final ticketMessagesStreamProvider = TicketMessagesStreamFamily._();

final class TicketMessagesStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TicketMessage>>,
          List<TicketMessage>,
          Stream<List<TicketMessage>>
        >
    with
        $FutureModifier<List<TicketMessage>>,
        $StreamProvider<List<TicketMessage>> {
  TicketMessagesStreamProvider._({
    required TicketMessagesStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ticketMessagesStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ticketMessagesStreamHash();

  @override
  String toString() {
    return r'ticketMessagesStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TicketMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TicketMessage>> create(Ref ref) {
    final argument = this.argument as String;
    return ticketMessagesStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TicketMessagesStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ticketMessagesStreamHash() =>
    r'af56a9a3d1cd4751df5fa8ca58f1854ea74da131';

final class TicketMessagesStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TicketMessage>>, String> {
  TicketMessagesStreamFamily._()
    : super(
        retry: null,
        name: r'ticketMessagesStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TicketMessagesStreamProvider call(String ticketId) =>
      TicketMessagesStreamProvider._(argument: ticketId, from: this);

  @override
  String toString() => r'ticketMessagesStreamProvider';
}

@ProviderFor(supportTicketDetail)
final supportTicketDetailProvider = SupportTicketDetailFamily._();

final class SupportTicketDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<SupportTicket>,
          SupportTicket,
          FutureOr<SupportTicket>
        >
    with $FutureModifier<SupportTicket>, $FutureProvider<SupportTicket> {
  SupportTicketDetailProvider._({
    required SupportTicketDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'supportTicketDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$supportTicketDetailHash();

  @override
  String toString() {
    return r'supportTicketDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SupportTicket> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SupportTicket> create(Ref ref) {
    final argument = this.argument as String;
    return supportTicketDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SupportTicketDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$supportTicketDetailHash() =>
    r'8ea60c0484797635c899ec0dbda2694517e4ba2d';

final class SupportTicketDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SupportTicket>, String> {
  SupportTicketDetailFamily._()
    : super(
        retry: null,
        name: r'supportTicketDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SupportTicketDetailProvider call(String ticketId) =>
      SupportTicketDetailProvider._(argument: ticketId, from: this);

  @override
  String toString() => r'supportTicketDetailProvider';
}
