import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:keep_sims/core/theme/app_colors.dart';
import 'package:keep_sims/core/utils/build_context_extension.dart';
import 'package:keep_sims/features/sim_lines/data/models/sim_line_model.dart';

import 'dashboard_sim_line_card.dart';

/// Keeps the page controller mounted when width, text scale or schedules change.
class DashboardSimLineCarousel extends StatefulWidget {
  final List<SimLine> lines;

  const DashboardSimLineCarousel({super.key, required this.lines});

  @override
  State<DashboardSimLineCarousel> createState() =>
      _DashboardSimLineCarouselState();
}

class _DashboardSimLineCarouselState extends State<DashboardSimLineCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant DashboardSimLineCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.lines.length && widget.lines.isNotEmpty) {
      _index = widget.lines.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(_index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) return const SizedBox.shrink();
    // The shared provider sorts by nickname. Dashboard numbering instead follows
    // creation order; undated legacy records stay before newly added lines.
    final lines = [...widget.lines]
      ..sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate != null) return -1;
        if (bDate == null && aDate != null) return 1;
        final byDate = aDate != null && bDate != null
            ? aDate.compareTo(bDate)
            : 0;
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = lines
            .map(
              (line) => DashboardSimCardLayout.of(context, width, line).height,
            )
            .reduce(math.max);
        return Column(
          children: [
            SizedBox(
              key: const ValueKey('dashboard-sim-carousel-pages'),
              height: height,
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _index = index),
                itemCount: lines.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.zero,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: double.infinity,
                      height: DashboardSimCardLayout.of(
                        context,
                        width,
                        lines[index],
                      ).height,
                      child: DashboardSimLineCard(
                        key: ValueKey(lines[index].id),
                        line: lines[index],
                        lineNumber: index + 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.lines.length > 1) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.lines.length,
                  (index) => AnimatedContainer(
                    key: ValueKey('dashboard-sim-page-$index'),
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _index == index ? 12 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _index == index
                          ? context.primaryColor
                          : (context.isDarkMode
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight)
                                .withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
