import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'auth_service.dart';

class TaskService extends ChangeNotifier {
  static const String _defaultStorageKey = 'saved_tasks_v1';

  final FirebaseFirestore? _firestore;
  final AuthService? authService;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSubscription;

  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _activeUserId;

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;

  TaskService({this.authService, FirebaseFirestore? firestore})
      : _firestore = firestore ?? _safeFirestore() {
    if (authService != null) {
      authService!.addListener(_onAuthChanged);
      _activeUserId = authService!.currentUser?.id;
    }
    _init();
  }

  static FirebaseFirestore? _safeFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('Firestore unavailable (running local mode): $e');
      return null;
    }
  }

  String get _storageKey {
    if (_activeUserId != null && _activeUserId!.isNotEmpty) {
      return 'saved_tasks_user_$_activeUserId';
    }
    return _defaultStorageKey;
  }

  CollectionReference<Map<String, dynamic>>? get _userTasksCollection {
    if (_firestore == null || _activeUserId == null || _activeUserId!.isEmpty) {
      return null;
    }
    return _firestore.collection('users').doc(_activeUserId).collection('tasks');
  }

  void _onAuthChanged() {
    final currentId = authService?.currentUser?.id;
    if (currentId != _activeUserId) {
      _activeUserId = currentId;
      _firestoreSubscription?.cancel();
      loadTasks();
    }
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    authService?.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _init() async {
    await loadTasks();
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Step 1: Load from SharedPreferences first (offline-first & instant UI)
      final prefs = await SharedPreferences.getInstance();
      final List<String>? rawList = prefs.getStringList(_storageKey) ??
          prefs.getStringList(_defaultStorageKey);

      if (rawList != null && rawList.isNotEmpty) {
        _tasks = rawList.map((str) => Task.fromJson(str)).toList();
      } else {
        // Starter onboarding tasks for new users
        _tasks = _getStarterTasks();
        await _saveToPrefs();
      }

      // Step 2: If Firestore and User are available, bind real-time sync
      final collection = _userTasksCollection;
      if (collection != null) {
        _bindFirestoreStream(collection);
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _bindFirestoreStream(CollectionReference<Map<String, dynamic>> collection) {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = collection.snapshots().listen(
      (snapshot) async {
        if (snapshot.docs.isEmpty) {
          // New remote collection: seed local starter tasks if available
          if (_tasks.isNotEmpty) {
            final batch = _firestore?.batch();
            if (batch != null) {
              for (final t in _tasks) {
                batch.set(collection.doc(t.id), t.toMap());
              }
              try {
                await batch.commit();
              } catch (e) {
                debugPrint('Error seeding starter tasks to Firestore: $e');
              }
            }
          }
        } else {
          // Update local tasks from Firestore documents
          final remoteTasks = snapshot.docs.map((doc) {
            final data = doc.data();
            // Ensure ID is set
            if (!data.containsKey('id') || data['id'] == null) {
              data['id'] = doc.id;
            }
            return Task.fromMap(data);
          }).toList();

          // Sort tasks: pending first, then by date descending
          remoteTasks.sort((a, b) {
            if (a.isCompleted != b.isCompleted) {
              return a.isCompleted ? 1 : -1;
            }
            return b.date.compareTo(a.date);
          });

          _tasks = remoteTasks;
          await _saveToPrefs();
          notifyListeners();
        }
      },
      onError: (e) {
        debugPrint('Firestore tasks snapshot error: $e');
      },
    );
  }

  List<Task> _getStarterTasks() {
    final now = DateTime.now();
    return [
      Task(
        id: '1',
        title: 'إنجاز مهام العمل الرئيسية 💼',
        description: 'التركيز على أولويات العمل والمهام اليومية.',
        date: now,
        isCompleted: true,
        priority: TaskPriority.high,
        category: 'عمل',
        completedAt: now,
        startTime: '09:00 ص',
        endTime: '10:00 ص',
        durationMinutes: 60,
        actualDurationMinutes: 50,
      ),
      Task(
        id: '2',
        title: 'جلسة دراسة وتطوير مهارات 📚',
        description: 'قراءة درس أو مراجعة مادة تعليمية بدون تشتت.',
        date: now,
        isCompleted: false,
        priority: TaskPriority.high,
        category: 'دراسة',
        startTime: '10:30 ص',
        endTime: '12:00 م',
        durationMinutes: 90,
      ),
      Task(
        id: '3',
        title: 'ممارسة الرياضة والمشي 🏃‍♂️',
        description: 'نشاط بدني للحفاظ على الصحة واللياقة والطاقة.',
        date: now,
        isCompleted: false,
        priority: TaskPriority.medium,
        category: 'صحة',
        startTime: '05:00 م',
        endTime: '06:00 م',
        durationMinutes: 60,
      ),
    ];
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = _tasks.map((t) => t.toJson()).toList();
      await prefs.setStringList(_storageKey, rawList);
    } catch (e) {
      debugPrint('Error saving tasks to local storage: $e');
    }
  }

  Future<void> addTask(Task task) async {
    _tasks.insert(0, task);
    notifyListeners();
    await _saveToPrefs();

    final collection = _userTasksCollection;
    if (collection != null) {
      try {
        await collection.doc(task.id).set(task.toMap());
      } catch (e) {
        debugPrint('Error saving task to Firestore: $e');
      }
    }
  }

  Future<void> updateTask(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      notifyListeners();
      await _saveToPrefs();

      final collection = _userTasksCollection;
      if (collection != null) {
        try {
          await collection.doc(task.id).set(task.toMap());
        } catch (e) {
          debugPrint('Error updating task in Firestore: $e');
        }
      }
    }
  }

  Future<void> toggleTask(String id, {int? actualDurationMinutes}) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final current = _tasks[index];
      final newStatus = !current.isCompleted;
      final updatedSubtasks = newStatus
          ? current.subtasks.map((st) => st.copyWith(isCompleted: true)).toList()
          : current.subtasks.map((st) => st.copyWith(isCompleted: false)).toList();

      final updated = current.copyWith(
        isCompleted: newStatus,
        completedAt: newStatus ? DateTime.now() : null,
        actualDurationMinutes: newStatus
            ? (actualDurationMinutes ?? current.effectiveMinutes)
            : null,
        clearActualDuration: !newStatus,
        clearCompletedAt: !newStatus,
        subtasks: updatedSubtasks,
      );
      _tasks[index] = updated;
      notifyListeners();
      await _saveToPrefs();

      final collection = _userTasksCollection;
      if (collection != null) {
        try {
          await collection.doc(id).set(updated.toMap());
        } catch (e) {
          debugPrint('Error updating task status in Firestore: $e');
        }
      }
    }
  }

  Future<void> updateActualDuration(String id, int actualMinutes) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final current = _tasks[index];
      final updated = current.copyWith(
        actualDurationMinutes: actualMinutes,
      );
      _tasks[index] = updated;
      notifyListeners();
      await _saveToPrefs();

      final collection = _userTasksCollection;
      if (collection != null) {
        try {
          await collection.doc(id).set(updated.toMap());
        } catch (e) {
          debugPrint('Error updating task actual duration in Firestore: $e');
        }
      }
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveToPrefs();

    final collection = _userTasksCollection;
    if (collection != null) {
      try {
        await collection.doc(id).delete();
      } catch (e) {
        debugPrint('Error deleting task from Firestore: $e');
      }
    }
  }

  Future<void> toggleSubTask(String taskId, String subTaskId) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];
    final updatedSubtasks = task.subtasks.map((st) {
      if (st.id == subTaskId) {
        return st.copyWith(isCompleted: !st.isCompleted);
      }
      return st;
    }).toList();

    // Check if all subtasks are finished
    final allCompleted = updatedSubtasks.isNotEmpty &&
        updatedSubtasks.every((st) => st.isCompleted);

    final bool newIsCompleted = allCompleted;

    final updatedTask = task.copyWith(
      subtasks: updatedSubtasks,
      isCompleted: newIsCompleted,
      completedAt: newIsCompleted ? (task.completedAt ?? DateTime.now()) : null,
      actualDurationMinutes: newIsCompleted
          ? (task.actualDurationMinutes ?? task.effectiveMinutes)
          : null,
      clearActualDuration: !newIsCompleted,
      clearCompletedAt: !newIsCompleted,
    );

    _tasks[taskIndex] = updatedTask;
    notifyListeners();
    await _saveToPrefs();

    final collection = _userTasksCollection;
    if (collection != null) {
      try {
        await collection.doc(taskId).set(updatedTask.toMap());
      } catch (e) {
        debugPrint('Error updating subtask in Firestore: $e');
      }
    }
  }
}
