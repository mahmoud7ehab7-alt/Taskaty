import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'category_screen.dart';
import 'analytics_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final TaskService taskService;
  final AuthService authService;

  const MainNavigationScreen({
    super.key,
    required this.taskService,
    required this.authService,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  DateTime _selectedDate = DateTime.now();

  void _onDateChanged(DateTime date) {
    setState(() => _selectedDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        taskService: widget.taskService,
        authService: widget.authService,
        selectedDate: _selectedDate,
        onDateChanged: _onDateChanged,
        onNavigateToAnalytics: () {
          setState(() => _currentIndex = 2);
        },
      ),
      CategoryScreen(
        taskService: widget.taskService,
        selectedDate: _selectedDate,
        onDateChanged: _onDateChanged,
      ),
      AnalyticsScreen(
        taskService: widget.taskService,
        selectedDate: _selectedDate,
        onDateChanged: _onDateChanged,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1F4450)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.check_circle_outline_rounded),
              selectedIcon: Icon(Icons.check_circle_rounded),
              label: 'المهام',
            ),
            NavigationDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category_rounded),
              label: 'المجالات',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'الإنتاجية',
            ),
          ],
        ),
      ),
    );
  }
}
