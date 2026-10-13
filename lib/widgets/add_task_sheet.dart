import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'complete_task_dialog.dart';

class _TimeSlotDraft {
  TimeOfDay? start;
  TimeOfDay? end;

  _TimeSlotDraft({this.start, this.end});

  bool get isComplete => start != null && end != null;

  int calculateMinutes(BuildContext context) {
    if (!isComplete) return 0;
    int startMins = start!.hour * 60 + start!.minute;
    int endMins = end!.hour * 60 + end!.minute;
    return endMins >= startMins ? (endMins - startMins) : ((24 * 60 - startMins) + endMins);
  }
}

class AddTaskSheet extends StatefulWidget {
  final Task? taskToEdit;
  final Function(Task task) onSave;
  final DateTime? initialDate;
  final String? initialCategory;

  const AddTaskSheet({
    super.key,
    this.taskToEdit,
    required this.onSave,
    this.initialDate,
    this.initialCategory,
  });

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final TextEditingController _subtaskInputController = TextEditingController();

  late DateTime _selectedDate;
  late TaskPriority _priority;
  late String _category;
  TimeOfDay? _reminderTime;
  List<_TimeSlotDraft> _timeSlotDrafts = [];
  late List<SubTask> _subtasks;
  int? _actualDurationMinutes;
  int? _newSubtaskMinutes;

  final List<String> _categories = ['عمل', 'دراسة', 'صحة', 'إنجليزي', 'عام'];

  @override
  void initState() {
    super.initState();
    final edit = widget.taskToEdit;
    _titleController = TextEditingController(text: edit?.title ?? '');
    _descController = TextEditingController(text: edit?.description ?? '');
    _selectedDate = edit?.date ?? widget.initialDate ?? DateTime.now();
    _priority = edit?.priority ?? TaskPriority.medium;
    _category = edit?.category ?? widget.initialCategory ?? 'عمل';
    _subtasks = edit?.subtasks != null ? List.from(edit!.subtasks) : [];

    if (edit?.reminderDateTime != null) {
      _reminderTime = TimeOfDay.fromDateTime(edit!.reminderDateTime!);
    }

    _timeSlotDrafts = [];
    if (edit?.allTimeSlots.isNotEmpty == true) {
      _timeSlotDrafts = edit!.allTimeSlots.map((s) {
        return _TimeSlotDraft(
          start: _parseTimeString(s.start),
          end: _parseTimeString(s.end),
        );
      }).toList();
    } else {
      TimeOfDay? sTime;
      TimeOfDay? eTime;
      if (edit?.startTime != null) sTime = _parseTimeString(edit!.startTime!);
      if (edit?.endTime != null) eTime = _parseTimeString(edit!.endTime!);
      if (sTime != null || eTime != null) {
        _timeSlotDrafts.add(_TimeSlotDraft(start: sTime, end: eTime));
      }
    }

    _actualDurationMinutes = edit?.actualDurationMinutes;
  }

  TimeOfDay? _parseTimeString(String str) {
    try {
      final parts = str.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0].trim());
        final minPart = parts[1].split(' ')[0].trim();
        final minute = int.parse(minPart);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _subtaskInputController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  Future<void> _pickSlotStartTime(int index) async {
    final draft = _timeSlotDrafts[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: draft.start ?? const TimeOfDay(hour: 14, minute: 0),
    );
    if (picked != null) {
      setState(() {
        draft.start = picked;
      });
    }
  }

