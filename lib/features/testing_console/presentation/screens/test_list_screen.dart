import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/test_case.dart';
import '../controllers/test_list_controller.dart';
import 'package:collection/collection.dart'; // For groupBy

class TestListScreen extends ConsumerWidget {
  const TestListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(testListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Testing Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(testListControllerProvider);
            },
          )
        ],
      ),
      body: state.when(
        data: (tests) {
          if (tests.isEmpty) {
            return const Center(child: Text('No tests found.'));
          }

          // Group by feature_group
          final grouped = groupBy(tests, (TestCase tc) => tc.featureGroup);
          final groups = grouped.entries.toList();

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _buildFeatureGroup(context, ref, group.key, group.value);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildFeatureGroup(
      BuildContext context, WidgetRef ref, String groupName, List<TestCase> tests) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          groupName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${tests.where((t) => t.status == 'passed').length} / ${tests.length} Passed'),
        initiallyExpanded: true,
        children: tests.map((tc) => _buildTestCaseTile(context, ref, tc)).toList(),
      ),
    );
  }

  Widget _buildTestCaseTile(BuildContext context, WidgetRef ref, TestCase tc) {
    Color statusColor;
    IconData statusIcon;

    switch (tc.status) {
      case 'passed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'needs_review':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(tc.testName, style: const TextStyle(fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              _statusChip(ref, tc.id, 'passed', 'Pass', Colors.green, tc.status == 'passed'),
              const SizedBox(width: 4),
              _statusChip(ref, tc.id, 'failed', 'Fail', Colors.red, tc.status == 'failed'),
              const SizedBox(width: 4),
              _statusChip(ref, tc.id, 'needs_review', 'Review', Colors.orange, tc.status == 'needs_review'),
            ],
          ),
          if (tc.aiTaskRequest != null && tc.aiTaskRequest!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'AI Task: ${tc.aiTaskRequest}',
                style: TextStyle(color: AppColors.primary, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.add_comment),
        onPressed: () => _showAddAiRequestDialog(context, ref, tc),
      ),
    );
  }

  Widget _statusChip(
      WidgetRef ref, String id, String status, String label, Color color, bool isSelected) {
    return InkWell(
      onTap: () {
        ref.read(testListControllerProvider.notifier).updateTestStatus(id, status);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _showAddAiRequestDialog(BuildContext context, WidgetRef ref, TestCase tc) async {
    final textController = TextEditingController(text: tc.aiTaskRequest);
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add AI Task Request'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: 'e.g. Please solve the issue in this test',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(testListControllerProvider.notifier).updateAiRequest(tc.id, textController.text);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
