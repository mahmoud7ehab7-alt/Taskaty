import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/task_service.dart';
import '../services/productivity_service.dart';
import '../widgets/export_report_dialog.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  final TaskService taskService;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateChanged;

  const AnalyticsScreen({
    super.key,
    required this.taskService,
    this.selectedDate,
    this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: taskService,
      builder: (context, _) {
        final tasks = taskService.tasks;
    final targetDate = selectedDate ?? DateTime.now();
    final dailyStats = ProductivityService.getDailyStats(tasks, date: targetDate);
    final weeklyStats = ProductivityService.getWeeklyStats(tasks, referenceDate: targetDate);
    final thisMonthStats = ProductivityService.getMonthlyStats(tasks);
    final lastMonthStats = ProductivityService.getLastMonthStats(tasks);
    final last7Days = ProductivityService.getLast7DaysStats(tasks);
    final streakStats = ProductivityService.getStreak(tasks);

    final now = DateTime.now();
    final isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = targetDate.year == yesterday.year && targetDate.month == yesterday.month && targetDate.day == yesterday.day;
    final dayBeforeYesterday = now.subtract(const Duration(days: 2));
    final isDayBeforeYesterday = targetDate.year == dayBeforeYesterday.year && targetDate.month == dayBeforeYesterday.month && targetDate.day == dayBeforeYesterday.day;

    String dayLabel;
    if (isToday) {
      dayLabel = 'اليوم';
    } else if (isYesterday) {
      dayLabel = 'أمس';
    } else if (isDayBeforeYesterday) {
      dayLabel = 'أول أمس';
    } else {
      try {
        dayLabel = DateFormat('EEEE d MMMM', 'ar').format(targetDate);
      } catch (_) {
        dayLabel = DateFormat('MM/dd').format(targetDate);
      }
    }

    final heroTitle = isToday
        ? 'ملخص النشاط اليوم'
        : (isYesterday ? 'ملخص نشاط الأمس' : (isDayBeforeYesterday ? 'ملخص نشاط أول أمس' : 'ملخص نشاط ($dayLabel)'));
    final heroSubtitle = isToday
        ? 'معدل الإنجاز اليومي ⚡'
        : 'معدل إنجاز $dayLabel ⚡';
    final dailyMetricTitle = isToday
        ? 'إنتاجية اليوم'
        : (isYesterday ? 'إنتاجية الأمس' : (isDayBeforeYesterday ? 'إنتاجية أول أمس' : 'إنتاجية $dayLabel'));

    // Productivity comparison vs last month
    final double monthDiff = thisMonthStats.rate - lastMonthStats.rate;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'معدلات الإنتاجية والأداء 📊',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'تصدير التقرير',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ExportReportDialog(tasks: tasks),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date Navigation Bar
          _buildDateNavigationBar(context, targetDate),
          const SizedBox(height: 12),

          // Header Card
          _buildSummaryHero(context, dailyStats, title: heroTitle, subtitle: heroSubtitle),
          const SizedBox(height: 16),

          // Productive Hours Dedicated Section
          _buildProductiveHoursSection(context, dailyStats, weeklyStats, thisMonthStats, dailyLabel: dayLabel),
          const SizedBox(height: 16),

          // Streak Card
          _buildStreakCard(context, streakStats),
          const SizedBox(height: 20),

          // Productivity Cards Grid (اليوم، الأسبوع، هذا الشهر، الشهر الماضي)
          const Text(
            'مؤشرات الفترات الزمنية ⏱️',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: dailyMetricTitle,
                  rate: dailyStats.rate,
                  completed: dailyStats.completed,
                  total: dailyStats.total,
                  hoursText: dailyStats.formattedProductiveHours,
                  icon: isToday ? Icons.today_rounded : Icons.event_available_rounded,
                  color: AppTheme.accentInfo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'إنتاجية الأسبوع',
                  rate: weeklyStats.rate,
                  completed: weeklyStats.completed,
                  total: weeklyStats.total,
                  hoursText: weeklyStats.formattedProductiveHours,
                  icon: Icons.date_range_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'الشهر الحالي',
                  rate: thisMonthStats.rate,
                  completed: thisMonthStats.completed,
                  total: thisMonthStats.total,
                  hoursText: thisMonthStats.formattedProductiveHours,
                  icon: Icons.calendar_month_rounded,
                  color: AppTheme.accentSuccess,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'الشهر الماضي',
                  rate: lastMonthStats.rate,
                  completed: lastMonthStats.completed,
                  total: lastMonthStats.total,
                  hoursText: lastMonthStats.formattedProductiveHours,
                  icon: Icons.history_rounded,
                  color: AppTheme.accentWarning,
                  subtitle: lastMonthStats.total == 0
                      ? 'لا توجد بيانات'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Monthly Comparison Card
          _buildMonthComparisonCard(context, thisMonthStats, lastMonthStats, monthDiff),
          const SizedBox(height: 24),

          // 7-day Weekly Visual Bar Chart
          const Text(
            'معدل إنجاز آخر 7 أيام 📈',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildWeeklyBarChart(context, last7Days),
          const SizedBox(height: 24),

          // Overall Stats & Insights
          const Text(
            'نصائح تعزيز الإنتاجية 💡',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildTipCard(
            context,
            icon: Icons.stars_rounded,
            title: 'قاعدة الـ 3 مهام الأساسية',
            desc: 'حدد 3 مهام رئيسية كل صباح وابدأ بها، إنجازها يرفع معدل إنتاجيتك ويمنحك زخماً قوياً طوال اليوم.',
          ),
          const SizedBox(height: 10),
          _buildTipCard(
            context,
            icon: Icons.checklist_rtl_rounded,
            title: 'تقسيم المهام الكبيرة (Sub-tasks)',
            desc: 'المهمة المعقدة تصبح سهلة عندما تقسمها إلى خطوات صغيرة واضحة يمكن شطبها واحدة تلو الأخرى.',
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildProductiveHoursSection(
    BuildContext context,
    ProductivityStats daily,
    ProductivityStats weekly,
    ProductivityStats monthly, {
    String dailyLabel = 'اليوم',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F4450) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_filled_rounded, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'الساعات المنتجة (Focus Time) ⏱️',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$dailyLabel: ${daily.formattedProductiveHours}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildHourMiniTile(
                  label: dailyLabel,
                  value: daily.formattedProductiveHours,
                  planned: 'المخطط: ${daily.formattedPlannedHours}',
                  color: AppTheme.primaryColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHourMiniTile(
                  label: 'هذا الأسبوع',
                  value: weekly.formattedProductiveHours,
                  planned: 'المخطط: ${weekly.formattedPlannedHours}',
                  color: AppTheme.accentInfo,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHourMiniTile(
                  label: 'هذا الشهر',
                  value: monthly.formattedProductiveHours,
                  planned: 'المخطط: ${monthly.formattedPlannedHours}',
                  color: AppTheme.accentSuccess,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourMiniTile({
    required String label,
    required String value,
    required String planned,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B191E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              planned,
              style: TextStyle(
                fontSize: 9.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context, StreakStats streak) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'سلسلة الالتزام (Streak)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${streak.currentStreak} أيام متتالية',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  streak.currentStreak > 0
                      ? 'رائع! واصل إنجاز مهامك يومياً للحفاظ على شعلة الالتزام 🔥'
                      : 'أنجز مهام اليوم لتبدأ سلسلة التزام جديدة وتصل لأعلى معدل 🚀',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                if (streak.bestStreak > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '🏆 أفضل سلسلة سابقة: ${streak.bestStreak} يوم متتالي',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateNavigationBar(BuildContext context, DateTime targetDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;

    String dateString;
    try {
      dateString = DateFormat('EEEE، d MMMM', 'ar').format(targetDate);
    } catch (_) {
      dateString = DateFormat('yyyy/MM/dd').format(targetDate);
    }

    String dayTag = '';
    final yesterday = now.subtract(const Duration(days: 1));
    final dayBeforeYesterday = now.subtract(const Duration(days: 2));
    if (isToday) {
      dayTag = 'اليوم';
    } else if (targetDate.year == yesterday.year && targetDate.month == yesterday.month && targetDate.day == yesterday.day) {
      dayTag = 'أمس';
    } else if (targetDate.year == dayBeforeYesterday.year && targetDate.month == dayBeforeYesterday.month && targetDate.day == dayBeforeYesterday.day) {
      dayTag = 'أول أمس';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A32) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1F4450) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          // Previous Day button
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 24),
            tooltip: 'اليوم السابق',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final newDate = targetDate.subtract(const Duration(days: 1));
              onDateChanged?.call(newDate);
            },
          ),

          // Date Display & Picker
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: targetDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  helpText: 'اختر يوماً لاستعراض إنتاجيته',
                  confirmText: 'اختيار',
                  cancelText: 'إلغاء',
                );
                if (picked != null) {
                  onDateChanged?.call(picked);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: isToday ? AppTheme.primaryColor : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dayTag.isNotEmpty ? '$dayTag - $dateString' : dateString,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : Colors.orangeAccent,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Return to Today button (if not today)
          if (!isToday) ...[
            InkWell(
              onTap: () => onDateChanged?.call(DateTime.now()),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.today_rounded, size: 14, color: AppTheme.primaryColor),
                    SizedBox(width: 4),
                    Text(
                      'اليوم',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],

          // Next Day button
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
            tooltip: 'اليوم التالي',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              final newDate = targetDate.add(const Duration(days: 1));
              onDateChanged?.call(newDate);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHero(
    BuildContext context,
    ProductivityStats daily, {
    String subtitle = 'معدل الإنجاز اليومي ⚡',
    String title = 'ملخص النشاط اليوم',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF132A32), const Color(0xFF0B191E)]
              : [const Color(0xFF0D9488), const Color(0xFF0F766E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  daily.percentageFormatted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: daily.total == 0 ? 0 : (daily.rate / 100),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentSuccess),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أنجزت ${daily.completed} من ${daily.total} مهام',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Flexible(
                child: Text(
                  daily.motivationalFeedback,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required double rate,
    required int completed,
    required int total,
    required String hoursText,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F4450) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? '$completed من $total • $hoursText ⏱️',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthComparisonCard(
    BuildContext context,
    ProductivityStats current,
    ProductivityStats last,
    double diff,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBetter = diff >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F4450) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isBetter ? AppTheme.accentSuccess : AppTheme.accentDanger)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBetter ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: isBetter ? AppTheme.accentSuccess : AppTheme.accentDanger,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مقارنة بالشهر الماضي',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  last.total == 0
                      ? 'الشهر الماضي لم يحتوي على مهام مسجلة بعد.'
                      : (isBetter
                          ? 'أداؤك تحسن بنسبة +${diff.toStringAsFixed(0)}% مقارنة بالشهر السابق! رائع 👏'
                          : 'انخفض معدل الإنجاز بـ ${diff.abs().toStringAsFixed(0)}% مقارنة بالشهر السابق.'),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBarChart(BuildContext context, List<DayStat> days) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F4450) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final barHeight = day.total == 0 ? 8.0 : (day.rate / 100) * 100.0 + 8.0;
          final isToday = day.date.day == DateTime.now().day &&
              day.date.month == DateTime.now().month;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${day.rate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isToday
                      ? AppTheme.primaryColor
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 18,
                height: barHeight.clamp(8.0, 108.0),
                decoration: BoxDecoration(
                  color: day.total == 0
                      ? (isDark ? Colors.white12 : Colors.grey.shade200)
                      : (isToday ? AppTheme.primaryColor : AppTheme.accentSuccess),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                day.dayName.substring(0, 3),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday
                      ? AppTheme.primaryColor
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              Text(
                '${day.productiveHours.toStringAsFixed(1)}س',
                style: TextStyle(
                  fontSize: 9.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTipCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A32) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1F4450) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
