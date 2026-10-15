import 'package:flutter_test/flutter_test.dart';
import 'package:my_tasks/models/task.dart';
import 'package:my_tasks/services/productivity_service.dart';
import 'package:my_tasks/services/task_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Subtask Duration & Completion Tests', () {
    test('SubTask models duration correctly and serializes to/from map', () {
      final sub = SubTask(
        id: 's1',
        title: 'الخطوة الأولى',
        isCompleted: false,
        durationMinutes: 45,
      );

      expect(sub.formattedDuration, '45 د');
      final map = sub.toMap();
      expect(map['durationMinutes'], 45);

      final restored = SubTask.fromMap(map);
      expect(restored.durationMinutes, 45);
      expect(restored.title, 'الخطوة الأولى');
    });

    test('toggleTask marks all subtasks completed when completing task', () async {
      final service = TaskService();
      final now = DateTime.now();
      final task = Task(
        id: 'task_sub_1',
        title: 'مهمة رئيسية 4 ساعات',
        date: now,
        durationMinutes: 240,
        subtasks: [
          SubTask(id: 'sub1', title: 'خطوة 1', durationMinutes: 60, isCompleted: false),
          SubTask(id: 'sub2', title: 'خطوة 2', durationMinutes: 60, isCompleted: false),
          SubTask(id: 'sub3', title: 'خطوة 3', durationMinutes: 60, isCompleted: false),
          SubTask(id: 'sub4', title: 'خطوة 4', durationMinutes: 60, isCompleted: false),
        ],
      );

      await service.addTask(task);
      expect(service.tasks.first.subtasks.every((s) => !s.isCompleted), isTrue);

      // Toggle main task to complete
      await service.toggleTask('task_sub_1');
      final updated = service.tasks.firstWhere((t) => t.id == 'task_sub_1');
      expect(updated.isCompleted, isTrue);
      expect(updated.subtasks.every((s) => s.isCompleted), isTrue);

      // Toggle a specific subtask back
      await service.toggleSubTask('task_sub_1', 'sub1');
      final subToggled = service.tasks.firstWhere((t) => t.id == 'task_sub_1');
      expect(subToggled.subtasks.firstWhere((s) => s.id == 'sub1').isCompleted, isFalse);
      expect(subToggled.subtasks.firstWhere((s) => s.id == 'sub2').isCompleted, isTrue);
    });

    test('updateSubTaskTitle edits subtask text properly', () async {
      final service = TaskService();
      final now = DateTime.now();
      final task = Task(
        id: 'task_sub_edit',
        title: 'مهمة لتعديل المهمة الفرعية',
        date: now,
        durationMinutes: 120,
        subtasks: [
          SubTask(id: 'st_1', title: 'عنوان قديم', durationMinutes: 30, isCompleted: false),
          SubTask(id: 'st_2', title: 'خطوة ثانية', durationMinutes: 30, isCompleted: false),
        ],
      );

      await service.addTask(task);
      expect(service.tasks.firstWhere((t) => t.id == 'task_sub_edit').subtasks.first.title, 'عنوان قديم');

      // Edit title
      await service.updateSubTaskTitle('task_sub_edit', 'st_1', 'عنوان معدل جديد');
      final updatedTask = service.tasks.firstWhere((t) => t.id == 'task_sub_edit');
      expect(updatedTask.subtasks.firstWhere((s) => s.id == 'st_1').title, 'عنوان معدل جديد');
      expect(updatedTask.subtasks.firstWhere((s) => s.id == 'st_2').title, 'خطوة ثانية');
    });
  });

  group('Date-specific Productivity Analytics Tests', () {
    test('ProductivityService returns productivity for past days (yesterday, before)', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final dayBefore = today.subtract(const Duration(days: 2));

      final tasks = [
        // Yesterday tasks: 2 tasks, 1 completed (50%)
        Task(
          id: 'y1',
          title: 'مهمة أمس 1',
          date: yesterday,
          durationMinutes: 60,
          isCompleted: true,
          actualDurationMinutes: 60,
        ),
        Task(
          id: 'y2',
          title: 'مهمة أمس 2',
          date: yesterday,
          durationMinutes: 60,
          isCompleted: false,
        ),
        // Today tasks: 1 task completed (100%)
        Task(
          id: 't1',
          title: 'مهمة اليوم',
          date: today,
          durationMinutes: 120,
          isCompleted: true,
          actualDurationMinutes: 120,
        ),
      ];

      final yesterdayStats = ProductivityService.getDailyStats(tasks, date: yesterday);
      expect(yesterdayStats.total, 2);
      expect(yesterdayStats.completed, 1);
      expect(yesterdayStats.rate, 50.0);
      expect(yesterdayStats.productiveHours, 1.0);

      final todayStats = ProductivityService.getDailyStats(tasks, date: today);
      expect(todayStats.total, 1);
      expect(todayStats.completed, 1);
      expect(todayStats.rate, 100.0);
      expect(todayStats.productiveHours, 2.0);

      final dayBeforeStats = ProductivityService.getDailyStats(tasks, date: dayBefore);
      expect(dayBeforeStats.total, 0);
      expect(dayBeforeStats.rate, 0.0);
    });
  });
}
