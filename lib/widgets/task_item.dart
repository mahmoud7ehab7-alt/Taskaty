import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class TaskItem extends StatefulWidget {
  final Task task;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final Function(String subTaskId)? onToggleSubTask;
  final Function(String subTaskId, String newTitle)? onEditSubTask;
  final VoidCallback? onEditActualDuration;

  const TaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.onEdit,
    this.onToggleSubTask,
    this.onEditSubTask,
    this.onEditActualDuration,
  });

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = !widget.task.isCompleted && widget.task.subtasks.isNotEmpty;
  }

  Future<void> _showEditSubTaskDialog(BuildContext context, SubTask sub) async {
    final controller = TextEditingController(text: sub.title);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Theme.of(ctx).cardTheme.color ?? (isDark ? const Color(0xFF132A32) : Colors.white),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('تعديل المهمة الفرعية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 150,
            textInputAction: TextInputAction.done,
            onSubmitted: (val) {
              final trimmed = val.trim();
              if (trimmed.isNotEmpty) {
                Navigator.pop(ctx, trimmed);
              }
            },
            decoration: InputDecoration(
              hintText: 'عنوان المهمة الفرعية...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.pop(ctx, trimmed);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != sub.title) {
      widget.onEditSubTask?.call(sub.id, result);
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AppTheme.accentDanger;
      case TaskPriority.medium:
        return AppTheme.accentWarning;
      case TaskPriority.low:
        return AppTheme.accentInfo;
    }
  }

  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'عالية';
      case TaskPriority.medium:
        return 'متوسطة';
      case TaskPriority.low:
        return 'منخفضة';
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.delete_forever_rounded, color: AppTheme.accentDanger, size: 24),
              SizedBox(width: 8),
              Text(
                'تأكيد حذف المهمة ⚠️',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف المهمة "${widget.task.title}"؟ لا يمكن التراجع عن هذا الإجراء.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('حذف المهمة', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentDanger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final priorityColor = _getPriorityColor(widget.task.priority);
    final hasSubtasks = widget.task.subtasks.isNotEmpty;
    final completedSubtasksCount = widget.task.subtasks.where((s) => s.isCompleted).length;
    final timeSlots = widget.task.allTimeSlots;

    return Dismissible(
      key: Key(widget.task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppTheme.accentDanger.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context);
      },
      onDismissed: (_) => widget.onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: widget.task.isCompleted
                ? (isDark ? Colors.white10 : Colors.black12)
                : priorityColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: widget.onEdit,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Main Checkbox
                    GestureDetector(
                      onTap: () => widget.onToggle(!widget.task.isCompleted),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.task.isCompleted
                              ? AppTheme.accentSuccess
                              : Colors.transparent,
                          border: Border.all(
                            color: widget.task.isCompleted
                                ? AppTheme.accentSuccess
                                : (isDark ? Colors.white38 : Colors.grey.shade400),
                            width: 2,
                          ),
                        ),
                        child: widget.task.isCompleted
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: widget.task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: widget.task.isCompleted
                                  ? (isDark ? Colors.white38 : Colors.black38)
                                  : (isDark ? Colors.white : const Color(0xFF1E293B)),
                            ),
                          ),
                          if (widget.task.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.task.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                                decoration: widget.task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.redAccent.withValues(alpha: 0.8),
                      tooltip: 'حذف المهمة',
                      onPressed: () async {
                        final confirmed = await _showDeleteConfirmation(context);
                        if (confirmed) {
                          widget.onDelete();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Tags row (Priority, Category, Reminder, Subtasks indicator)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Priority Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: priorityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _getPriorityLabel(widget.task.priority),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Category Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.task.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),

                    // Reminder Badge
                    if (widget.task.reminderDateTime != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentWarning.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alarm, size: 12, color: AppTheme.accentWarning),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('hh:mm a').format(widget.task.reminderDateTime!),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentWarning,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Execution Time Window Badges (Supports Multiple Time Windows)
                    if (timeSlots.isNotEmpty)
                      ...timeSlots.map((slot) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule, size: 12, color: AppTheme.primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                slot.formattedWindow,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                    else if (widget.task.startTime != null || widget.task.endTime != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: AppTheme.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              widget.task.startTime != null && widget.task.endTime != null
                                  ? '${widget.task.startTime} - ${widget.task.endTime}'
                                  : (widget.task.startTime != null
                                      ? 'من ${widget.task.startTime}'
                                      : 'حتى ${widget.task.endTime}'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Planned Duration Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            widget.task.isCompleted
                                ? 'مخطط: ${widget.task.formattedDuration}'
                                : widget.task.formattedDuration,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actual Duration Comparison Badge (when completed and recorded)
                    if (widget.task.isCompleted && widget.task.actualDurationMinutes != null) ...[
                      Builder(
                        builder: (context) {
                          final diff = widget.task.durationDifferenceMinutes ?? 0;
                          Color badgeColor;
                          IconData badgeIcon;
                          String badgeText;

                          if (diff < 0) {
                            badgeColor = AppTheme.accentSuccess;
                            badgeIcon = Icons.bolt_rounded;
                            badgeText = 'فعلي: ${widget.task.formattedActualDuration} (وفرت ${Task.formatMinutes(diff.abs())})';
                          } else if (diff > 0) {
                            badgeColor = AppTheme.accentWarning;
                            badgeIcon = Icons.hourglass_top_rounded;
                            badgeText = 'فعلي: ${widget.task.formattedActualDuration} (+${Task.formatMinutes(diff)})';
                          } else {
                            badgeColor = AppTheme.accentInfo;
                            badgeIcon = Icons.check_circle_outline_rounded;
                            badgeText = 'فعلي: ${widget.task.formattedActualDuration} (في الموعد)';
                          }

                          return InkWell(
                            onTap: widget.onEditActualDuration,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: badgeColor.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(badgeIcon, size: 12, color: badgeColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                    ),
                                  ),
                                  if (widget.onEditActualDuration != null) ...[
                                    const SizedBox(width: 3),
                                    Icon(Icons.edit, size: 10, color: badgeColor.withValues(alpha: 0.7)),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    // Subtasks toggle chip
                    if (hasSubtasks)
                      InkWell(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.checklist, size: 14, color: AppTheme.primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.task.completionPercentage}% • $completedSubtasksCount/${widget.task.subtasks.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Icon(
                                _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Expanded Subtasks Checklist
                if (hasSubtasks && _isExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subtasks header with progress (calculated by hours)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.checklist_rounded, size: 16, color: AppTheme.primaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  'المهام الفرعية ($completedSubtasksCount من ${widget.task.subtasks.length})',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${Task.formatMinutes(widget.task.completedSubtasksPlannedMinutes)} / ${Task.formatMinutes(widget.task.totalSubtasksPlannedMinutes)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${widget.task.completionPercentage}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: widget.task.completionProgress,
                            minHeight: 5,
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentSuccess),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Subtask items list
                        ...widget.task.subtasks.map((sub) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: InkWell(
                              onTap: widget.onToggleSubTask != null
                                  ? () => widget.onToggleSubTask!(sub.id)
                                  : null,
                              onLongPress: widget.onEditSubTask != null
                                  ? () => _showEditSubTaskDialog(context, sub)
                                  : null,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: sub.isCompleted
                                      ? (isDark
                                          ? AppTheme.accentSuccess.withValues(alpha: 0.08)
                                          : AppTheme.accentSuccess.withValues(alpha: 0.05))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    // Custom animated circle checkbox like main task
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeInOut,
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: sub.isCompleted
                                            ? AppTheme.accentSuccess
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: sub.isCompleted
                                              ? AppTheme.accentSuccess
                                              : (isDark ? Colors.white38 : Colors.grey.shade400),
                                          width: 1.8,
                                        ),
                                      ),
                                      child: sub.isCompleted
                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),

                                    // Subtask title
                                    Expanded(
                                      child: Text(
                                        sub.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: sub.isCompleted ? FontWeight.normal : FontWeight.w500,
                                          decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                                          color: sub.isCompleted
                                              ? (isDark ? Colors.white38 : Colors.black38)
                                              : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                    ),

                                    // Subtask allocated time badge (explicit or proportional)
                                    Builder(
                                      builder: (context) {
                                        final int subAllocatedMins = widget.task.subtaskAllocatedMinutes(sub);

                                        if (subAllocatedMins <= 0) return const SizedBox.shrink();

                                        final badgeColor = sub.isCompleted ? AppTheme.accentSuccess : AppTheme.primaryColor;
                                        final totalMins = widget.task.totalSubtasksPlannedMinutes;
                                        final sharePct = totalMins > 0 ? ((subAllocatedMins / totalMins) * 100).round() : 0;

                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(7),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    sub.isCompleted ? Icons.check_circle_outline_rounded : Icons.timer_outlined,
                                                    size: 11,
                                                    color: badgeColor,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${Task.formatMinutes(subAllocatedMins)} ($sharePct%)',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: badgeColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),

                                    // Edit subtask text button
                                    if (widget.onEditSubTask != null) ...[
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => _showEditSubTaskDialog(context, sub),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.all(3.0),
                                          child: Tooltip(
                                            message: 'تعديل المهمة الفرعية',
                                            child: Icon(
                                              Icons.edit_outlined,
                                              size: 14,
                                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
