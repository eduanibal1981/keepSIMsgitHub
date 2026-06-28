// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SupportController)
final supportControllerProvider = SupportControllerProvider._();

final class SupportControllerProvider
    extends $AsyncNotifierProvider<SupportController, List<SupportTicket>> {
  SupportControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportControllerHash();

  @$internal
  @override
  SupportController create() => SupportController();
}

String _$supportControllerHash() => r'a40f5462cae78d072c2687d3dfa674f58f2ae026';

abstract class _$SupportController extends $AsyncNotifier<List<SupportTicket>> {
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
