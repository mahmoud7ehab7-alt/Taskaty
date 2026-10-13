import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class CompleteTaskDialog extends StatefulWidget {
  final Task task;
  final bool isEditingExistingDuration;

  const CompleteTaskDialog({
    super.key,
    required this.task,
    this.isEditingExistingDuration = false,
  });

  static Future<int?> show(
    BuildContext context, {
    required Task task,
    bool isEditingExistingDuration = false,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompleteTaskDialog(
        task: task,
        isEditingExistingDuration: isEditingExistingDuration,
      ),
    );
  }

  @override
  State<CompleteTaskDialog> createState() => _CompleteTaskDialogState();
}

class _CompleteTaskDialogState extends State<CompleteTaskDialog> {
  late int _selectedMinutes;
  late int _plannedMinutes;

  @override
  void initState() {
    super.initState();
    _plannedMinutes = widget.task.effectiveMinutes;
    // Default to existing actualDurationMinutes if set, or plannedMinutes
    _selectedMinutes = widget.task.actualDurationMinutes ?? _plannedMinutes;
  }

  void _adjustMinutes(int delta) {
    setState(() {
      _selectedMinutes = (_selectedMinutes + delta).clamp(5, 24 * 60);
    });
  }

  void _setMinutes(int mins) {
    setState(() {
      _selectedMinutes = mins.clamp(5, 24 * 60);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diff = _selectedMinutes - _plannedMinutes;

    final int hours = _selectedMinutes ~/ 60;
    final int mins = _selectedMinutes % 60;

    Color diffColor;
    IconData diffIcon;
    String diffTitle;
    if (diff < 0) {
      diffColor = AppTheme.accentSuccess;
      diffIcon = Icons.bolt_rounded;
      diffTitle = 'إنجاز سريع! وفرت ${Task.formatMinutes(diff.abs())} 🚀';
    } else if (diff > 0) {
      diffColor = AppTheme.accentWarning;
      diffIcon = Icons.hourglass_top_rounded;
      diffTitle = 'استغرقت ${Task.formatMinutes(diff)} وقت إضافي ⏱️';
    } else {
      diffColor = AppTheme.primaryColor;
      diffIcon = Icons.check_circle_outline_rounded;
      diffTitle = 'في نفس الوقت المخطط له تماماً 🎯';
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ??
              (isDark ? const Color(0xFF132A32) : Colors.white),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentSuccess.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.isEditingExistingDuration
                          ? Icons.edit_calendar_rounded
                          : Icons.task_alt_rounded,
                      color: AppTheme.accentSuccess,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEditingExistingDuration
                              ? 'تعديل وقت الإنجاز الفعلي ⏱️'
                              : 'تسجيل وقت إنجاز المهمة ✅',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Planned vs Live Difference Hero Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: diffColor.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 15, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'الوقت المخطط:',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          widget.task.formattedDuration,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        Icon(diffIcon, size: 18, color: diffColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            diffTitle,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: diffColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.task.subtasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSuccess.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accentSuccess.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_add_check_circle_rounded, color: AppTheme.accentSuccess, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم تحديد جميع المهام الفرعية (${widget.task.subtasks.length} خطوات) كمكتملة تلقائياً ✅',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.accentSuccess),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Large Interactive Time Display & Incrementors
              Text(
                'الوقت الفعلي المستغرق:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1E24) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E3A45) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Hours Column
                    _buildStepper(
                      context,
                      label: 'ساعات',
                      value: hours,
                      onIncrement: () => _adjustMinutes(60),
                      onDecrement: () => _adjustMinutes(-60),
                      isDark: isDark,
                    ),

                    Container(
                      height: 50,
                      width: 1,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),

                    // Minutes Column
                    _buildStepper(
                      context,
                      label: 'دقائق',
                      value: mins,
                      onIncrement: () => _adjustMinutes(15),
                      onDecrement: () => _adjustMinutes(-15),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Quick Adjustment Chips
              Text(
                'تعديل سريع:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickChip(
                    label: 'نفس المخطط (${widget.task.formattedDuration})',
                    isSelected: _selectedMinutes == _plannedMinutes,
                    onTap: () => _setMinutes(_plannedMinutes),
                    isDark: isDark,
                  ),
                  _buildQuickChip(
                    label: '-15 د',
                    onTap: () => _adjustMinutes(-15),
                    isDark: isDark,
                  ),
                  _buildQuickChip(
                    label: '-30 د',
                    onTap: () => _adjustMinutes(-30),
                    isDark: isDark,
                  ),
                  _buildQuickChip(
                    label: '+15 د',
                    onTap: () => _adjustMinutes(15),
                    isDark: isDark,
                  ),
                  _buildQuickChip(
                    label: '+30 د',
                    onTap: () => _adjustMinutes(30),
                    isDark: isDark,
                  ),
                  _buildQuickChip(
                    label: '+1 ساعة',
                    onTap: () => _adjustMinutes(60),
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Confirm Button
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  widget.isEditingExistingDuration
                      ? 'حفظ التعديل (${Task.formatMinutes(_selectedMinutes)})'
                      : 'تأكيد الإنجاز (${Task.formatMinutes(_selectedMinutes)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentSuccess,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  Navigator.pop(context, _selectedMinutes);
                },
              ),
              const SizedBox(height: 10),

              // Secondary Quick Action
              if (!widget.isEditingExistingDuration)
                TextButton(
                  onPressed: () {
                    // Quick confirm with planned duration
                    Navigator.pop(context, _plannedMinutes);
                  },
                  child: Text(
                    'إتمام المهمة بالوقت المخطط دون تعديل (${widget.task.formattedDuration})',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(
    BuildContext context, {
    required String label,
    required int value,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildCircularButton(
              icon: Icons.remove,
              onPressed: onDecrement,
              isDark: isDark,
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 50),
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildCircularButton(
              icon: Icons.add,
              onPressed: onIncrement,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E3A45) : const Color(0xFFE2E8F0),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? const Color(0xFF1E3A45) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
