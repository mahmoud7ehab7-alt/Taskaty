import 'dart:convert';

enum TaskPriority { low, medium, high }

class SubTask {
  final String id;
  final String title;
  final bool isCompleted;
  final int? durationMinutes;

  SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.durationMinutes,
  });

  String get formattedDuration {
    if (durationMinutes == null || durationMinutes! <= 0) return '';
    return Task.formatMinutes(durationMinutes!);
  }

  SubTask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    int? durationMinutes,
    bool clearDuration = false,
  }) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      durationMinutes: clearDuration ? null : (durationMinutes ?? this.durationMinutes),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'durationMinutes': durationMinutes,
    };
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'] as String,
      title: map['title'] as String,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
    );
  }
}

class TimeSlot {
  final String start; // e.g. "01:00 ص"
  final String end;   // e.g. "02:00 ص"

  const TimeSlot({required this.start, required this.end});

  int get durationMinutes => Task.calculateMinutesBetween(start, end);

  String get formattedDuration => Task.formatMinutes(durationMinutes);

  String get formattedWindow => '$start - $end';

  TimeSlot copyWith({String? start, String? end}) {
    return TimeSlot(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      start: (map['start'] as String?) ?? '',
      end: (map['end'] as String?) ?? '',
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final bool isCompleted;
  final TaskPriority priority;
  final String category;
  final DateTime? completedAt;
  final List<SubTask> subtasks;
  final DateTime? reminderDateTime;
  final String? startTime; // Primary start time
  final String? endTime;   // Primary end time
  final List<TimeSlot> timeSlots; // Multiple execution windows
  final int? durationMinutes; // explicit duration in minutes
  final int? actualDurationMinutes; // actual time spent in minutes

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
    this.category = 'عام',
    this.completedAt,
    this.subtasks = const [],
    this.reminderDateTime,
    this.startTime,
    this.endTime,
    this.timeSlots = const [],
    this.durationMinutes,
    this.actualDurationMinutes,
  });

  // Returns all time slots, combining explicit timeSlots or fallback startTime/endTime
  List<TimeSlot> get allTimeSlots {
    if (timeSlots.isNotEmpty) return timeSlots;
    if (startTime != null && endTime != null) {
      return [TimeSlot(start: startTime!, end: endTime!)];
    }
    return const [];
  }

  // Returns formatted string representation of all time windows
  String get formattedTimeSlots {
    final slots = allTimeSlots;
    if (slots.isEmpty) {
      if (startTime != null && endTime != null) return '$startTime - $endTime';
      if (startTime != null) return 'من $startTime';
      if (endTime != null) return 'حتى $endTime';
      return '';
    }
    if (slots.length == 1) return slots.first.formattedWindow;
    return slots.map((s) => s.formattedWindow).join(' • ');
  }

  // Calculate effective minutes for this task (planned)
  int get effectiveMinutes {
    if (durationMinutes != null && durationMinutes! > 0) {
      return durationMinutes!;
    }
    // Sum duration of all execution time windows if present
    if (allTimeSlots.isNotEmpty) {
      final totalSlotMinutes = allTimeSlots.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      if (totalSlotMinutes > 0) return totalSlotMinutes;
    }
    if (startTime != null && endTime != null) {
      final diff = calculateMinutesBetween(startTime!, endTime!);
      if (diff > 0) return diff;
    }
    return 60; // Default estimate: 1 hour (60 minutes)
  }

  int get plannedMinutes => effectiveMinutes;

  // Productive minutes: uses actual duration if completed and available, otherwise planned estimate
  int get effectiveProductiveMinutes {
    if (isCompleted && actualDurationMinutes != null && actualDurationMinutes! > 0) {
      return actualDurationMinutes!;
    }
    return effectiveMinutes;
  }

  // Subtask allocated minutes (uses explicit duration, or evenly distributes task's planned hours)
  int subtaskAllocatedMinutes(SubTask sub) {
    if (sub.durationMinutes != null && sub.durationMinutes! > 0) {
      return sub.durationMinutes!;
    }
    if (subtasks.isNotEmpty) {
      final explicitTotal = subtasks
          .where((s) => s.durationMinutes != null && s.durationMinutes! > 0)
          .fold<int>(0, (sum, s) => sum + s.durationMinutes!);
      final unassignedCount = subtasks
          .where((s) => s.durationMinutes == null || s.durationMinutes! <= 0)
          .length;
      if (unassignedCount > 0) {
        final remaining = effectiveMinutes - explicitTotal;
        if (remaining > 0) {
          final share = (remaining / unassignedCount).round();
          return share > 0 ? share : 1;
        }
      }
      final fallbackShare = (effectiveMinutes / subtasks.length).round();
      return fallbackShare > 0 ? fallbackShare : 1;
    }
    return 0;
  }

  // Total planned minutes across all subtasks
  int get totalSubtasksPlannedMinutes {
    if (subtasks.isEmpty) return 0;
    return subtasks.fold<int>(0, (sum, s) => sum + subtaskAllocatedMinutes(s));
  }

  // Completed planned minutes across completed subtasks
  int get completedSubtasksPlannedMinutes {
    if (subtasks.isEmpty) return 0;
    return subtasks
        .where((s) => s.isCompleted)
        .fold<int>(0, (sum, s) => sum + subtaskAllocatedMinutes(s));
  }

  // Completion percentage strictly calculated by hours (0 to 100)
  int get completionPercentage => (completionProgress * 100).round();

