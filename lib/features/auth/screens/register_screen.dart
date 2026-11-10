import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import '../../../shared/providers/auth_provider.dart';
import '../widgets/gradient_button.dart';

/// Registration screen with role selection (Student / Faculty) — Neumorphic
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _schoolIdController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _selectedRole = AppConstants.roleStudent;
  String _selectedDepartment = AppConstants.departments.first;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _schoolIdController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        role: _selectedRole,
        department: _selectedDepartment,
        schoolId: _selectedRole == AppConstants.roleStudent
            ? _schoolIdController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (user != null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.accountAccess,
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Builds a neumorphic inset text field wrapper
  Widget _neumorphicField({required Widget child}) {
    return Container(
      decoration: AppTheme.neumorphicInsetDecoration(borderRadius: 14),
      child: child,
    );
  }

  InputDecoration _clearInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: AppTheme.textHint),
      suffixIcon: suffixIcon,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      fillColor: Colors.transparent,
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTheme.background,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 30),

                // ─── Back + Title ───
                _buildTopBar().animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 24),

                // ─── Role Selector (Neumorphic) ───
                _buildRoleSelector()
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, duration: 400.ms),

                const SizedBox(height: 20),

                Text(
                  _selectedRole == AppConstants.roleStudent
                      ? 'Registration links your account to this Android phone. '
                            'Replacing it requires approval from the project team.'
                      : 'Faculty accounts require verification by the project '
                            'team before they can manage attendance.',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),

                // ─── Registration Form (Neumorphic card) ───
                Container(
                      padding: const EdgeInsets.all(28),
                      decoration: AppTheme.neumorphicDecoration(
                        borderRadius: 24,
                        blurRadius: 14,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Account',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedRole == AppConstants.roleFaculty
                                  ? 'Faculty access requires project-team approval'
                                  : 'Register as Student',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Full Name
                            _neumorphicField(
                              child: TextFormField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                decoration: _clearInputDecoration(
                                  hintText: 'Full Name',
                                  prefixIcon: Icons.person_outline,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your full name';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Email
                            _neumorphicField(
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: _clearInputDecoration(
                                  hintText: 'Email address',
                                  prefixIcon: Icons.email_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Department Dropdown (neumorphic inset)
                            _neumorphicField(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedDepartment,
                                decoration: _clearInputDecoration(
                                  hintText: 'Department',
                                  prefixIcon: Icons.school_outlined,
                                ),
                                dropdownColor: AppTheme.background,
                                items: AppConstants.departments
                                    .map(
                                      (dept) => DropdownMenuItem(
                                        value: dept,
                                        child: Text(dept),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedDepartment = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (_selectedRole == AppConstants.roleStudent) ...[
                              _neumorphicField(
                                child: TextFormField(
                                  controller: _schoolIdController,
                                  textInputAction: TextInputAction.next,
                                  decoration: _clearInputDecoration(
                                    hintText: 'School Student ID (e.g. 2023-00123)',
                                    prefixIcon: Icons.badge_outlined,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your School Student ID';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Password
                            _neumorphicField(
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: _clearInputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppTheme.textHint,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Confirm Password
                            _neumorphicField(
                              child: TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleRegister(),
                                decoration: _clearInputDecoration(
                                  hintText: 'Confirm Password',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppTheme.textHint,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () =>
                                            _obscureConfirm = !_obscureConfirm,
                                      );
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Register button (neumorphic)
                            GradientButton(
                              text: 'Create Account',
                              isLoading: _isLoading,
                              onPressed: _isLoading ? null : _handleRegister,
                              icon: Icons.person_add_rounded,
                            ),
                          ],
                        ),
                      ),
                    )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.15, end: 0, duration: 500.ms),

                const SizedBox(height: 24),

                // ─── Login Link ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.inter(
                          color: AppTheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        // Neumorphic back button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: AppTheme.neumorphicDecoration(
              borderRadius: 12,
              blurRadius: 8,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const Spacer(),
        Text(
          AppConstants.appName,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 44), // Balance the back button
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: AppTheme.neumorphicInsetDecoration(borderRadius: 16),
      child: Row(
        children: [
          _buildRolePill(
            label: 'Student',
            icon: Icons.school_outlined,
            isSelected: _selectedRole == AppConstants.roleStudent,
            onTap: () =>
                setState(() => _selectedRole = AppConstants.roleStudent),
          ),
          _buildRolePill(
            label: 'Faculty',
            icon: Icons.person_outline,
            isSelected: _selectedRole == AppConstants.roleFaculty,
            onTap: () =>
                setState(() => _selectedRole = AppConstants.roleFaculty),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: isSelected
              ? AppTheme.neumorphicDecoration(
                  borderRadius: 12,
                  blurRadius: 6,
                  color: AppTheme.background,
                )
              : BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primary : AppTheme.textHint,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.primary : AppTheme.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
