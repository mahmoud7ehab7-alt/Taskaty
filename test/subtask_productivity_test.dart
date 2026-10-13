import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_tasks/models/task.dart';
import 'package:my_tasks/services/task_service.dart';
import 'package:my_tasks/services/productivity_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Subtasks contribute immediately to productivity rate and productive hours', () {
    final now = DateTime.now();

    // 2-hour task (120 minutes) with 4 subtasks (each represents 30 minutes / 0.5 hour)
    final task = Task(
      id: 'task_1',
      title: 'مهمة كبيرة',
      date: now,
      durationMinutes: 120,
      subtasks: [
        SubTask(id: 's1', title: 'جزء 1', isCompleted: true),
        SubTask(id: 's2', title: 'جزء 2', isCompleted: false),
        SubTask(id: 's3', title: 'جزء 3', isCompleted: false),
        SubTask(id: 's4', title: 'جزء 4', isCompleted: false),
      ],
    );

    expect(task.isCompleted, isFalse);
    expect(task.completionProgress, 0.25);
    expect(task.effectivePlannedMinutesAchieved, 30.0);
    expect(task.effectiveProductiveMinutesAchieved, 30.0);

    final stats = ProductivityService.getDailyStats([task], date: now);
    expect(stats.rate, 25.0); // 25% of the 2 hours
    expect(stats.productiveHours, 0.5); // 0.5 hour = 30 minutes
    expect(stats.formattedProductiveHours, '30 د');
  });

  test('Subtask with explicit duration calculates exact minutes and hours', () {
    final now = DateTime.now();

    // 2-hour task with explicit 30-min and 90-min subtasks
    final task = Task(
      id: 'task_2',
      title: 'مهمة ساعتين',
      date: now,
      durationMinutes: 120,
      subtasks: [
        SubTask(id: 's1', title: 'مهمة فرعية نص ساعة', durationMinutes: 30, isCompleted: true),
        SubTask(id: 's2', title: 'مهمة فرعية ساعة ونصف', durationMinutes: 90, isCompleted: false),
      ],
    );

    expect(task.completionProgress, 0.25);
    expect(task.effectiveProductiveMinutesAchieved, 30.0);

    final stats = ProductivityService.getDailyStats([task], date: now);
    expect(stats.rate, 25.0);
    expect(stats.productiveHours, 0.5);
  });

  test('Finishing all subtasks auto-completes parent task, unchecking uncompletes it', () async {
    final taskService = TaskService();
    final now = DateTime.now();

    final task = Task(
      id: 'task_auto',
      title: 'مهمة للتجربة',
      date: now,
      durationMinutes: 60,
      subtasks: [
        SubTask(id: 'sub_a', title: 'أ', isCompleted: false),
        SubTask(id: 'sub_b', title: 'ب', isCompleted: false),
      ],
    );

    await taskService.addTask(task);

    // Toggle first subtask
    await taskService.toggleSubTask('task_auto', 'sub_a');
    var updated = taskService.tasks.firstWhere((t) => t.id == 'task_auto');
    expect(updated.isCompleted, isFalse);
    expect(updated.subtasks.firstWhere((s) => s.id == 'sub_a').isCompleted, isTrue);

    // Toggle second subtask -> all finished -> auto completes parent!
    await taskService.toggleSubTask('task_auto', 'sub_b');
    updated = taskService.tasks.firstWhere((t) => t.id == 'task_auto');
    expect(updated.isCompleted, isTrue);
    expect(updated.completedAt, isNotNull);

    // Uncheck first subtask -> parent should auto-uncomplete
    await taskService.toggleSubTask('task_auto', 'sub_a');
    updated = taskService.tasks.firstWhere((t) => t.id == 'task_auto');
    expect(updated.isCompleted, isFalse);
    expect(updated.completedAt, isNull);
  });
}
