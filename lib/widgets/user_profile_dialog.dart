import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';
import '../services/productivity_service.dart';
import '../theme/app_theme.dart';

class UserProfileDialog extends StatelessWidget {
  final AuthService authService;
  final TaskService taskService;

  const UserProfileDialog({
    super.key,
    required this.authService,
    required this.taskService,
  });

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasks = taskService.tasks;
    final streak = ProductivityService.getStreak(tasks);
    final completedCount = tasks.where((t) => t.isCompleted).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              child: Text(
                user != null && user.name.isNotEmpty
                    ? user.name.characters.first.toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // User Name
            Text(
              user?.name ?? 'مستخدم',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // User Email
            Text(
              user?.email ?? '',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            // Quick Stats Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132A32) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F4450) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$completedCount',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentSuccess,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'مهام منجزة',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  Column(
                    children: [
                      Text(
                        '${streak.currentStreak}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'أيام الالتزام 🔥',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  authService.logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('تسجيل الخروج'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentDanger.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.accentDanger,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
