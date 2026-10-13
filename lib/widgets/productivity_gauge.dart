import 'package:flutter/material.dart';
import '../services/productivity_service.dart';
import '../theme/app_theme.dart';

class ProductivityCard extends StatelessWidget {
  final ProductivityStats stats;
  final VoidCallback? onTap;

  const ProductivityCard({
    super.key,
    required this.stats,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color rateColor;
    if (stats.rate >= 80) {
      rateColor = AppTheme.accentSuccess;
    } else if (stats.rate >= 50) {
      rateColor = AppTheme.accentWarning;
    } else if (stats.rate > 0) {
      rateColor = AppTheme.primaryLight;
    } else {
      rateColor = isDark ? Colors.white38 : Colors.white60;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF132A32),
                    const Color(0xFF0B191E),
                  ]
                : [
                    const Color(0xFF0D9488),
                    const Color(0xFF0F766E),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF0D9488))
                  .withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Circular Progress Indicator
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: CircularProgressIndicator(
                          value: stats.total == 0 ? 0 : (stats.rate / 100),
                          strokeWidth: 6.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? rateColor : Colors.white,
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            stats.percentageFormatted,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                // Texts, Counters and Productive Hours
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إنتاجية اليوم',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Badges: Productive Hours & Tasks Count
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${stats.formattedProductiveHours} منجز',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${stats.completed} من ${stats.total} مهام',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stats.motivationalFeedback,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Linear Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: stats.total == 0 ? 0 : (stats.rate / 100),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? rateColor : const Color(0xFF2DD4BF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
