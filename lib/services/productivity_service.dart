import '../models/task.dart';

class ProductivityStats {
  final int total;
  final int completed;
  final double rate; // 0.0 to 100.0 (calculated based on hours/planned duration)
  final double productiveHours; // hours spent on completed tasks
  final double plannedHours;     // total hours planned
  final double completedPlannedHours; // planned hours of completed tasks

  const ProductivityStats({
    required this.total,
    required this.completed,
    required this.rate,
    this.productiveHours = 0.0,
    this.plannedHours = 0.0,
    this.completedPlannedHours = 0.0,
  });

  String get percentageFormatted => '${rate.toStringAsFixed(0)}%';

  String get formattedProductiveHours {
    if (productiveHours <= 0) return '0 س';
    final h = productiveHours.floor();
    final m = ((productiveHours - h) * 60).round();
    if (h == 0) return '$m د';
    if (m == 0) return '$h ساعة';
    return '$h س $m د';
  }

  String get formattedPlannedHours {
    if (plannedHours <= 0) return '0 س';
    final h = plannedHours.floor();
    final m = ((plannedHours - h) * 60).round();
    if (h == 0) return '$m د';
    if (m == 0) return '$h ساعة';
    return '$h س $m د';
  }

  String get motivationalFeedback {
    if (total == 0) return 'لا توجد مهام مسجلة بعد';
    if (rate >= 90) return 'إنجاز أسطوري! إنتاجيتك في القمة 🚀🔥';
    if (rate >= 75) return 'عمل رائع جداً! حافظ على هذا الزخم 💪✨';
    if (rate >= 50) return 'أداء جيد، أنجزت أكثر من النصف! استمر 🎯';
    if (rate > 0) return 'بداية طيبة، خطوة بخطوة تكتمل المهام 🌱';
    return 'ابدأ بإنجاز أول مهمة اليوم لتنشيط مؤشر الإنتاجية ⚡';
  }
}

class DayStat {
  final String dayName;
  final DateTime date;
  final int total;
  final int completed;
  final double rate;
  final double productiveHours;

  DayStat({
    required this.dayName,
    required this.date,
    required this.total,
    required this.completed,
    required this.rate,
    this.productiveHours = 0.0,
  });
}

class ProductivityService {
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Daily Stats for a specific date (defaults to today)
  static ProductivityStats getDailyStats(List<Task> tasks, {DateTime? date}) {
    final target = date ?? DateTime.now();
    final dayTasks = tasks.where((t) => _isSameDay(t.date, target)).toList();

    final total = dayTasks.length;
    final completedTasks = dayTasks.where((t) => t.isCompleted).toList();
    final completed = completedTasks.length;

    final plannedMinutes = dayTasks.fold<int>(0, (sum, t) => sum + t.effectiveMinutes);
    final completedPlannedMinutes = dayTasks.fold<double>(0, (sum, t) => sum + t.effectivePlannedMinutesAchieved);
    final rate = plannedMinutes == 0 ? 0.0 : ((completedPlannedMinutes / plannedMinutes) * 100).clamp(0.0, 100.0);

    final productiveMinutes = dayTasks.fold<double>(0, (sum, t) => sum + t.effectiveProductiveMinutesAchieved);

    return ProductivityStats(
      total: total,
      completed: completed,
      rate: rate,
      productiveHours: productiveMinutes / 60.0,
      plannedHours: plannedMinutes / 60.0,
      completedPlannedHours: completedPlannedMinutes / 60.0,
    );
  }

