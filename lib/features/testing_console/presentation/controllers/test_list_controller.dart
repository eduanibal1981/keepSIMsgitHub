import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/test_case.dart';
import '../../data/repositories/test_repository.dart';

part 'test_list_controller.g.dart';

@riverpod
class TestListController extends _$TestListController {
  @override
  FutureOr<List<TestCase>> build() async {
    return _fetchTestCases();
  }

  Future<List<TestCase>> _fetchTestCases() async {
    final repo = ref.read(testRepositoryProvider);
    return repo.getTestCases();
  }

  Future<void> updateTestStatus(String id, String status) async {
    final previousState = state;
    
    // Optimistic update
    if (state.value != null) {
      final updatedList = state.value!.map((tc) {
        if (tc.id == id) {
          return tc.copyWith(status: status);
        }
        return tc;
      }).toList();
      state = AsyncData(updatedList);
    }

    try {
      final repo = ref.read(testRepositoryProvider);
      await repo.updateTestStatus(id, status);
      // Re-fetch to ensure sync with db if needed, or keep optimistic
    } catch (e, st) {
      state = previousState;
      state = AsyncError(e, st);
    }
  }

  Future<void> updateAiRequest(String id, String request) async {
    final previousState = state;

    // Optimistic update
    if (state.value != null) {
      final updatedList = state.value!.map((tc) {
        if (tc.id == id) {
          return tc.copyWith(aiTaskRequest: request);
        }
        return tc;
      }).toList();
      state = AsyncData(updatedList);
    }

    try {
      final repo = ref.read(testRepositoryProvider);
      await repo.updateTestAiRequest(id, request);
    } catch (e, st) {
      state = previousState;
      state = AsyncError(e, st);
    }
  }
}
