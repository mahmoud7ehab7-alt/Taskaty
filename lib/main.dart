import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/task_service.dart';
import 'services/auth_service.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  final authService = AuthService();
  final taskService = TaskService(authService: authService);

  runApp(MyTasksApp(
    taskService: taskService,
    authService: authService,
  ));
}

class MyTasksApp extends StatelessWidget {
  final TaskService taskService;
  final AuthService authService;

  const MyTasksApp({
    super.key,
    required this.taskService,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskaty',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        // Enforce RTL directionality for Arabic UI
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
      home: ListenableBuilder(
        listenable: authService,
        builder: (context, _) {
          if (authService.isLoading) {
            return const SplashScreen();
          }

          if (authService.isLoggedIn) {
            return MainNavigationScreen(
              taskService: taskService,
              authService: authService,
            );
          }

          return AuthScreen(authService: authService);
        },
      ),
    );
  }
}
