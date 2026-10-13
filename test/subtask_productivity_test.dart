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

  test('Subtask completion percentage is calculated strictly by hours/duration, not task count', () {
    final now = DateTime.now();

    // 2-hour task (120 min):
    // Subtask 1: 90 min (1.5h) - completed
    // Subtask 2: 30 min (0.5h) - not completed
    final taskWithLargeCompleted = Task(
      id: 'sub_hrs_1',
      title: 'مهمة ساعتين',
      date: now,
      durationMinutes: 120,
      subtasks: [
        SubTask(id: 's1', title: 'خطوة كبيرة 90 د', durationMinutes: 90, isCompleted: true),
        SubTask(id: 's2', title: 'خطوة صغيرة 30 د', durationMinutes: 30, isCompleted: false),
      ],
    );

    // By count it would be 50%, but by hours it must be 75% (90/120)
    expect(taskWithLargeCompleted.completionProgress, 0.75);
    expect(taskWithLargeCompleted.completionPercentage, 75);
    expect(taskWithLargeCompleted.totalSubtasksPlannedMinutes, 120);
    expect(taskWithLargeCompleted.completedSubtasksPlannedMinutes, 90);

    // If only the 30-minute subtask is completed
    final taskWithSmallCompleted = Task(
      id: 'sub_hrs_2',
      title: 'مهمة ساعتين',
      date: now,
      durationMinutes: 120,
      subtasks: [
        SubTask(id: 's1', title: 'خطوة كبيرة 90 د', durationMinutes: 90, isCompleted: false),
        SubTask(id: 's2', title: 'خطوة صغيرة 30 د', durationMinutes: 30, isCompleted: true),
      ],
    );

    // By count it would be 50%, but by hours it must be 25% (30/120)
    expect(taskWithSmallCompleted.completionProgress, 0.25);
    expect(taskWithSmallCompleted.completionPercentage, 25);
    expect(taskWithSmallCompleted.completedSubtasksPlannedMinutes, 30);
  });

  test('Subtasks with automatic/unassigned durations evenly split remaining hours', () {
    final now = DateTime.now();

    // Main task is 120 minutes (2 hours).
    // Subtask 1 has explicit 60 min.
    // Subtasks 2 & 3 have unassigned durations (should get (120-60)/2 = 30 min each).
    final task = Task(
      id: 'mix_test',
      title: 'مهمة بمزيج أوقات',
      date: now,
      durationMinutes: 120,
      subtasks: [
        SubTask(id: 's1', title: 'خطوة محددة', durationMinutes: 60, isCompleted: false),
        SubTask(id: 's2', title: 'خطوة تلقائية 1', isCompleted: true),
        SubTask(id: 's3', title: 'خطوة تلقائية 2', isCompleted: false),
      ],
    );

    expect(task.subtaskAllocatedMinutes(task.subtasks[0]), 60);
    expect(task.subtaskAllocatedMinutes(task.subtasks[1]), 30);
    expect(task.subtaskAllocatedMinutes(task.subtasks[2]), 30);
    expect(task.totalSubtasksPlannedMinutes, 120);
    expect(task.completedSubtasksPlannedMinutes, 30);
    // 30 / 120 = 25%
    expect(task.completionProgress, 0.25);
    expect(task.completionPercentage, 25);
  });
}

