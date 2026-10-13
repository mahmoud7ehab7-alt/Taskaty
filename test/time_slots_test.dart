import 'package:flutter_test/flutter_test.dart';
import 'package:my_tasks/models/task.dart';

void main() {
  group('TimeSlot & Multiple Execution Windows Tests', () {
    test('Calculates individual slot durations correctly', () {
      final slot1 = TimeSlot(start: '01:00 AM', end: '02:00 AM');
      expect(slot1.durationMinutes, 60);

      final slot2 = TimeSlot(start: '05:00 PM', end: '08:00 PM');
      expect(slot2.durationMinutes, 180);

      // Crossing midnight (11 PM to 1 AM)
      final slotMidnight = TimeSlot(start: '11:00 PM', end: '01:00 AM');
      expect(slotMidnight.durationMinutes, 120);
    });

    test('Task effectiveMinutes sums all multiple time slots', () {
      final task = Task(
        id: 'slot-task-1',
        title: 'مهمة فترات متعددة',
        date: DateTime.now(),
        priority: TaskPriority.high,
        timeSlots: [
          TimeSlot(start: '01:00 AM', end: '02:00 AM'), // 60 mins
          TimeSlot(start: '05:00 PM', end: '08:00 PM'), // 180 mins
        ],
      );

      expect(task.allTimeSlots.length, 2);
      expect(Task.formatMinutes(task.effectiveMinutes), '4 س');
    });

    test('Task formats multiple time slot badges clearly', () {
      final task = Task(
        id: 'slot-task-2',
        title: 'مهمة فترات',
        date: DateTime.now(),
        priority: TaskPriority.medium,
        timeSlots: [
          TimeSlot(start: '01:00', end: '02:00'),
          TimeSlot(start: '17:00', end: '20:00'),
        ],
      );

      expect(task.formattedTimeSlots.contains('01:00 - 02:00'), true);
      expect(task.formattedTimeSlots.contains('17:00 - 20:00'), true);
      expect(task.formattedTimeSlots.contains('•'), true);
    });

    test('Serializes and deserializes timeSlots to/from Firestore map', () {
      final originalTask = Task(
        id: 'slot-task-3',
        title: 'مهمة حفظ وسحب',
        date: DateTime(2026, 10, 12),
        priority: TaskPriority.high,
        timeSlots: [
          TimeSlot(start: '01:00 ص', end: '02:00 ص'),
          TimeSlot(start: '05:00 م', end: '08:00 م'),
        ],
      );

      final map = originalTask.toMap();
      expect(map['timeSlots'], isA<List>());
      expect((map['timeSlots'] as List).length, 2);

      final restoredTask = Task.fromMap(map);
      expect(restoredTask.timeSlots.length, 2);
      expect(restoredTask.timeSlots[0].start, '01:00 ص');
      expect(restoredTask.timeSlots[0].end, '02:00 ص');
      expect(restoredTask.timeSlots[1].start, '05:00 م');
      expect(restoredTask.timeSlots[1].end, '08:00 م');
    });

    test('Legacy fallback to single startTime/endTime works if timeSlots is empty', () {
      final legacyTask = Task(
        id: 'legacy-task',
        title: 'مهمة قديمة',
        date: DateTime.now(),
        priority: TaskPriority.low,
        startTime: '09:00 AM',
        endTime: '11:00 AM',
        timeSlots: [],
      );

      expect(legacyTask.allTimeSlots.length, 1);
      expect(legacyTask.allTimeSlots.first.start, '09:00 AM');
      expect(legacyTask.allTimeSlots.first.end, '11:00 AM');
      expect(legacyTask.effectiveMinutes, 120);
    });
  });
}
