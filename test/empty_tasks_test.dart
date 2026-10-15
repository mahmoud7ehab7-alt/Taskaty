import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_tasks/services/task_service.dart';
import 'package:my_tasks/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('New user starts with completely empty task list (no dummy/starter tasks)', () async {
    SharedPreferences.setMockInitialValues({});

    final taskService = TaskService();
    await taskService.loadTasks();

    expect(taskService.tasks, isEmpty);
  });

  test('Existing dummy starter tasks in SharedPreferences are automatically filtered out', () async {
    final now = DateTime.now();
    final dummyTasksJson = [
      Task(
        id: '1',
        title: 'إنجاز مهام العمل الرئيسية 💼',
        date: now,
        priority: TaskPriority.high,
      ).toJson(),
      Task(
        id: '2',
        title: 'جلسة دراسة وتطوير مهارات 📚',
        date: now,
        priority: TaskPriority.high,
      ).toJson(),
      Task(
        id: '3',
        title: 'ممارسة الرياضة والمشي 🏃‍♂️',
        date: now,
        priority: TaskPriority.medium,
      ).toJson(),
    ];

    SharedPreferences.setMockInitialValues({
      'saved_tasks_v1': dummyTasksJson,
    });

    final taskService = TaskService();
    await taskService.loadTasks();

    expect(taskService.tasks, isEmpty);
  });

  test('Real user-created tasks are preserved and not filtered', () async {
    final now = DateTime.now();
    final realTask = Task(
      id: 'custom_123',
      title: 'مهمتي الحقيقية الخاصة',
      date: now,
      priority: TaskPriority.high,
    );

    SharedPreferences.setMockInitialValues({
      'saved_tasks_v1': [realTask.toJson()],
    });

    final taskService = TaskService();
    await taskService.loadTasks();

    expect(taskService.tasks.length, 1);
    expect(taskService.tasks.first.title, 'مهمتي الحقيقية الخاصة');
  });
}