  // Weekly Stats
  static ProductivityStats getWeeklyStats(List<Task> tasks, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: (now.weekday % 7)));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    final weekTasks = tasks.where((t) {
      return (t.date.isAfter(weekStart) || _isSameDay(t.date, weekStart)) &&
             (t.date.isBefore(weekEnd) || _isSameDay(t.date, weekEnd));
    }).toList();

    final total = weekTasks.length;
    final completedTasks = weekTasks.where((t) => t.isCompleted).toList();
    final completed = completedTasks.length;

    final plannedMinutes = weekTasks.fold<int>(0, (sum, t) => sum + t.effectiveMinutes);
    final completedPlannedMinutes = weekTasks.fold<double>(0, (sum, t) => sum + t.effectivePlannedMinutesAchieved);
    final rate = plannedMinutes == 0 ? 0.0 : ((completedPlannedMinutes / plannedMinutes) * 100).clamp(0.0, 100.0);

    final productiveMinutes = weekTasks.fold<double>(0, (sum, t) => sum + t.effectiveProductiveMinutesAchieved);

    return ProductivityStats(
      total: total,
      completed: completed,
      rate: rate,
      productiveHours: productiveMinutes / 60.0,
      plannedHours: plannedMinutes / 60.0,
      completedPlannedHours: completedPlannedMinutes / 60.0,
    );
  }

  // Monthly Stats
  static ProductivityStats getMonthlyStats(List<Task> tasks, {int? year, int? month}) {
    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;

    final monthTasks = tasks.where((t) {
      return t.date.year == targetYear && t.date.month == targetMonth;
    }).toList();

    final total = monthTasks.length;
    final completedTasks = monthTasks.where((t) => t.isCompleted).toList();
    final completed = completedTasks.length;

    final plannedMinutes = monthTasks.fold<int>(0, (sum, t) => sum + t.effectiveMinutes);
    final completedPlannedMinutes = monthTasks.fold<double>(0, (sum, t) => sum + t.effectivePlannedMinutesAchieved);
    final rate = plannedMinutes == 0 ? 0.0 : ((completedPlannedMinutes / plannedMinutes) * 100).clamp(0.0, 100.0);

    final productiveMinutes = monthTasks.fold<double>(0, (sum, t) => sum + t.effectiveProductiveMinutesAchieved);

    return ProductivityStats(
      total: total,
      completed: completed,
      rate: rate,
      productiveHours: productiveMinutes / 60.0,
      plannedHours: plannedMinutes / 60.0,
      completedPlannedHours: completedPlannedMinutes / 60.0,
    );
  }

  // Last Month Stats
  static ProductivityStats getLastMonthStats(List<Task> tasks) {
    final now = DateTime.now();
    int lastMonth = now.month - 1;
    int lastYear = now.year;
    if (lastMonth == 0) {
      lastMonth = 12;
      lastYear -= 1;
    }
    return getMonthlyStats(tasks, year: lastYear, month: lastMonth);
  }

  // Last 7 days breakdown for bar chart
  static List<DayStat> getLast7DaysStats(List<Task> tasks, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final List<DayStat> stats = [];

    const arabicDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayTasks = tasks.where((t) => _isSameDay(t.date, date)).toList();
      final total = dayTasks.length;
      final completedTasks = dayTasks.where((t) => t.isCompleted).toList();
      final completed = completedTasks.length;

      final plannedMinutes = dayTasks.fold<int>(0, (sum, t) => sum + t.effectiveMinutes);
      final completedPlannedMinutes = dayTasks.fold<double>(0, (sum, t) => sum + t.effectivePlannedMinutesAchieved);
      final rate = plannedMinutes == 0 ? 0.0 : ((completedPlannedMinutes / plannedMinutes) * 100).clamp(0.0, 100.0);

      final productiveMinutes = dayTasks.fold<double>(0, (sum, t) => sum + t.effectiveProductiveMinutesAchieved);
      final dayName = arabicDays[date.weekday % 7];

      stats.add(DayStat(
        dayName: dayName,
        date: date,
        total: total,
        completed: completed,
        rate: rate,
        productiveHours: productiveMinutes / 60.0,
      ));
    }

    return stats;
  }

  // Streak Calculation (consecutive days with completed tasks)
  static StreakStats getStreak(List<Task> tasks) {
    if (tasks.isEmpty) return const StreakStats(currentStreak: 0, bestStreak: 0);

    final now = DateTime.now();
    int currentStreak = 0;
    int tempStreak = 0;
    int bestStreak = 0;

    final Map<String, List<Task>> tasksByDay = {};
    for (final t in tasks) {
      final key = "${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}";
      tasksByDay.putIfAbsent(key, () => []).add(t);
    }

    final Map<String, bool> daySuccessCache = {};
    for (final entry in tasksByDay.entries) {
      final dayList = entry.value;
      final completedTasksCount = dayList.where((t) => t.isCompleted).length;
      final plannedMinutes = dayList.fold<int>(0, (sum, t) => sum + t.effectiveMinutes);
      final completedPlannedMinutes = dayList.fold<double>(0, (sum, t) => sum + t.effectivePlannedMinutesAchieved);
      final rate = plannedMinutes == 0 ? 0.0 : ((completedPlannedMinutes / plannedMinutes) * 100);
      daySuccessCache[entry.key] = rate >= 60.0 || (dayList.length == 1 && (completedTasksCount > 0 || rate >= 50.0));
    }

    bool checkDaySuccess(DateTime d) {
      final key = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      return daySuccessCache[key] ?? false;
    }

    DateTime pointer = DateTime(now.year, now.month, now.day);
    if (checkDaySuccess(pointer)) {
      currentStreak++;
      pointer = pointer.subtract(const Duration(days: 1));
    } else {
      final yesterday = pointer.subtract(const Duration(days: 1));
      if (checkDaySuccess(yesterday)) {
        pointer = yesterday;
      }
    }

    while (checkDaySuccess(pointer)) {
      if (pointer != DateTime(now.year, now.month, now.day) || currentStreak == 0) {
        currentStreak++;
      }
      pointer = pointer.subtract(const Duration(days: 1));
    }

    for (int i = 365; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      if (checkDaySuccess(day)) {
        tempStreak++;
        if (tempStreak > bestStreak) bestStreak = tempStreak;
      } else {
        tempStreak = 0;
      }
    }

    if (currentStreak > bestStreak) bestStreak = currentStreak;

    return StreakStats(currentStreak: currentStreak, bestStreak: bestStreak);
  }

  // Category-Specific Helpers
  static ProductivityStats getCategoryDailyStats(List<Task> tasks, String category, {DateTime? date}) {
    final catTasks = tasks.where((t) => t.category == category).toList();
    return getDailyStats(catTasks, date: date);
  }

  static ProductivityStats getCategoryWeeklyStats(List<Task> tasks, String category, {DateTime? referenceDate}) {
    final catTasks = tasks.where((t) => t.category == category).toList();
    return getWeeklyStats(catTasks, referenceDate: referenceDate);
  }

  static ProductivityStats getCategoryMonthlyStats(List<Task> tasks, String category, {int? year, int? month}) {
    final catTasks = tasks.where((t) => t.category == category).toList();
    return getMonthlyStats(catTasks, year: year, month: month);
  }

  static List<DayStat> getCategory7DaysStats(List<Task> tasks, String category, {DateTime? referenceDate}) {
    final catTasks = tasks.where((t) => t.category == category).toList();
    return getLast7DaysStats(catTasks, referenceDate: referenceDate);
  }

  // Export report generator
  static String generateReport({
    required List<Task> tasks,
    required String type, // 'daily', 'weekly', 'monthly'
  }) {
    final now = DateTime.now();
    final buffer = StringBuffer();

    if (type == 'daily') {
      final stats = getDailyStats(tasks);
      final dayTasks = tasks.where((t) => _isSameDay(t.date, now)).toList();
      buffer.writeln('📋 تقرير الإنتاجية اليومي - Taskaty');
      buffer.writeln('📅 التاريخ: ${now.year}/${now.month}/${now.day}');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('⚡ معدل الإنجاز: ${stats.percentageFormatted}');
      buffer.writeln('⏱️ الساعات المنتجة: ${stats.formattedProductiveHours} (من أصل ${stats.formattedPlannedHours})');
      buffer.writeln('✅ المهام المكتملة: ${stats.completed} من أصل ${stats.total}');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('تفاصيل المهام:');
      for (final t in dayTasks) {
        final status = t.isCompleted ? '✓' : '✗';
        final timeStr = t.formattedTimeSlots.isNotEmpty ? ' (${t.formattedTimeSlots})' : '';
        String durationNote = ' - مخططة: ${t.formattedDuration}';
        if (t.isCompleted && t.actualDurationMinutes != null) {
          durationNote = ' - فعلي: ${t.formattedActualDuration} (مخطط: ${t.formattedDuration} | ${t.durationDifferenceText})';
        }
        buffer.writeln('$status ${t.title} [${t.category}]$timeStr$durationNote');
        for (final s in t.subtasks) {
          final subStatus = s.isCompleted ? '   └ [✓]' : '   └ [ ]';
          buffer.writeln('$subStatus ${s.title}');
        }
      }
    } else if (type == 'weekly') {
      final stats = getWeeklyStats(tasks);
      final streak = getStreak(tasks);
      buffer.writeln('📊 تقرير الإنتاجية الأسبوعي - Taskaty');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('⚡ معدل إنجاز الأسبوع: ${stats.percentageFormatted}');
      buffer.writeln('⏱️ إجمالي الساعات المنتجة: ${stats.formattedProductiveHours}');
      buffer.writeln('✅ إجمالي المهام المنجزة: ${stats.completed} من ${stats.total}');
      buffer.writeln('🔥 سلسلة الالتزام الحالية: ${streak.currentStreak} يوم متتالي');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    } else {
      final stats = getMonthlyStats(tasks);
      final lastStats = getLastMonthStats(tasks);
      buffer.writeln('📈 تقرير الإنتاجية الشهري - Taskaty');
      buffer.writeln('🗓️ شهر: ${now.month} / ${now.year}');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('⚡ معدل إنجاز الشهر: ${stats.percentageFormatted}');
      buffer.writeln('⏱️ الساعات المنتجة هذا الشهر: ${stats.formattedProductiveHours}');
      buffer.writeln('✅ المهام المنجزة: ${stats.completed} من ${stats.total}');
      buffer.writeln('⏮️ معدل الشهر الماضي: ${lastStats.percentageFormatted}');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    }

    buffer.writeln('\nتم الإنشاء بواسطة تطبيق تاسكاتي (Taskaty) ✨');
    return buffer.toString();
  }
}

class StreakStats {
  final int currentStreak;
  final int bestStreak;

  const StreakStats({required this.currentStreak, required this.bestStreak});
}
