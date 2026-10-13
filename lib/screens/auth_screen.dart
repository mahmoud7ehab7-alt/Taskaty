import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final AuthService authService;

  const AuthScreen({
    super.key,
    required this.authService,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true; // true = Login, false = Register
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? error;
    if (_isLogin) {
      error = await widget.authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _isLoading = false);
        _showError('كلمتا المرور غير متطابقتين');
        return;
      }

      error = await widget.authService.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    }

    setState(() => _isLoading = false);

    if (error != null && mounted) {
      _showError(error);
    }
  }

  void _fillDemoAccount() {
    _emailController.text = 'demo@tasks.com';
    _passwordController.text = 'password123';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إدخال بيانات الحساب التجريبي بنجاح ⚡'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentDanger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo & Heading
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'تاسكاتي • Taskaty',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'نظّم أهدافك، تابع إنجازك، وضاعف إنتاجيتك ✨',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Segmented Toggle (تسجيل الدخول / إنشاء حساب)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF132A32) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1F4450) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isLogin = true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isLogin ? AppTheme.primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _isLogin
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'تسجيل الدخول 🔑',
                                  style: TextStyle(
                                    fontWeight: _isLogin ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                    color: _isLogin
                                        ? Colors.white
                                        : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isLogin = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isLogin ? AppTheme.primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !_isLogin
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primaryColor.withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'إنشاء حساب 📝',
                                  style: TextStyle(
                                    fontWeight: !_isLogin ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                    color: !_isLogin
                                        ? Colors.white
                                        : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Inputs Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF132A32) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1F4450) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Name field (Only in Register mode)
                          if (!_isLogin) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'الاسم الكامل *',
                                hintText: 'مثال: أحمد محمد',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (val) {
                                if (!_isLogin) {
                                  final trimmed = val?.trim() ?? '';
                                  if (trimmed.isEmpty) return 'يرجى كتابة الاسم';
                                  if (trimmed.length < 2 || trimmed.length > 60) {
                                    return 'الاسم يجب أن يكون بين حرفين و 60 حرفاً';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني *',
                              hintText: 'name@example.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (val) {
                              final trimmed = val?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return 'يرجى إدخال البريد الإلكتروني';
                              }
                              if (!AuthService.emailRegex.hasMatch(trimmed)) {
                                return 'صيغة البريد الإلكتروني غير صحيحة';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور *',
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (val) {
                              final trimmed = val?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return 'يرجى إدخال كلمة المرور';
                              }
                              if (trimmed.length < 6) {
                                return 'كلمة المرور لا تقل عن 6 أحرف';
                              }
                              if (trimmed.length > 128) {
                                return 'كلمة المرور طويلة جداً (الحد الأقصى 128)';
                              }
                              return null;
                            },
                          ),

                          // Confirm Password field (Only in Register mode)
                          if (!_isLogin) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                labelText: 'تأكيد كلمة المرور *',
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_reset),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscureConfirm = !_obscureConfirm);
                                  },
                                ),
                              ),
                              validator: (val) {
                                if (!_isLogin) {
                                  final trimmed = val?.trim() ?? '';
                                  if (trimmed.isEmpty) {
                                    return 'يرجى تأكيد كلمة المرور';
                                  }
                                  if (trimmed != _passwordController.text.trim()) {
                                    return 'كلمتا المرور غير متطابقتين';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Submit Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    _isLogin ? 'تسجيل الدخول 🚀' : 'إنشاء حساب جديد ✨',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quick Demo / Guest Options
                    if (_isLogin)
                      TextButton.icon(
                        onPressed: _fillDemoAccount,
                        icon: const Icon(Icons.flash_on_rounded, size: 16),
                        label: const Text('استخدام الحساب التجريبي للتجربة السريعة'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Continue as Guest Button
                    OutlinedButton.icon(
                      onPressed: () => widget.authService.loginAsGuest(),
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: const Text('المتابعة كضيف بدون تسجيل 👤'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
