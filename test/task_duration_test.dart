import 'package:flutter_test/flutter_test.dart';
import 'package:my_tasks/models/task.dart';
import 'package:my_tasks/services/productivity_service.dart';

void main() {
  group('Task actualDurationMinutes tests', () {
    test('Calculates duration difference correctly when completed faster', () {
      final task = Task(
        id: '1',
        title: 'برمجة الميزة',
        date: DateTime.now(),
        durationMinutes: 60,
        actualDurationMinutes: 45,
        isCompleted: true,
      );

      expect(task.effectiveMinutes, 60);
      expect(task.effectiveProductiveMinutes, 45);
      expect(task.durationDifferenceMinutes, -15);
      expect(task.durationDifferenceText, 'وفرت 15 د ⚡');
    });

    test('Calculates duration difference correctly when took longer', () {
      final task = Task(
        id: '2',
        title: 'مذاكرة',
        date: DateTime.now(),
        durationMinutes: 60,
        actualDurationMinutes: 90,
        isCompleted: true,
      );

      expect(task.effectiveMinutes, 60);
      expect(task.effectiveProductiveMinutes, 90);
      expect(task.durationDifferenceMinutes, 30);
      expect(task.durationDifferenceText, 'إضافي 30 د ⏱️');
    });

    test('Calculates duration difference correctly when completed exactly on time', () {
      final task = Task(
        id: '3',
        title: 'اجتماع',
        date: DateTime.now(),
        durationMinutes: 60,
        actualDurationMinutes: 60,
        isCompleted: true,
      );

      expect(task.durationDifferenceMinutes, 0);
      expect(task.durationDifferenceText, 'في نفس الوقت المخطط 🎯');
    });

    test('ProductivityService counts actual duration for productiveHours', () {
      final now = DateTime.now();
      final tasks = [
        Task(
          id: '1',
          title: 'مهمة 1',
          date: now,
          durationMinutes: 60,
          actualDurationMinutes: 45,
          isCompleted: true,
        ),
        Task(
          id: '2',
          title: 'مهمة 2',
          date: now,
          durationMinutes: 60,
          isCompleted: false,
        ),
      ];

      final stats = ProductivityService.getDailyStats(tasks);
      // Productive hours should be 45 mins (0.75h) instead of planned 60 mins (1.0h)
      expect(stats.productiveHours, 0.75);
      expect(stats.plannedHours, 2.0);
    });

    test('Calculates productivity rate based on hours rather than task count', () {
      final now = DateTime.now();
      // 2 tasks: 3 hours (180 min) and 2 hours (120 min)
      final tasks = [
        Task(
          id: '1',
          title: 'مهمة 3 ساعات',
          date: now,
          durationMinutes: 180, // 3 hours
          isCompleted: true,
        ),
        Task(
          id: '2',
          title: 'مهمة ساعتين',
          date: now,
          durationMinutes: 120, // 2 hours
          isCompleted: false,
        ),
      ];

      final stats = ProductivityService.getDailyStats(tasks);
      // 3 hours out of 5 hours planned = 60.0%
      expect(stats.rate, 60.0);
      expect(stats.percentageFormatted, '60%');
      expect(stats.total, 2);
      expect(stats.completed, 1);
      expect(stats.plannedHours, 5.0);
      expect(stats.productiveHours, 3.0);
    });
  });
}
