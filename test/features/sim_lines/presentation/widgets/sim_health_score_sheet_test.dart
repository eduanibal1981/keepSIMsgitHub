import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';
import 'package:keep_sims/features/sim_lines/domain/sim_line_health.dart';
import 'package:keep_sims/features/sim_lines/presentation/widgets/sim_health_score_sheet.dart';

void main() {
  testWidgets('SimHealthScoreSheet displays score and achieved / non-achieved pillars correctly', (tester) async {
    const simLine = SimLine(
      id: 'test-line',
      userId: 'test-user',
      phoneNumber: '+201098971020',
      status: 'active',
      isCarrierVerified: true,
      healthScore: 50,
    );

    // Scenario: 2 pillars achieved (Live verify, Auto-notify), 1 not achieved (Recharge)
    final pillars = [
      const HealthScorePillar(
        type: HealthScorePillarType.realLiveVerification,
        title: 'Real Live Verification',
        description: 'SIM is live-verified on the mobile network via telecom signaling',
        earnedPoints: 25,
        maxPoints: 25,
        isAchieved: true,
        icon: Icons.cell_tower_rounded,
        actionLabel: 'Verify Line',
      ),
      const HealthScorePillar(
        type: HealthScorePillarType.autoNotify,
        title: 'Auto-Notify Alerts',
        description: 'Automated reminder alerts are active',
        earnedPoints: 25,
        maxPoints: 25,
        isAchieved: true,
        icon: Icons.notifications_active_outlined,
        actionLabel: 'Set Auto-Notify',
      ),
      const HealthScorePillar(
        type: HealthScorePillarType.recentRecharge,
        title: 'Active Recharge Window',
        description: 'No recharge recorded yet. Update your last recharge date',
        earnedPoints: 0,
        maxPoints: 50,
        isAchieved: false,
        icon: Icons.calendar_today_outlined,
        actionLabel: 'Update Recharge',
      ),
    ];

    bool rechargeActionCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  SimHealthScoreSheet.show(
                    context: context,
                    line: simLine,
                    pillars: pillars,
                    score: 50,
                    tier: 'standard',
                    countryName: 'Egypt',
                    onUpdateRecharge: () {
                      rechargeActionCalled = true;
                    },
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    );

    // Tap to open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    expect(find.text('SIM Health Breakdown'), findsOneWidget);
    expect(find.text('Standard · Egypt'), findsOneWidget);
    expect(find.text('50'), findsWidgets);
    expect(find.text('Moderate Protection'), findsOneWidget);

    // Verify Achieved Badges (+25 pts) - 2 achieved pillars
    expect(find.text('+25 pts'), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));

    // Verify Non-Achieved Badges (Not achieved) - 1 unachieved pillar
    expect(find.text('Not achieved'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

    // Verify Action button for Update Recharge is present
    expect(find.text('Update Recharge'), findsOneWidget);

    // Scroll into view and tap Update Recharge action button
    await tester.ensureVisible(find.text('Update Recharge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Recharge'));
    await tester.pumpAndSettle();

    // Verify action was called and sheet closed
    expect(rechargeActionCalled, isTrue);
    expect(find.text('SIM Health Breakdown'), findsNothing);
  });
}