  Future<void> _pickSlotEndTime(int index) async {
    final draft = _timeSlotDrafts[index];
    final initial = draft.end ??
        (draft.start != null
            ? TimeOfDay(hour: (draft.start!.hour + 1) % 24, minute: draft.start!.minute)
            : const TimeOfDay(hour: 16, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        draft.end = picked;
      });
    }
  }

  void _addTimeSlot() {
    setState(() {
      _timeSlotDrafts.add(_TimeSlotDraft());
    });
  }

  void _removeTimeSlot(int index) {
    setState(() {
      _timeSlotDrafts.removeAt(index);
    });
  }

  void _clearAllTimeSlots() {
    setState(() {
      _timeSlotDrafts.clear();
    });
  }

  int _getTotalSlotsMinutes() {
    int total = 0;
    for (final draft in _timeSlotDrafts) {
      total += draft.calculateMinutes(context);
    }
    return total;
  }

  void _addSubtask() {
    final text = _subtaskInputController.text.trim();
    if (text.isNotEmpty) {
      if (text.length > 150) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('عنوان المهمة الفرعية طويل جداً (الحد الأقصى 150 حرفاً)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      setState(() {
        _subtasks.add(
          SubTask(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: text,
            isCompleted: false,
            durationMinutes: _newSubtaskMinutes,
          ),
        );
        _subtaskInputController.clear();
        _newSubtaskMinutes = null;
      });
    }
  }

  int get _effectiveMainTaskMinutes {
    final totalSlots = _getTotalSlotsMinutes();
    if (totalSlots > 0) return totalSlots;
    return widget.taskToEdit?.durationMinutes ?? 60;
  }

  void _distributeTimeToSubtasks() {
    if (_subtasks.isEmpty) return;
    final totalMins = _effectiveMainTaskMinutes;
    final perSubtask = (totalMins / _subtasks.length).round();
    setState(() {
      _subtasks = _subtasks.map((s) => s.copyWith(durationMinutes: perSubtask)).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم توزيع ${Task.formatMinutes(totalMins)} بالتساوي: ${Task.formatMinutes(perSubtask)} لكل مهمة فرعية ⚖️'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickSubTaskDuration(int index) async {
    final current = _subtasks[index].durationMinutes;
    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int tempMins = current ?? 30;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: Theme.of(ctx).cardTheme.color ?? (isDark ? const Color(0xFF132A32) : Colors.white),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'تحديد وقت المهمة الفرعية:\n"${_subtasks[index].title}"',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    Task.formatMinutes(tempMins),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [15, 30, 45, 60, 90, 120].map((m) {
                      final isSel = tempMins == m;
                      return ChoiceChip(
                        label: Text(Task.formatMinutes(m)),
                        selected: isSel,
                        onSelected: (_) => setSheetState(() => tempMins = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (current != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, -1),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            child: const Text('إلغاء الوقت'),
                          ),
                        ),
                      if (current != null) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, tempMins),
                          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                          child: const Text('تأكيد الوقت'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _subtasks[index] = _subtasks[index].copyWith(
          durationMinutes: result == -1 ? null : result,
          clearDuration: result == -1,
        );
      });
    }
  }

  String _getComputedDurationText() {
    int total = _getTotalSlotsMinutes();
    if (total <= 0) return '';
    return Task.formatMinutes(total);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      DateTime? reminder;
      if (_reminderTime != null) {
        reminder = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _reminderTime!.hour,
          _reminderTime!.minute,
        );
      }

      final List<TimeSlot> finalSlots = [];
      for (final draft in _timeSlotDrafts) {
        if (draft.isComplete) {
          finalSlots.add(TimeSlot(
            start: draft.start!.format(context),
            end: draft.end!.format(context),
          ));
        }
      }

      int? calculatedMins;
      String? primaryStart;
      String? primaryEnd;

      if (finalSlots.isNotEmpty) {
        primaryStart = finalSlots.first.start;
        primaryEnd = finalSlots.last.end;
        calculatedMins = finalSlots.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      } else {
        final subtasksTotal = _subtasks.fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));
        if (subtasksTotal > 0) {
          calculatedMins = subtasksTotal;
        } else {
          calculatedMins = widget.taskToEdit?.durationMinutes;
        }
      }

      final task = Task(
        id: widget.taskToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        date: _selectedDate,
        priority: _priority,
        category: _category,
        subtasks: _subtasks,
        reminderDateTime: reminder,
        timeSlots: finalSlots,
        startTime: primaryStart,
        endTime: primaryEnd,
        durationMinutes: calculatedMins,
        actualDurationMinutes: _actualDurationMinutes,
        isCompleted: widget.taskToEdit?.isCompleted ?? false,
        completedAt: widget.taskToEdit?.completedAt,
      );
      widget.onSave(task);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEditing ? 'تعديل المهمة ✏️' : 'إضافة مهمة جديدة ➕',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Title
                TextFormField(
                  controller: _titleController,
                  autofocus: !isEditing,
                  decoration: const InputDecoration(
                    labelText: 'عنوان المهمة *',
                    hintText: 'مثال: إنجاز تقرير المشروع',
                    prefixIcon: Icon(Icons.task_alt_outlined),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                       return 'يرجى كتابة عنوان للمهمة';
                    }
                    if (trimmed.length > 200) {
                      return 'عنوان المهمة طويل جداً (الحد الأقصى 200 حرف)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات وتفاصيل (اختياري)',
                    hintText: 'أي تفاصيل مساعدة لإكمال المهمة...',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.length > 2000) {
                      return 'تفاصيل المهمة طويلة جداً (الحد الأقصى 2000 حرف)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date & Reminder Pickers
                Row(
                  children: [
                    // Date Picker
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('التاريخ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    Text(
                                      DateFormat('MM/dd').format(_selectedDate),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Reminder Picker
                    Expanded(
                      child: InkWell(
                        onTap: _pickReminderTime,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: _reminderTime != null
                                ? Border.all(color: AppTheme.accentWarning, width: 1.2)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _reminderTime != null ? Icons.alarm_on : Icons.alarm,
                                size: 18,
                                color: _reminderTime != null ? AppTheme.accentWarning : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('تذكير ⏰', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    Text(
                                      _reminderTime != null
                                          ? _reminderTime!.format(context)
                                          : 'بدون تذكير',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _reminderTime != null ? AppTheme.accentWarning : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_reminderTime != null)
                                GestureDetector(
                                  onTap: () => setState(() => _reminderTime = null),
                                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Execution Time Windows (أوقات تنفيذ المهمة - فترة أو عدة فترات)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _timeSlotDrafts.isNotEmpty
                          ? AppTheme.primaryColor.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 18, color: AppTheme.primaryColor),
                              SizedBox(width: 6),
                              Text(
                                'أوقات تنفيذ المهمة 🕒',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (_timeSlotDrafts.isNotEmpty)
                            GestureDetector(
                              onTap: _clearAllTimeSlots,
                              child: const Text(
                                'إلغاء الكل',
                                style: TextStyle(fontSize: 11, color: Colors.redAccent),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_timeSlotDrafts.isEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: _addTimeSlot,
                          icon: const Icon(Icons.add_alarm_rounded, size: 16),
                          label: const Text(
                            '+ تحديد وقت لتنفيذ المهمة (من - إلى)',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 42),
                          ),
                        ),
                      ] else ...[
                        for (int i = 0; i < _timeSlotDrafts.length; i++) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _timeSlotDrafts[i].isComplete
                                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'الفترة ${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_timeSlotDrafts[i].isComplete)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          Task.formatMinutes(_timeSlotDrafts[i].calculateMinutes(context)),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _removeTimeSlot(i),
                                      borderRadius: BorderRadius.circular(12),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _pickSlotStartTime(i),
                                        icon: const Icon(Icons.play_arrow_rounded, size: 15),
                                        label: Text(
                                          _timeSlotDrafts[i].start != null
                                              ? 'من: ${_timeSlotDrafts[i].start!.format(context)}'
                                              : 'من: وقت البدء',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: _timeSlotDrafts[i].start != null
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          side: BorderSide(
                                            color: _timeSlotDrafts[i].start != null
                                                ? AppTheme.primaryColor
                                                : Colors.grey.withValues(alpha: 0.3),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _pickSlotEndTime(i),
                                        icon: const Icon(Icons.stop_rounded, size: 15),
                                        label: Text(
                                          _timeSlotDrafts[i].end != null
                                              ? 'إلى: ${_timeSlotDrafts[i].end!.format(context)}'
                                              : 'إلى: وقت الانتهاء',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: _timeSlotDrafts[i].end != null
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          side: BorderSide(
                                            color: _timeSlotDrafts[i].end != null
                                                ? AppTheme.primaryColor
                                                : Colors.grey.withValues(alpha: 0.3),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        OutlinedButton.icon(
                          onPressed: _addTimeSlot,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                          label: const Text(
                            '+ إضافة فترة تنفيذ أخرى',
                            style: TextStyle(fontSize: 11.5),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: const Size(double.infinity, 36),
                          ),
                        ),
                        if (_getTotalSlotsMinutes() > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: AppTheme.primaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  'إجمالي المدة المخططة: ${_getComputedDurationText()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      if (widget.taskToEdit?.isCompleted == true) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentSuccess.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.accentSuccess.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.accentSuccess),
                                  const SizedBox(width: 6),
                                  Text(
                                    _actualDurationMinutes != null
                                        ? 'الوقت الفعلي: ${Task.formatMinutes(_actualDurationMinutes!)}'
                                        : 'الوقت الفعلي: لم يسجل بعد',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('تعديل', style: TextStyle(fontSize: 12)),
                                onPressed: () async {
                                  final res = await CompleteTaskDialog.show(
                                    context,
                                    task: widget.taskToEdit!.copyWith(
                                      actualDurationMinutes: _actualDurationMinutes,
                                    ),
                                    isEditingExistingDuration: true,
                                  );
                                  if (res != null) {
                                    setState(() => _actualDurationMinutes = res);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Subtasks (Checklist) Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المهام الفرعية (Checklist) 📋',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (_subtasks.isNotEmpty)
                      Text(
                        '${_subtasks.length} خطوات',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Time Distribution summary card if subtasks exist
                if (_subtasks.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final int allocatedMins = _subtasks.fold(0, (sum, s) => sum + (s.durationMinutes ?? 0));
                      final int mainMins = _effectiveMainTaskMinutes;
                      final int remainingMins = mainMins - allocatedMins;
                      final int equalShare = (mainMins / _subtasks.length).round();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'المخطط: ${Task.formatMinutes(mainMins)} | الموزع: ${Task.formatMinutes(allocatedMins)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                if (remainingMins > 0)
                                  Text(
                                    'متبقي ${Task.formatMinutes(remainingMins)}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.accentSuccess, fontWeight: FontWeight.bold),
                                  )
                                else if (remainingMins < 0)
                                  Text(
                                    'تجاوز بـ ${Task.formatMinutes(remainingMins.abs())}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.accentWarning, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _distributeTimeToSubtasks,
                                icon: const Icon(Icons.balance_rounded, size: 14),
                                label: Text(
                                  'توزيع وقت المهمة بالتساوي (${Task.formatMinutes(equalShare)} لكل خطوة) ⚖️',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],

                // Subtask input row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subtaskInputController,
                        onSubmitted: (_) => _addSubtask(),
                        decoration: InputDecoration(
                          hintText: _newSubtaskMinutes != null
                              ? 'أضف خطوة (${Task.formatMinutes(_newSubtaskMinutes!)})...'
                              : 'أضف خطوة فرعية...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _addSubtask,
                      icon: const Icon(Icons.add),
                      tooltip: 'إضافة خطوة',
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Quick duration selector for the step being added
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('وقت الخطوة: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ...[null, 15, 30, 45, 60, 90, 120].map((m) {
                        final isSelected = _newSubtaskMinutes == m;
                        final label = m == null ? 'تلقائي' : Task.formatMinutes(m);
                        return Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: ChoiceChip(
                            label: Text(label, style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onSelected: (val) {
                              setState(() {
                                _newSubtaskMinutes = val ? m : null;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Subtasks list preview
                if (_subtasks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: _subtasks.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final sub = entry.value;
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: InkWell(
                            onTap: () {
                              setState(() {
                                _subtasks[idx] = sub.copyWith(isCompleted: !sub.isCompleted);
                              });
                            },
                            child: Icon(
                              sub.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                              size: 20,
                              color: sub.isCompleted ? AppTheme.accentSuccess : Colors.grey,
                            ),
                          ),
                          title: Text(
                            sub.title,
                            style: TextStyle(
                              fontSize: 13,
                              decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Duration Pill
                              InkWell(
                                onTap: () => _pickSubTaskDuration(idx),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (sub.durationMinutes != null && sub.durationMinutes! > 0)
                                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: (sub.durationMinutes != null && sub.durationMinutes! > 0)
                                          ? AppTheme.primaryColor.withValues(alpha: 0.4)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 12,
                                        color: (sub.durationMinutes != null && sub.durationMinutes! > 0)
                                            ? AppTheme.primaryColor
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        (sub.durationMinutes != null && sub.durationMinutes! > 0)
                                            ? sub.formattedDuration
                                            : '+ وقت',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: (sub.durationMinutes != null && sub.durationMinutes! > 0)
                                              ? AppTheme.primaryColor
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _subtasks.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Priority Selector
                const Text(
                  'مستوى الأولوية',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPriorityChip(TaskPriority.high, 'عالية 🔥', AppTheme.accentDanger),
                    const SizedBox(width: 8),
                    _buildPriorityChip(TaskPriority.medium, 'متوسطة ⚡', AppTheme.accentWarning),
                    const SizedBox(width: 8),
                    _buildPriorityChip(TaskPriority.low, 'منخفضة ☕', AppTheme.accentInfo),
                  ],
                ),
                const SizedBox(height: 16),

                // Category Selector
                const Text(
                  'التصنيف',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _category == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _category = cat);
                          },
                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.18),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'حفظ التعديلات' : 'إضافة المهمة إلى اليومية 🚀',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(TaskPriority p, String label, Color color) {
    final isSelected = _priority == p;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = p),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
