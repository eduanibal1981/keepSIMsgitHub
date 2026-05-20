import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:keep_sims/core/theme/app_colors.dart';

/// A reusable premium shimmer skeleton box.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: const Color(0xFF2D2D52),
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle 
              ? BorderRadius.circular(borderRadius) 
              : null,
        ),
      ),
    );
  }
}

/// Shimmer loader tailored for the main dashboard screen layout.
class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Header: Greeting and avatar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonLoader(width: 140, height: 16),
                    SizedBox(height: 8),
                    SkeletonLoader(width: 220, height: 28),
                  ],
                ),
                const SkeletonLoader(width: 50, height: 50, borderRadius: 25, shape: BoxShape.circle),
              ],
            ),
            const SizedBox(height: 30),

            // Health status card / Quick Metrics
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.darkCard.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.darkBorder.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonLoader(width: 120, height: 16),
                      SkeletonLoader(width: 80, height: 16),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const SkeletonLoader(width: 70, height: 70, shape: BoxShape.circle),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonLoader(width: 160, height: 20),
                            SizedBox(height: 8),
                            SkeletonLoader(width: 110, height: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Quick Actions grid header
            const SkeletonLoader(width: 120, height: 22),
            const SizedBox(height: 16),

            // Grid: 4 Action Buttons
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkCard.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.darkBorder.withOpacity(0.5)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonLoader(width: 36, height: 36, borderRadius: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLoader(width: 80, height: 14),
                          SizedBox(height: 6),
                          SkeletonLoader(width: 50, height: 10),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 35),

            // Protection Timeline / Active lines header
            const SkeletonLoader(width: 150, height: 22),
            const SizedBox(height: 16),

            // List of 3 mock protected lines
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const SkeletonLoader(width: 44, height: 44, borderRadius: 12),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonLoader(width: 120, height: 16),
                            SizedBox(height: 6),
                            SkeletonLoader(width: 180, height: 12),
                          ],
                        ),
                      ),
                      const SkeletonLoader(width: 60, height: 26, borderRadius: 13),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loader matched to the SIM list and SIM lines filters.
class SIMLinesShimmer extends StatelessWidget {
  const SIMLinesShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter tabs shimmer
          Row(
            children: const [
              SkeletonLoader(width: 80, height: 36, borderRadius: 18),
              SizedBox(width: 10),
              SkeletonLoader(width: 90, height: 36, borderRadius: 18),
              SizedBox(width: 10),
              SkeletonLoader(width: 100, height: 36, borderRadius: 18),
            ],
          ),
          const SizedBox(height: 24),

          // Vertical list of SIM Cards
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.darkBorder.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SkeletonLoader(width: 42, height: 42, borderRadius: 12),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                SkeletonLoader(width: 140, height: 18),
                                SizedBox(height: 6),
                                SkeletonLoader(width: 90, height: 12),
                              ],
                            ),
                          ),
                          const SkeletonLoader(width: 65, height: 26, borderRadius: 13),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Progress Bar Shimmer
                      const SkeletonLoader(width: double.infinity, height: 8, borderRadius: 4),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          SkeletonLoader(width: 100, height: 12),
                          SkeletonLoader(width: 60, height: 12),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Action buttons row shimmer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: const [
                          SkeletonLoader(width: 90, height: 32, borderRadius: 8),
                          SizedBox(width: 12),
                          SkeletonLoader(width: 120, height: 32, borderRadius: 8),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer loader representing credit card layouts and ledger entries.
class WalletShimmer extends StatelessWidget {
  const WalletShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card visual balance visualizer
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.darkCard.withOpacity(0.5),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.darkBorder.withOpacity(0.5)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonLoader(width: 100, height: 14),
                      SkeletonLoader(width: 45, height: 25, borderRadius: 6),
                    ],
                  ),
                  const SkeletonLoader(width: 180, height: 36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonLoader(width: 140, height: 16),
                      SkeletonLoader(width: 50, height: 16),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Top-up options capsule shimmer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkCard.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonLoader(width: 110, height: 16),
                  SkeletonLoader(width: 70, height: 32, borderRadius: 16),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Recent Transactions Ledger
            const SkeletonLoader(width: 160, height: 22),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const SkeletonLoader(width: 40, height: 40, shape: BoxShape.circle),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonLoader(width: 150, height: 15),
                            SizedBox(height: 6),
                            SkeletonLoader(width: 90, height: 11),
                          ],
                        ),
                      ),
                      const SkeletonLoader(width: 60, height: 18),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer loader for in-app messaging logs.
class NotificationsShimmer extends StatelessWidget {
  const NotificationsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonLoader(width: 120, height: 22),
              SkeletonLoader(width: 80, height: 16),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.darkBorder.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonLoader(width: 36, height: 36, shape: BoxShape.circle),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonLoader(width: 150, height: 16),
                            SizedBox(height: 8),
                            SkeletonLoader(width: double.infinity, height: 12),
                            SizedBox(height: 6),
                            SkeletonLoader(width: 180, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
