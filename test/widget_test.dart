import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_tasks/main.dart';
import 'package:my_tasks/services/task_service.dart';
import 'package:my_tasks/services/auth_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
  });

  testWidgets('MyTasksApp loads and displays auth screen or home screen correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final authService = AuthService();
    final taskService = TaskService(authService: authService);

    await tester.pumpWidget(MyTasksApp(
      taskService: taskService,
      authService: authService,
    ));
    await tester.pumpAndSettle();

    // Default without login shows AuthScreen
    expect(find.text('تاسكاتي • Taskaty'), findsOneWidget);
    expect(find.text('تسجيل الدخول 🔑'), findsOneWidget);
  });
}
