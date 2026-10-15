import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/productivity_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/task_item.dart';

class CategoryInfo {
  final String key;
  final String label;
  final String title;
  final IconData icon;
  final Color color;
  final Color lightBg;
  final Color darkBg;
  final String description;

  const CategoryInfo({
    required this.key,
    required this.label,
    required this.title,
    required this.icon,
    required this.color,
    required this.lightBg,
    required this.darkBg,
    required this.description,
  });
}

class CategoryScreen extends StatefulWidget {
  final TaskService taskService;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateChanged;

  const CategoryScreen({
    super.key,
    required this.taskService,
    this.selectedDate,
    this.onDateChanged,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String _selectedCategory = 'عمل';

  static const List<CategoryInfo> mainCategories = [
    CategoryInfo(
      key: 'عمل',
      label: 'عمل',
      title: 'مجال العمل 💼',
      icon: Icons.work_rounded,
      color: Color(0xFF0284C7), // Blue / Sky
      lightBg: Color(0xFFE0F2FE),
      darkBg: Color(0xFF0C243B),
      description: 'ساعات العمل والمشاريع والمهام المهنية 💼',
    ),
    CategoryInfo(
      key: 'دراسة',
      label: 'دراسة',
      title: 'مجال الدراسة 📚',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF8B5CF6), // Purple / Indigo
      lightBg: Color(0xFFEDE9FE),
      darkBg: Color(0xFF231445),
      description: 'ساعات المذاكرة، الدورات والتعلم المستمر 📚',
    ),
    CategoryInfo(
      key: 'صحة',
      label: 'صحة',
      title: 'مجال الصحة ❤️',
      icon: Icons.favorite_rounded,
      color: Color(0xFF10B981), // Emerald / Green
      lightBg: Color(0xFFD1FAE5),
      darkBg: Color(0xFF0B3326),
      description: 'الرياضة، التمارين، واللياقة البدنية والصحية ❤️',
    ),
    CategoryInfo(
      key: 'إنجليزي',
      label: 'إنجليزي',
      title: 'تعلم الإنجليزية 🇬🇧',
      icon: Icons.language_rounded,
      color: Color(0xFFF59E0B), // Amber / Warm Gold
      lightBg: Color(0xFFFEF3C7),
      darkBg: Color(0xFF382305),
      description: 'ساعات ممارسة الإنجليزية، المحادثة وتطوير اللغة 🇬🇧',
    ),
  ];

  static const CategoryInfo generalCategory = CategoryInfo(
    key: 'عام',
    label: 'عام',
    title: 'مهام عامة 📌',
    icon: Icons.label_outline_rounded,
    color: Color(0xFF64748B),
    lightBg: Color(0xFFF1F5F9),
    darkBg: Color(0xFF1E293B),
    description: 'المهام العامة والأنشطة المتنوعة 📌',
  );

  CategoryInfo get _activeInfo {
    for (final c in mainCategories) {
      if (c.key == _selectedCategory) return c;
    }
    return generalCategory;
  }

  void _openAddTask([String? category]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(
        initialDate: widget.selectedDate ?? DateTime.now(),
        initialCategory: category ?? _selectedCategory,
        onSave: (task) {
          widget.taskService.addTask(task);
        },
      ),
    );
  }

