import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/productivity_service.dart';
import '../widgets/productivity_gauge.dart';
import '../widgets/task_item.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/export_report_dialog.dart';
import '../widgets/complete_task_dialog.dart';
import '../services/auth_service.dart';
import '../widgets/user_profile_dialog.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final TaskService taskService;
  final AuthService authService;
  final VoidCallback onNavigateToAnalytics;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateChanged;

  const HomeScreen({
    super.key,
    required this.taskService,
    required this.authService,
    required this.onNavigateToAnalytics,
    this.selectedDate,
    this.onDateChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum TaskFilter { today, pending, completed }

class _HomeScreenState extends State<HomeScreen> {
  TaskFilter _currentFilter = TaskFilter.today;
  String _searchQuery = '';
  DateTime _localSelectedDate = DateTime.now();

  DateTime get _selectedDate => widget.selectedDate ?? _localSelectedDate;

  void _setSelectedDate(DateTime date) {
    if (widget.onDateChanged != null) {
      widget.onDateChanged!(date);
    } else {
      setState(() => _localSelectedDate = date);
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _showAddSheet([Task? taskToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTaskSheet(
        taskToEdit: taskToEdit,
        initialDate: _selectedDate,
        onSave: (task) {
          if (taskToEdit != null) {
            widget.taskService.updateTask(task);
          } else {
            widget.taskService.addTask(task);
          }
        },
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (_) => ExportReportDialog(tasks: widget.taskService.tasks),
    );
  }

  Future<void> _handleToggleTask(Task task) async {
    if (!task.isCompleted) {
      final actualMinutes = await CompleteTaskDialog.show(context, task: task);
      if (actualMinutes != null) {
        widget.taskService.toggleTask(task.id, actualDurationMinutes: actualMinutes);
      }
    } else {
      widget.taskService.toggleTask(task.id);
    }
  }

  Future<void> _handleEditActualDuration(Task task) async {
    final updatedMinutes = await CompleteTaskDialog.show(
      context,
      task: task,
      isEditingExistingDuration: true,
    );
    if (updatedMinutes != null) {
      widget.taskService.updateActualDuration(task.id, updatedMinutes);
    }
  }

  List<Task> _getFilteredTasks() {
    var list = widget.taskService.tasks.where((t) =>
      t.date.year == _selectedDate.year &&
      t.date.month == _selectedDate.month &&
      t.date.day == _selectedDate.day
    ).toList();

    if (_currentFilter == TaskFilter.pending) {
      list = list.where((t) => !t.isCompleted).toList();
    } else if (_currentFilter == TaskFilter.completed) {
      list = list.where((t) => t.isCompleted).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) =>
        t.title.toLowerCase().contains(q) ||
        t.category.toLowerCase().contains(q) ||
        t.description.toLowerCase().contains(q)
      ).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.taskService,
      builder: (context, _) {
        final tasks = widget.taskService.tasks;
        final selectedDateStats = ProductivityService.getDailyStats(tasks, date: _selectedDate);
        final streakStats = ProductivityService.getStreak(tasks);
        final filteredTasks = _getFilteredTasks();

        final selectedDateTasks = tasks.where((t) =>
          t.date.year == _selectedDate.year &&
          t.date.month == _selectedDate.month &&
          t.date.day == _selectedDate.day
        ).toList();
        final int selectedTotal = selectedDateTasks.length;
        final int selectedPending = selectedDateTasks.where((t) => !t.isCompleted).length;
        final int selectedCompleted = selectedDateTasks.where((t) => t.isCompleted).length;

        // Selected day's tasks with reminders
        final selectedReminders = selectedDateTasks.where((t) =>
          t.reminderDateTime != null && !t.isCompleted
        ).toList();

        String todayFormatted;
        try {
          todayFormatted = DateFormat('EEEE, d MMMM', 'ar').format(DateTime.now());
        } catch (_) {
          todayFormatted = DateFormat('yyyy/MM/dd').format(DateTime.now());
        }

        final user = widget.authService.currentUser;

        return Scaffold(
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => UserProfileDialog(
                      authService: widget.authService,
                      taskService: widget.taskService,
                    ),
                  );
                },
                child: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    user != null && user.name.isNotEmpty
                        ? user.name.characters.first.toUpperCase()
                        : '👤',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user != null && user.name.isNotEmpty
                      ? 'أهلاً، ${user.name} 👋'
                      : 'مهامي اليومية 📋',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  todayFormatted,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white60
                        : Colors.black54,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            actions: [
              // Streak Chip
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${streakStats.currentStreak} يوم',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Export Report button
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'تصدير التقرير',
                onPressed: _showExportDialog,
              ),

              // Analytics button
              IconButton(
                icon: const Icon(Icons.bar_chart_rounded),
                tooltip: 'معدل الإنتاجية',
                onPressed: widget.onNavigateToAnalytics,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddSheet(),
            icon: const Icon(Icons.add),
            label: const Text('مهمة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: widget.taskService.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => widget.taskService.loadTasks(),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate.fixed([
                            // Date Navigation Bar
                            _buildDateNavigationBar(context),

                            // Daily Productivity Card for selected date
                            ProductivityCard(
                              stats: selectedDateStats,
                              onTap: widget.onNavigateToAnalytics,
                            ),

                            // Reminders Banner for selected date
                            if (selectedReminders.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentWarning.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.accentWarning.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.notifications_active, color: AppTheme.accentWarning, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _isToday
                                            ? 'لديك ${selectedReminders.length} مهام محدد لها تذكير اليوم ⏰'
                                            : 'يوجد ${selectedReminders.length} مهام محدد لها تذكير في هذا اليوم ⏰',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Search Bar
                            TextField(
                              decoration: InputDecoration(
                                hintText: _isToday ? 'بحث في مهام اليوم...' : 'بحث في مهام هذا التاريخ...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () => setState(() => _searchQuery = ''),
                                      )
                                    : null,
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                            const SizedBox(height: 14),

                            // Unified Seamless Segmented Filter Bar
                            _buildSegmentedFilterBar(
                              context,
                              selectedTotal,
                              selectedPending,
                              selectedCompleted,
                            ),
                            const SizedBox(height: 16),

                            // Section Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _getFilterSectionTitle(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${filteredTasks.length} مهمة',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ]),
                        ),
                      ),

                      // Tasks list or Empty State
                      if (filteredTasks.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          sliver: SliverToBoxAdapter(
                            child: _buildEmptyState(),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          sliver: SliverList.builder(
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = filteredTasks[index];
                              return TaskItem(
                                key: ValueKey(task.id),
                                task: task,
                                onToggle: (_) => _handleToggleTask(task),
                                onDelete: () => widget.taskService.deleteTask(task.id),
                                onEdit: () => _showAddSheet(task),
                                onToggleSubTask: (subId) => widget.taskService.toggleSubTask(task.id, subId),
                                onEditActualDuration: () => _handleEditActualDuration(task),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSegmentedFilterBar(
    BuildContext context,
    int total,
    int pending,
    int completed,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A32) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1F4450) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          _buildSegmentItem(
            filter: TaskFilter.today,
            title: _isToday ? 'اليوم' : 'الكل',
            icon: Icons.wb_sunny_rounded,
            count: total,
            isDark: isDark,
          ),
          _buildSegmentItem(
            filter: TaskFilter.pending,
            title: 'المتبقية',
            icon: Icons.hourglass_empty_rounded,
            count: pending,
            isDark: isDark,
          ),
          _buildSegmentItem(
            filter: TaskFilter.completed,
            title: 'المكتملة',
            icon: Icons.task_alt_rounded,
            count: completed,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem({
    required TaskFilter filter,
    required String title,
    required IconData icon,
    required int count,
    required bool isDark,
  }) {
    final isSelected = _currentFilter == filter;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentFilter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigationBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String dateString;
    try {
      dateString = DateFormat('EEEE، d MMMM', 'ar').format(_selectedDate);
    } catch (_) {
      dateString = DateFormat('yyyy/MM/dd').format(_selectedDate);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              _setSelectedDate(_selectedDate.subtract(const Duration(days: 1)));
            },
          ),

          // Date Display & Picker
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  helpText: 'اختر يوماً لاستعراض مهامه',
                  confirmText: 'اختيار',
                  cancelText: 'إلغاء',
                );
                if (picked != null) {
                  _setSelectedDate(picked);
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
                      color: _isToday ? AppTheme.primaryColor : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isToday ? 'اليوم - $dateString' : dateString,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isToday
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
          if (!_isToday) ...[
            InkWell(
              onTap: () => _setSelectedDate(DateTime.now()),
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
              _setSelectedDate(_selectedDate.add(const Duration(days: 1)));
            },
          ),
        ],
      ),
    );
  }

  String _getFilterSectionTitle() {
    final dateLabel = _isToday
        ? 'اليوم'
        : DateFormat('d MMMM', 'ar').format(_selectedDate);
    switch (_currentFilter) {
      case TaskFilter.today:
        return 'مهام $dateLabel';
      case TaskFilter.pending:
        return 'المهام المتبقية ($dateLabel)';
      case TaskFilter.completed:
        return 'المهام المكتملة ($dateLabel)';
    }
  }

  Widget _buildEmptyState() {
    final dateLabel = _isToday
        ? 'اليوم'
        : DateFormat('d MMMM', 'ar').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            _currentFilter == TaskFilter.completed
                ? Icons.check_circle_outline
                : Icons.task_outlined,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _currentFilter == TaskFilter.completed
                ? 'لم تكتمل أي مهمة في $dateLabel'
                : 'لا توجد مهام مسجلة في $dateLabel',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentFilter == TaskFilter.today
                ? (_isToday
                    ? 'أضف مهامك اليومية بالضغط على "مهمة جديدة" أدناه 🚀'
                    : 'يمكنك إضافة مهمة لهذا التاريخ بالضغط على "مهمة جديدة" 📝')
                : 'أنجز مهامك لتشهد مؤشر الإنتاجية يرتفع.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white60
                  : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
