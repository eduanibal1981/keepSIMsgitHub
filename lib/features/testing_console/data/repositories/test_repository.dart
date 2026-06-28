import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/test_case.dart';

part 'test_repository.g.dart';

abstract class TestRepository {
  Future<List<TestCase>> getTestCases();
  Future<void> updateTestStatus(String id, String status);
  Future<void> updateTestAiRequest(String id, String request);
}

class TestRepositoryImpl implements TestRepository {
  final SupabaseClient _supabase;

  TestRepositoryImpl({required SupabaseClient supabase}) : _supabase = supabase;

  @override
  Future<List<TestCase>> getTestCases() async {
    final response = await _supabase
        .from('test_cases')
        .select()
        .order('feature_group', ascending: true)
        .order('created_at', ascending: true);

    return (response as List).map((json) => TestCase.fromJson(json)).toList();
  }

  @override
  Future<void> updateTestStatus(String id, String status) async {
    await _supabase
        .from('test_cases')
        .update({'status': status})
        .eq('id', id);
  }

  @override
  Future<void> updateTestAiRequest(String id, String request) async {
    await _supabase
        .from('test_cases')
        .update({'ai_task_request': request})
        .eq('id', id);
  }
}

@riverpod
TestRepository testRepository(Ref ref) {
  return TestRepositoryImpl(supabase: Supabase.instance.client);
}
