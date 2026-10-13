import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  static const String _usersKey = 'app_users_v1';
  static const String _sessionKey = 'current_user_session_v1';
  static const String _userDataKey = 'current_user_data_v1';

  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  // In-memory brute-force protection (email -> list of failed attempt timestamps)
  final Map<String, List<DateTime>> _failedLoginAttempts = {};

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  StreamSubscription<User?>? _authSubscription;

  AppUser? _currentUser;
  bool _isLoading = true;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? _safeFirebaseAuth(),
        _firestore = firestore ?? _safeFirestore() {
    _init();
  }

  static String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _hashPassword(String password, String salt) {
    final saltedBytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(saltedBytes);
    return 'sha256\$$salt\$${digest.toString()}';
  }

  static bool _verifyPassword(String password, String storedHash) {
    if (storedHash.startsWith('sha256\$')) {
      final parts = storedHash.split('\$');
      if (parts.length == 3) {
        final salt = parts[1];
        final expectedHash = parts[2];
        final actual = sha256.convert(utf8.encode('$salt:$password')).toString();
        return _constantTimeCompare(expectedHash, actual);
      }
    }
    // Backward compatibility for legacy plaintext passwords
    return password == storedHash;
  }

  static bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  bool _isThrottled(String email) {
    final now = DateTime.now();
    final attempts = _failedLoginAttempts[email.toLowerCase()] ?? [];
    final recent = attempts.where((d) => now.difference(d).inMinutes < 5).toList();
    _failedLoginAttempts[email.toLowerCase()] = recent;
    return recent.length >= 5;
  }

  void _recordFailedAttempt(String email) {
    final key = email.toLowerCase();
    final list = _failedLoginAttempts.putIfAbsent(key, () => []);
    list.add(DateTime.now());
  }

  void _clearFailedAttempts(String email) {
    _failedLoginAttempts.remove(email.toLowerCase());
  }

  static FirebaseAuth? _safeFirebaseAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      debugPrint('FirebaseAuth unavailable (running local fallback): $e');
      return null;
    }
  }

  static FirebaseFirestore? _safeFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('FirebaseFirestore unavailable (running local fallback): $e');
      return null;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // First: load cached user session for instant rendering
      final cachedJson = prefs.getString(_userDataKey);
      if (cachedJson != null) {
        try {
          _currentUser = AppUser.fromJson(cachedJson);
        } catch (_) {}
      }

      // If Firebase Auth is available, listen to real-time auth changes
      if (_auth != null) {
        _authSubscription = _auth.authStateChanges().listen((User? fbUser) async {
          if (fbUser != null) {
            String name = fbUser.displayName ?? '';

            // Try to fetch custom profile name from Firestore if missing
            if (name.isEmpty && _firestore != null) {
              try {
                final doc = await _firestore.collection('users').doc(fbUser.uid).get();
                if (doc.exists && doc.data() != null) {
                  name = (doc.data()!['name'] as String?) ?? '';
                }
              } catch (_) {}
            }

            if (name.isEmpty) {
              if (fbUser.isAnonymous) {
                name = 'ضيف كريم';
              } else if (fbUser.email != null && fbUser.email!.isNotEmpty) {
                name = fbUser.email!.split('@').first;
              } else {
                name = 'مستخدم';
              }
            }

            _currentUser = AppUser(
              id: fbUser.uid,
              name: name,
              email: fbUser.email ?? (fbUser.isAnonymous ? 'guest@tasks.local' : 'user@tasks.local'),
              password: '',
              createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
              isAnonymous: fbUser.isAnonymous,
            );

            await prefs.setString(_sessionKey, fbUser.uid);
            await prefs.setString(_userDataKey, _currentUser!.toSessionJson());
          } else {
            // Only clear if not in an offline-only session
            if (_currentUser != null && !_currentUser!.id.startsWith('local_')) {
              _currentUser = null;
              await prefs.remove(_sessionKey);
              await prefs.remove(_userDataKey);
            }
          }

          _isLoading = false;
          notifyListeners();
        });
      } else {
        // Fallback local users
        final currentUserId = prefs.getString(_sessionKey);
        final users = await _loadLocalUsers(prefs);

        if (users.isEmpty) {
          final salt = _generateSalt();
          final demo = AppUser(
            id: 'demo_user',
            name: 'أحمد محمد',
            email: 'demo@tasks.com',
            password: _hashPassword('password123', salt),
            createdAt: DateTime.now(),
          );
          users.add(demo);
          await _saveLocalUsers(prefs, users);
        }

        if (currentUserId != null) {
          final found = users.firstWhere(
            (u) => u.id == currentUserId,
            orElse: () => users.first,
          );
          _currentUser = found.copyWith(password: '');
        }
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in AuthService init: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<AppUser>> _loadLocalUsers(SharedPreferences prefs) async {
    final list = prefs.getStringList(_usersKey) ?? [];
    return list.map((str) => AppUser.fromJson(str)).toList();
  }

  Future<void> _saveLocalUsers(SharedPreferences prefs, List<AppUser> users) async {
    final list = users.map((u) => u.toJson()).toList();
    await prefs.setStringList(_usersKey, list);
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanPass = password.trim();

    if (_auth != null) {
      try {
        final cred = await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPass,
        );

        final fbUser = cred.user;
        if (fbUser != null) {
          String name = fbUser.displayName ?? '';
          if (name.isEmpty && _firestore != null) {
            try {
              final doc = await _firestore.collection('users').doc(fbUser.uid).get();
              if (doc.exists && doc.data() != null) {
                name = (doc.data()!['name'] as String?) ?? '';
              }
            } catch (_) {}
          }

          if (name.isEmpty) {
            name = cleanEmail.split('@').first;
          }

          _currentUser = AppUser(
            id: fbUser.uid,
            name: name,
            email: fbUser.email ?? cleanEmail,
            password: '',
            createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_sessionKey, fbUser.uid);
          await prefs.setString(_userDataKey, _currentUser!.toSessionJson());
          notifyListeners();
          return null;
        }
      } on FirebaseAuthException catch (e) {
        // If demo user is being used and not yet created in Firebase, auto-create it
        if (cleanEmail.toLowerCase() == 'demo@tasks.com' &&
            (e.code == 'user-not-found' || e.code == 'invalid-credential')) {
          try {
            final cred = await _auth.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: cleanPass,
            );
            await cred.user?.updateDisplayName('أحمد محمد');
            if (_firestore != null && cred.user != null) {
              await _firestore.collection('users').doc(cred.user!.uid).set({
                'name': 'أحمد محمد',
                'email': cleanEmail,
                'createdAt': DateTime.now().toIso8601String(),
              });
            }
            return null; // Login succeeded via auto-provision
          } catch (_) {}
        }

        switch (e.code) {
          case 'user-not-found':
            return 'البريد الإلكتروني غير مسجل، يرجى إنشاء حساب جديد.';
          case 'wrong-password':
          case 'invalid-credential':
            return 'بيانات تسجيل الدخول أو كلمة المرور غير صحيحة.';
          case 'invalid-email':
            return 'صيغة البريد الإلكتروني غير صحيحة.';
          case 'user-disabled':
            return 'تم تعطيل هذا الحساب، يرجى التواصل مع الإدارة.';
          case 'too-many-requests':
            return 'تم حظر تسجيل الدخول مؤقتاً لكثرة المحاولات، يرجى المحاولة بعد قليل.';
          case 'network-request-failed':
            return 'تعذر الاتصال بفايربيز، يرجى التحقق من اتصالك بالإنترنت.';
          default:
            return 'خطأ في تسجيل الدخول: ${e.message ?? e.code}';
        }
      } catch (e) {
        return 'حدث خطأ أثناء تسجيل الدخول: $e';
      }
    }

    // Local fallback when Firebase is not active
    try {
      if (_isThrottled(cleanEmail)) {
        return 'تم حظر تسجيل الدخول مؤقتاً لتكرار المحاولات الفاشلة، يرجى الانتظار 5 دقائق.';
      }

      final prefs = await SharedPreferences.getInstance();
      final users = await _loadLocalUsers(prefs);

      final userIndex = users.indexWhere(
        (u) => u.email.toLowerCase() == cleanEmail.toLowerCase(),
      );

      if (userIndex == -1) {
        _recordFailedAttempt(cleanEmail);
        return 'البريد الإلكتروني غير مسجل، يرجى إنشاء حساب جديد.';
      }

      final user = users[userIndex];

      if (!_verifyPassword(cleanPass, user.password)) {
        _recordFailedAttempt(cleanEmail);
        return 'كلمة المرور غير صحيحة، يرجى المحاولة مجدداً.';
      }

      _clearFailedAttempts(cleanEmail);

      // Auto-migrate legacy unhashed passwords to salted hash
      if (!user.password.startsWith('sha256\$')) {
        final salt = _generateSalt();
        users[userIndex] = user.copyWith(password: _hashPassword(cleanPass, salt));
        await _saveLocalUsers(prefs, users);
      }

      _currentUser = user.copyWith(password: '');
      await prefs.setString(_sessionKey, user.id);
      await prefs.setString(_userDataKey, _currentUser!.toSessionJson());
      notifyListeners();
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء تسجيل الدخول: $e';
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    final cleanPass = password.trim();

    if (cleanName.length < 2 || cleanName.length > 60) {
      return 'يجب أن يكون الاسم بين حرفين و 60 حرفاً';
    }
    if (!emailRegex.hasMatch(cleanEmail)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    if (cleanPass.length < 6 || cleanPass.length > 128) {
      return 'يجب أن تتكون كلمة المرور من 6 إلى 128 حرفاً أو رقماً';
    }

    if (_auth != null) {
      try {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPass,
        );

        final fbUser = cred.user;
        if (fbUser != null) {
          await fbUser.updateDisplayName(cleanName);

          if (_firestore != null) {
            await _firestore.collection('users').doc(fbUser.uid).set({
              'name': cleanName,
              'email': cleanEmail.toLowerCase(),
              'createdAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
          }

          _currentUser = AppUser(
            id: fbUser.uid,
            name: cleanName,
            email: cleanEmail.toLowerCase(),
            password: '',
            createdAt: DateTime.now(),
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_sessionKey, fbUser.uid);
          await prefs.setString(_userDataKey, _currentUser!.toSessionJson());
          notifyListeners();
          return null;
        }
      } on FirebaseAuthException catch (e) {
        switch (e.code) {
          case 'email-already-in-use':
            return 'هذا البريد الإلكتروني مسجل بالفعل، يمكنك تسجيل الدخول به.';
          case 'weak-password':
            return 'كلمة المرور ضعيفة، يرجى اختيار كلمة مرور أقوى.';
          case 'invalid-email':
            return 'صيغة البريد الإلكتروني غير صحيحة.';
          case 'network-request-failed':
            return 'تعذر الاتصال بفايربيز، يرجى التحقق من اتصالك بالإنترنت.';
          default:
            return 'حدث خطأ أثناء إنشاء الحساب: ${e.message ?? e.code}';
        }
      } catch (e) {
        return 'حدث خطأ أثناء إنشاء الحساب: $e';
      }
    }

    // Local fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = await _loadLocalUsers(prefs);

      final exists = users.any(
        (u) => u.email.toLowerCase() == cleanEmail.toLowerCase(),
      );

      if (exists) {
        return 'هذا البريد الإلكتروني مسجل بالفعل، يمكنك تسجيل الدخول.';
      }

      final salt = _generateSalt();
      final hashedPassword = _hashPassword(cleanPass, salt);

      final newUser = AppUser(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanName,
        email: cleanEmail.toLowerCase(),
        password: hashedPassword,
        createdAt: DateTime.now(),
      );

      users.add(newUser);
      await _saveLocalUsers(prefs, users);

      _currentUser = newUser.copyWith(password: '');
      await prefs.setString(_sessionKey, newUser.id);
      await prefs.setString(_userDataKey, _currentUser!.toSessionJson());
      notifyListeners();
      return null;
    } catch (e) {
      return 'حدث خطأ أثناء إنشاء الحساب: $e';
    }
  }

  Future<void> loginAsGuest() async {
    if (_auth != null) {
      try {
        final cred = await _auth.signInAnonymously();
        final fbUser = cred.user;
        if (fbUser != null) {
          _currentUser = AppUser(
            id: fbUser.uid,
            name: 'ضيف كريم 👤',
            email: 'guest@tasks.local',
            password: '',
            createdAt: DateTime.now(),
            isAnonymous: true,
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_sessionKey, fbUser.uid);
          await prefs.setString(_userDataKey, _currentUser!.toSessionJson());
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('Firebase anonymous login skipped or disabled, using local guest: $e');
      }
    }

    // Local guest fallback
    final prefs = await SharedPreferences.getInstance();
    final guest = AppUser(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: 'ضيف كريم 👤',
      email: 'guest@tasks.local',
      password: '',
      createdAt: DateTime.now(),
      isAnonymous: true,
    );

    _currentUser = guest;
    await prefs.setString(_sessionKey, guest.id);
    await prefs.setString(_userDataKey, guest.toSessionJson());
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if (_auth != null) {
        await _auth.signOut();
      }
    } catch (e) {
      debugPrint('Error during FirebaseAuth sign out: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_userDataKey);
    _currentUser = null;
    notifyListeners();
  }
}