  void _pickDate(DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && widget.onDateChanged != null) {
      widget.onDateChanged!(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.taskService,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTasks = widget.taskService.tasks;
    final targetDate = widget.selectedDate ?? DateTime.now();

    // Stats for active category
    final dailyCatStats = ProductivityService.getCategoryDailyStats(
      allTasks,
      _selectedCategory,
      date: targetDate,
    );
    final weeklyCatStats = ProductivityService.getCategoryWeeklyStats(
      allTasks,
      _selectedCategory,
      referenceDate: targetDate,
    );
    final monthlyCatStats = ProductivityService.getCategoryMonthlyStats(
      allTasks,
      _selectedCategory,
      year: targetDate.year,
      month: targetDate.month,
    );
    final weekly7Days = ProductivityService.getCategory7DaysStats(
      allTasks,
      _selectedCategory,
      referenceDate: targetDate,
    );

    // Filter tasks for selected category and day
    final dayCatTasks = allTasks.where((t) {
      final isDay = t.date.year == targetDate.year &&
          t.date.month == targetDate.month &&
          t.date.day == targetDate.day;
      return isDay && t.category == _selectedCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تتبع المجالات 🎯',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_rounded),
            tooltip: 'إضافة مهمة في هذا المجال',
            onPressed: () => _openAddTask(_selectedCategory),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTask(_selectedCategory),
        backgroundColor: _activeInfo.color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('إضافة مهمة ${_activeInfo.label}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Date Navigator Bar
          _buildDateBar(context, targetDate, isDark),
          const SizedBox(height: 16),

          // 2. The 3 Main Category Sections (الأقسام الثلاثة الرئيسية)
          _buildCategorySelectorRow(context, allTasks, targetDate, isDark),
          const SizedBox(height: 16),

          // 3. Category Hero & Stats (اليوم، الأسبوع، الشهر)
          _buildCategoryStatsHero(
            context,
            dailyCatStats,
            weeklyCatStats,
            monthlyCatStats,
            targetDate,
            isDark,
          ),
          const SizedBox(height: 18),

          // 4. Weekly Trend / 7-Day Hours Chart for Active Category
          _buildWeeklyTrendSection(context, weekly7Days, targetDate, isDark),
          const SizedBox(height: 20),

          // 5. Today's Tasks in this Category
          _buildTodayCategoryTasks(context, dayCatTasks, targetDate, isDark),
          const SizedBox(height: 20),

          // 6. Cross-Category Balance (توزيع الساعات بين العمل والدراسة والصحة)
          _buildCategoriesDistributionCard(context, allTasks, targetDate, isDark),
          const SizedBox(height: 60), // Extra space for FAB
        ],
      ),
    );
      },
    );
  }

  // Date Navigation Bar
  Widget _buildDateBar(BuildContext context, DateTime targetDate, bool isDark) {
    final now = DateTime.now();
    final isToday = targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;

    String dateTitle;
    try {
      dateTitle = DateFormat('EEEE، d MMMM', 'ar').format(targetDate);
    } catch (_) {
      dateTitle = DateFormat('yyyy/MM/dd').format(targetDate);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ??
            (isDark ? const Color(0xFF132A32) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A42) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'اليوم السابق',
            onPressed: () {
              widget.onDateChanged?.call(targetDate.subtract(const Duration(days: 1)));
            },
          ),
          Expanded(
            child: InkWell(
              onTap: () => _pickDate(targetDate),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      dateTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'اليوم',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!isToday)
            TextButton(
              onPressed: () => widget.onDateChanged?.call(DateTime.now()),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('اليوم', style: TextStyle(fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'اليوم التالي',
            onPressed: () {
              widget.onDateChanged?.call(targetDate.add(const Duration(days: 1)));
            },
          ),
        ],
      ),
    );
  }

  // Category Selector Cards
  Widget _buildCategorySelectorRow(
    BuildContext context,
    List<Task> allTasks,
    DateTime targetDate,
    bool isDark,
  ) {
    // Check if there are tasks under 'عام'
    final hasGeneralTasks = allTasks.any((t) => t.category == 'عام');
    final categoriesToShow = List<CategoryInfo>.from(mainCategories);
    if (hasGeneralTasks || _selectedCategory == 'عام') {
      categoriesToShow.add(generalCategory);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'اختر المجال لعرض ساعاته وإحصائياته 📌',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            final bool needScroll = (availableWidth / categoriesToShow.length) < 78;

            final cards = categoriesToShow.map((cat) {
              final isSelected = _selectedCategory == cat.key;
              final catDayStats = ProductivityService.getCategoryDailyStats(
                allTasks,
                cat.key,
                date: targetDate,
              );

              final item = GestureDetector(
                onTap: () {
                  setState(() => _selectedCategory = cat.key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  width: needScroll ? 84 : null,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? cat.darkBg : cat.lightBg)
                        : (isDark ? const Color(0xFF132A32) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? cat.color : (isDark ? const Color(0xFF1E3A42) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: cat.color.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: isSelected ? 0.25 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat.icon, color: cat.color, size: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? cat.color : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        catDayStats.formattedProductiveHours,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? cat.color : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              return needScroll ? item : Expanded(child: item);
            }).toList();

            if (needScroll) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(children: cards),
              );
            }

            return Row(children: cards);
          },
        ),
      ],
    );
  }

  // Active Category Hero & Stats (Selected Day, Week, Month)
  Widget _buildCategoryStatsHero(
    BuildContext context,
    ProductivityStats dailyStats,
    ProductivityStats weeklyStats,
    ProductivityStats monthlyStats,
    DateTime targetDate,
    bool isDark,
  ) {
    final cat = _activeInfo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cat.color.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cat.color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(cat.icon, color: cat.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.description,
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 3 Big Stat Blocks: (1) تاريخ اليوم المختار, (2) هذا الأسبوع, (3) هذا الشهر
          Builder(
            builder: (context) {
              final now = DateTime.now();
              final isToday = targetDate.year == now.year &&
                  targetDate.month == now.month &&
                  targetDate.day == now.day;
              final yesterday = now.subtract(const Duration(days: 1));
              final isYesterday = targetDate.year == yesterday.year &&
                  targetDate.month == yesterday.month &&
                  targetDate.day == yesterday.day;

              String dayCardTitle;
              if (isToday) {
                dayCardTitle = 'ساعات اليوم';
              } else if (isYesterday) {
                dayCardTitle = 'ساعات أمس';
              } else {
                try {
                  dayCardTitle = DateFormat('d MMMM', 'ar').format(targetDate);
                } catch (_) {
                  dayCardTitle = '${targetDate.day}/${targetDate.month}';
                }
              }

              return Row(
                children: [
                  // 1. تاريخ اليوم المختار
                  Expanded(
                    child: _buildPeriodStatCard(
                      context,
                      title: dayCardTitle,
                      hours: dailyStats.formattedProductiveHours,
                      plannedHours: dailyStats.formattedPlannedHours,
                      rate: dailyStats.percentageFormatted,
                      subtitle: '${dailyStats.completed}/${dailyStats.total} مهام',
                      color: cat.color,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. هذا الأسبوع
                  Expanded(
                    child: _buildPeriodStatCard(
                      context,
                      title: 'ساعات الأسبوع',
                      hours: weeklyStats.formattedProductiveHours,
                      plannedHours: weeklyStats.formattedPlannedHours,
                      rate: weeklyStats.percentageFormatted,
                      subtitle: '${weeklyStats.completed}/${weeklyStats.total} مهام',
                      color: cat.color,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 3. هذا الشهر
                  Expanded(
                    child: _buildPeriodStatCard(
                      context,
                      title: 'ساعات الشهر',
                      hours: monthlyStats.formattedProductiveHours,
                      plannedHours: monthlyStats.formattedPlannedHours,
                      rate: monthlyStats.percentageFormatted,
                      subtitle: '${monthlyStats.completed}/${monthlyStats.total} مهام',
                      color: cat.color,
                      isDark: isDark,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodStatCard(
    BuildContext context, {
    required String title,
    required String hours,
    required String plannedHours,
    required String rate,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            hours,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'من أصل $plannedHours',
            style: const TextStyle(fontSize: 9.5, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$rate إنجاز',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Weekly Trend Bar Chart
  Widget _buildWeeklyTrendSection(
    BuildContext context,
    List<DayStat> weekly7Days,
    DateTime targetDate,
    bool isDark,
  ) {
    final cat = _activeInfo;
    final maxHours = weekly7Days.fold<double>(0.0, (m, d) => d.productiveHours > m ? d.productiveHours : m);
    final chartMax = maxHours > 0 ? (maxHours * 1.25) : 5.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ??
            (isDark ? const Color(0xFF132A32) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A42) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 20, color: cat.color),
                  const SizedBox(width: 8),
                  Text(
                    'توزيع ساعات ${cat.label} خلال الأسبوع 📊',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                'الحد الأقصى: ${maxHours.toStringAsFixed(1)} س',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weekly7Days.map((d) {
                final isSelectedDay = d.date.year == targetDate.year &&
                    d.date.month == targetDate.month &&
                    d.date.day == targetDate.day;

                final heightFactor = (d.productiveHours / chartMax).clamp(0.04, 1.0);

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      widget.onDateChanged?.call(d.date);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          d.productiveHours > 0 ? '${d.productiveHours.toStringAsFixed(1)}س' : '-',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: isSelectedDay ? FontWeight.bold : FontWeight.normal,
                            color: isSelectedDay ? cat.color : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor,
                              child: Container(
                                width: 14,
                                decoration: BoxDecoration(
                                  color: isSelectedDay
                                      ? cat.color
                                      : cat.color.withValues(alpha: d.productiveHours > 0 ? 0.4 : 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: isSelectedDay
                                      ? Border.all(color: Colors.white, width: 1.5)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          d.dayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelectedDay ? FontWeight.bold : FontWeight.normal,
                            color: isSelectedDay ? cat.color : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Today's Tasks in this category
  Widget _buildTodayCategoryTasks(
    BuildContext context,
    List<Task> dayCatTasks,
    DateTime targetDate,
    bool isDark,
  ) {
    final cat = _activeInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rounded, size: 20, color: cat.color),
                const SizedBox(width: 8),
                Text(
                  'مهام ${cat.label} لهذا اليوم (${dayCatTasks.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _openAddTask(_selectedCategory),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة مهمة', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (dayCatTasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ??
                  (isDark ? const Color(0xFF132A32) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF1E3A42) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Icon(cat.icon, size: 40, color: cat.color.withValues(alpha: 0.3)),
                const SizedBox(height: 10),
                Text(
                  'لا توجد مهام مسجلة في مجال "${cat.label}" لهذا اليوم 🌿',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openAddTask(_selectedCategory),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('إضافة مهمة ${cat.label} جديدة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cat.color,
                    side: BorderSide(color: cat.color.withValues(alpha: 0.4)),
                  ),
                ),
              ],
            ),
          )
        else
          ...dayCatTasks.map((task) {
            return TaskItem(
              key: ValueKey(task.id),
              task: task,
              onToggle: (_) {
                widget.taskService.toggleTask(task.id);
              },
              onToggleSubTask: (subId) {
                widget.taskService.toggleSubTask(task.id, subId);
              },
              onEditSubTask: (subId, newTitle) {
                widget.taskService.updateSubTaskTitle(task.id, subId, newTitle);
              },
              onDelete: () {
                widget.taskService.deleteTask(task.id);
              },
              onEdit: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AddTaskSheet(
                    taskToEdit: task,
                    onSave: (updated) {
                      widget.taskService.updateTask(updated);
                    },
                  ),
                );
              },
            );
          }),
      ],
    );
  }

  // Cross-Category Distribution (مقارنة توازن المجالات الثلاثة)
  Widget _buildCategoriesDistributionCard(
    BuildContext context,
    List<Task> allTasks,
    DateTime targetDate,
    bool isDark,
  ) {
    // Daily hours for the categories
    final workStats = ProductivityService.getCategoryDailyStats(allTasks, 'عمل', date: targetDate);
    final studyStats = ProductivityService.getCategoryDailyStats(allTasks, 'دراسة', date: targetDate);
    final healthStats = ProductivityService.getCategoryDailyStats(allTasks, 'صحة', date: targetDate);
    final englishStats = ProductivityService.getCategoryDailyStats(allTasks, 'إنجليزي', date: targetDate);

    final workH = workStats.productiveHours;
    final studyH = studyStats.productiveHours;
    final healthH = healthStats.productiveHours;
    final englishH = englishStats.productiveHours;
    final totalH = workH + studyH + healthH + englishH;

    final workPct = totalH > 0 ? ((workH / totalH) * 100).round() : 0;
    final studyPct = totalH > 0 ? ((studyH / totalH) * 100).round() : 0;
    final healthPct = totalH > 0 ? ((healthH / totalH) * 100).round() : 0;
    final englishPct = totalH > 0 ? ((englishH / totalH) * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ??
            (isDark ? const Color(0xFF132A32) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A42) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 20, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text(
                'توازن ساعات اليوم بين المجالات ⚖️',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Multi-color distribution bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (workH > 0)
                    Expanded(
                      flex: (workH * 100).toInt(),
                      child: Container(color: const Color(0xFF0284C7)),
                    ),
                  if (studyH > 0)
                    Expanded(
                      flex: (studyH * 100).toInt(),
                      child: Container(color: const Color(0xFF8B5CF6)),
                    ),
                  if (healthH > 0)
                    Expanded(
                      flex: (healthH * 100).toInt(),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (englishH > 0)
                    Expanded(
                      flex: (englishH * 100).toInt(),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  if (totalH == 0)
                    Expanded(
                      child: Container(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Legend Row
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceAround,
            children: [
              _buildLegendItem(
                label: 'عمل',
                hours: workStats.formattedProductiveHours,
                pct: '$workPct%',
                color: const Color(0xFF0284C7),
              ),
              _buildLegendItem(
                label: 'دراسة',
                hours: studyStats.formattedProductiveHours,
                pct: '$studyPct%',
                color: const Color(0xFF8B5CF6),
              ),
              _buildLegendItem(
                label: 'صحة',
                hours: healthStats.formattedProductiveHours,
                pct: '$healthPct%',
                color: const Color(0xFF10B981),
              ),
              _buildLegendItem(
                label: 'إنجليزي',
                hours: englishStats.formattedProductiveHours,
                pct: '$englishPct%',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required String hours,
    required String pct,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            Text('$hours ($pct)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}
