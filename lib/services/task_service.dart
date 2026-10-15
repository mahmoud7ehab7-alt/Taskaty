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
      _tasks = [];
      notifyListeners();
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
      final List<String>? rawList = _activeUserId != null
          ? prefs.getStringList(_storageKey)
          : prefs.getStringList(_defaultStorageKey);

      if (rawList != null && rawList.isNotEmpty) {
        _tasks = rawList
            .map((str) => Task.fromJson(str))
            .where((t) => !_isStarterDummyTask(t))
            .toList();
      } else {
        _tasks = [];
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
          // New remote collection for this account: user starts clean with 0 tasks
          _tasks = [];
          await _saveToPrefs();
          notifyListeners();
        } else {
          // Extract remote tasks, filtering and purging any dummy starter tasks if present
          final remoteTasks = <Task>[];
          final starterDocsToDelete = <String>[];

          for (final doc in snapshot.docs) {
            final data = Map<String, dynamic>.from(doc.data());
            if (!data.containsKey('id') || data['id'] == null) {
              data['id'] = doc.id;
            }
            final task = Task.fromMap(data);
            if (_isStarterDummyTask(task)) {
              starterDocsToDelete.add(doc.id);
            } else {
              remoteTasks.add(task);
            }
          }

          // Clean up dummy starter tasks from remote Firestore collection if found
          if (starterDocsToDelete.isNotEmpty && _firestore != null) {
            final batch = _firestore!.batch();
            for (final docId in starterDocsToDelete) {
              batch.delete(collection.doc(docId));
            }
            try {
              await batch.commit();
            } catch (e) {
              debugPrint('Error cleaning up dummy tasks from Firestore: $e');
            }
          }

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

  static bool _isStarterDummyTask(Task t) {
    return (t.id == '1' || t.id == '2' || t.id == '3') &&
        (t.title.contains('إنجاز مهام العمل') ||
            t.title.contains('جلسة دراسة') ||
            t.title.contains('ممارسة الرياضة'));
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

  Future<void> updateSubTaskTitle(String taskId, String subTaskId, String newTitle) async {
    final trimmedTitle = newTitle.trim();
    if (trimmedTitle.isEmpty) return;

    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];
    final updatedSubtasks = task.subtasks.map((st) {
      if (st.id == subTaskId) {
        return st.copyWith(title: trimmedTitle);
      }
      return st;
    }).toList();

    final updatedTask = task.copyWith(subtasks: updatedSubtasks);

    _tasks[taskIndex] = updatedTask;
    notifyListeners();
    await _saveToPrefs();

    final collection = _userTasksCollection;
    if (collection != null) {
      try {
        await collection.doc(taskId).set(updatedTask.toMap());
      } catch (e) {
        debugPrint('Error updating subtask title in Firestore: $e');
      }
    }
  }
}