  // Progress ratio from 0.0 to 1.0 (strictly calculated by hours / time duration)
  double get completionProgress {
    if (isCompleted) return 1.0;
    if (subtasks.isEmpty) return 0.0;

    final totalMins = totalSubtasksPlannedMinutes;
    if (totalMins > 0) {
      return (completedSubtasksPlannedMinutes / totalMins).clamp(0.0, 1.0);
    }
    final done = subtasks.where((s) => s.isCompleted).length;
    return (done / subtasks.length).clamp(0.0, 1.0);
  }

  // Productive minutes achieved for this task (full if completed, or proportional to finished subtasks by hours)
  double get effectiveProductiveMinutesAchieved {
    if (isCompleted) {
      return (actualDurationMinutes != null && actualDurationMinutes! > 0)
          ? actualDurationMinutes!.toDouble()
          : effectiveMinutes.toDouble();
    }
    if (subtasks.isNotEmpty) {
      final ratio = completionProgress;
      if (ratio > 0) {
        return (effectiveProductiveMinutes * ratio).clamp(0.0, effectiveProductiveMinutes.toDouble());
      }
    }
    return 0.0;
  }

  // Planned minutes achieved (for productivity rate calculation by hours)
  double get effectivePlannedMinutesAchieved {
    if (isCompleted) {
      return effectiveMinutes.toDouble();
    }
    if (subtasks.isNotEmpty) {
      final ratio = completionProgress;
      if (ratio > 0) {
        return (effectiveMinutes * ratio).clamp(0.0, effectiveMinutes.toDouble());
      }
    }
    return 0.0;
  }

  double get effectiveHours => effectiveMinutes / 60.0;
  double get effectiveProductiveHours => effectiveProductiveMinutes / 60.0;

  static String formatMinutes(int mins) {
    if (mins <= 0) return '0 د';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '$m د';
    if (m == 0) return '$h س';
    return '$h س $m د';
  }

  String get formattedDuration => formatMinutes(effectiveMinutes);

  String get formattedActualDuration {
    if (actualDurationMinutes == null) return '';
    return formatMinutes(actualDurationMinutes!);
  }

  // Difference: positive = took longer, negative = took less time (saved time)
  int? get durationDifferenceMinutes {
    if (actualDurationMinutes == null) return null;
    return actualDurationMinutes! - effectiveMinutes;
  }

  String? get durationDifferenceText {
    final diff = durationDifferenceMinutes;
    if (diff == null) return null;
    if (diff == 0) return 'في نفس الوقت المخطط 🎯';
    if (diff < 0) return 'وفرت ${formatMinutes(diff.abs())} ⚡';
    return 'إضافي ${formatMinutes(diff)} ⏱️';
  }

  static int calculateMinutesBetween(String startStr, String endStr) {
    int? parseToMinutes(String timeStr) {
      try {
        final isPM = timeStr.contains('م') || timeStr.toUpperCase().contains('PM');
        final isAM = timeStr.contains('ص') || timeStr.toUpperCase().contains('AM');
        final cleaned = timeStr.replaceAll(RegExp(r'[^0-9:]'), '');
        final parts = cleaned.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);
          if (isPM && hour < 12) hour += 12;
          if (isAM && hour == 12) hour = 0;
          return hour * 60 + minute;
        }
      } catch (_) {}
      return null;
    }

    final start = parseToMinutes(startStr);
    final end = parseToMinutes(endStr);
    if (start != null && end != null) {
      if (end >= start) {
        return end - start;
      } else {
        // Crosses midnight
        return (24 * 60 - start) + end;
      }
    }
    return 60;
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    bool? isCompleted,
    TaskPriority? priority,
    String? category,
    DateTime? completedAt,
    List<SubTask>? subtasks,
    DateTime? reminderDateTime,
    String? startTime,
    String? endTime,
    List<TimeSlot>? timeSlots,
    int? durationMinutes,
    int? actualDurationMinutes,
    bool clearActualDuration = false,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      subtasks: subtasks ?? this.subtasks,
      reminderDateTime: reminderDateTime ?? this.reminderDateTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      timeSlots: timeSlots ?? this.timeSlots,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      actualDurationMinutes: clearActualDuration
          ? null
          : (actualDurationMinutes ?? this.actualDurationMinutes),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'isCompleted': isCompleted,
      'priority': priority.name,
      'category': category,
      'completedAt': completedAt?.toIso8601String(),
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'reminderDateTime': reminderDateTime?.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'timeSlots': timeSlots.map((s) => s.toMap()).toList(),
      'durationMinutes': durationMinutes,
      'actualDurationMinutes': actualDurationMinutes,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    List<SubTask> loadedSubtasks = [];
    if (map['subtasks'] != null) {
      final list = map['subtasks'] as List;
      loadedSubtasks = list
          .map((item) => SubTask.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    List<TimeSlot> loadedSlots = [];
    if (map['timeSlots'] != null) {
      final list = map['timeSlots'] as List;
      loadedSlots = list
          .map((item) => TimeSlot.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } else if (map['startTime'] != null && map['endTime'] != null) {
      loadedSlots = [
        TimeSlot(start: map['startTime'] as String, end: map['endTime'] as String)
      ];
    }

    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      date: DateTime.parse(map['date'] as String),
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      category: (map['category'] as String?) ?? 'عام',
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
      subtasks: loadedSubtasks,
      reminderDateTime: map['reminderDateTime'] != null
          ? DateTime.tryParse(map['reminderDateTime'] as String)
          : null,
      startTime: map['startTime'] as String?,
      endTime: map['endTime'] as String?,
      timeSlots: loadedSlots,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
      actualDurationMinutes: (map['actualDurationMinutes'] as num?)?.toInt(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) =>
      Task.fromMap(json.decode(source) as Map<String, dynamic>);
}
