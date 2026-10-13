import 'package:flutter_test/flutter_test.dart';
import 'package:my_tasks/models/task.dart';
import 'package:my_tasks/services/productivity_service.dart';

void main() {
  group('Category Analytics Tests', () {
    final targetDate = DateTime(2026, 10, 12);

    final testTasks = [
      // Work task (completed, 120 mins)
      Task(
        id: 'w1',
        title: 'برمجة وتطوير',
        date: targetDate,
        category: 'عمل',
        isCompleted: true,
        durationMinutes: 120,
        actualDurationMinutes: 120,
      ),
      // Work task (pending, 60 mins)
      Task(
        id: 'w2',
        title: 'اجتماع عمل',
        date: targetDate,
        category: 'عمل',
        isCompleted: false,
        durationMinutes: 60,
      ),
      // Study task (completed, 90 mins)
      Task(
        id: 's1',
        title: 'مذاكرة لغات',
        date: targetDate,
        category: 'دراسة',
        isCompleted: true,
        durationMinutes: 90,
      ),
      // Health task (completed, 45 mins)
      Task(
        id: 'h1',
        title: 'تمرين جيم',
        date: targetDate,
        category: 'صحة',
        isCompleted: true,
        durationMinutes: 45,
      ),
    ];

    test('getCategoryDailyStats filters properly by category for selected day', () {
      final workDaily = ProductivityService.getCategoryDailyStats(testTasks, 'عمل', date: targetDate);
      expect(workDaily.total, 2);
      expect(workDaily.completed, 1);
      expect(workDaily.plannedHours, 3.0); // 120 + 60 = 180 mins = 3 hours
      expect(workDaily.productiveHours, 2.0); // 120 mins = 2 hours

      final studyDaily = ProductivityService.getCategoryDailyStats(testTasks, 'دراسة', date: targetDate);
      expect(studyDaily.total, 1);
      expect(studyDaily.completed, 1);
      expect(studyDaily.productiveHours, 1.5); // 90 mins

      final healthDaily = ProductivityService.getCategoryDailyStats(testTasks, 'صحة', date: targetDate);
      expect(healthDaily.total, 1);
      expect(healthDaily.completed, 1);
      expect(healthDaily.productiveHours, 0.75); // 45 mins
    });

    test('getCategoryWeeklyStats aggregates only matching category in that week', () {
      final workWeekly = ProductivityService.getCategoryWeeklyStats(testTasks, 'عمل', referenceDate: targetDate);
      expect(workWeekly.total, 2);
      expect(workWeekly.completed, 1);
      expect(workWeekly.productiveHours, 2.0);
    });

    test('getCategoryMonthlyStats aggregates month hours for category', () {
      final studyMonthly = ProductivityService.getCategoryMonthlyStats(testTasks, 'دراسة', year: 2026, month: 10);
      expect(studyMonthly.total, 1);
      expect(studyMonthly.completed, 1);
      expect(studyMonthly.productiveHours, 1.5);
    });
  });
}
