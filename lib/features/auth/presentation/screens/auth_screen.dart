// lib/features/auth/presentation/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/color_scheme.dart';
import '../../../../core/theme/text_styles.dart';
import '../bloc/auth_bloc.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AuthView();
  }
}

class _AuthView extends StatefulWidget {
  const _AuthView();

  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitAuth(BuildContext context) {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    if (!_isLogin && username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    if (_isLogin) {
      context.read<AuthBloc>().add(
            AuthSignInWithEmailRequested(email: email, password: password),
          );
    } else {
      context.read<AuthBloc>().add(
            AuthSignUpWithEmailRequested(
              email: email,
              password: password,
              username: username,
            ),
          );
    }
  }

  void _resetPassword(BuildContext context) {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email to reset password')),
      );
      return;
    }
    context.read<AuthBloc>().add(AuthPasswordResetRequested(email));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          curr is AuthSuccess ||
          curr is AuthPasswordResetSent ||
          curr is AuthFailure,
      listener: (context, state) {
        if (state is AuthSuccess) {
          context.go('/session');
        }
        if (state is AuthPasswordResetSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset link sent to your email.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: ScreenSageColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),

                      // ── Header ────────────────────────────────────
                      Text(
                        'Welcome to',
                        style: ScreenSageTextStyles.bodyLarge.copyWith(
                          color: ScreenSageColors.textSecondary,
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 4),

                      Text(
                        'ScreenSage',
                        style: ScreenSageTextStyles.displayMedium
                            .copyWith(color: ScreenSageColors.accent),
                      ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05),

                      const SizedBox(height: 8),

                      Text(
                        _isLogin
                            ? 'Sign in to continue your journey.'
                            : '7 days free, then \$4.99/month.',
                        style: ScreenSageTextStyles.bodyMedium,
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 32),

                      // ── Username (Sign Up only) ───────────────────
                      if (!_isLogin) ...[
                        TextField(
                          controller: _usernameController,
                          enabled: !isLoading,
                          style: ScreenSageTextStyles.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'Username',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: ScreenSageColors.textTertiary,
                            ),
                          ),
                        ).animate().fadeIn(delay: 350.ms),
                        const SizedBox(height: 16),
                      ],

                      // ── Email ──────────────────────────────────────
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: ScreenSageTextStyles.bodyLarge,
                        enabled: !isLoading,
                        decoration: const InputDecoration(
                          hintText: 'your@email.com',
                          prefixIcon: Icon(Icons.email_outlined,
                              color: ScreenSageColors.textTertiary),
                        ),
                      ).animate().fadeIn(delay: 400.ms),

                      const SizedBox(height: 16),

                      // ── Password ────────────────────────────────────
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: ScreenSageTextStyles.bodyLarge,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: ScreenSageColors.textTertiary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: ScreenSageColors.textTertiary,
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                      ).animate().fadeIn(delay: 500.ms),

                      // ── Forgot Password ────────────────────────────
                      if (_isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () => _resetPassword(context),
                            child: Text(
                              'Forgot Password?',
                              style: ScreenSageTextStyles.bodySmall
                                  .copyWith(color: ScreenSageColors.accent),
                            ),
                          ),
                        ).animate().fadeIn(delay: 550.ms)
                      else
                        const SizedBox(height: 24),

                      // ── Main Action Button ─────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              isLoading ? null : () => _submitAuth(context),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_isLogin ? 'Sign In' : 'Create Account'),
                        ),
                      ).animate().fadeIn(delay: 600.ms),

                      // ── Toggle Login / Sign Up ─────────────────────
                      Center(
                        child: TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                  });
                                },
                          child: Text(
                            _isLogin
                                ? "Don't have an account? Sign Up"
                                : "Already have an account? Sign In",
                            style: ScreenSageTextStyles.bodyMedium,
                          ),
                        ),
                      ).animate().fadeIn(delay: 650.ms),

                      const SizedBox(height: 16),

                      // ── OR Divider ──────────────────────────────────
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR',
                                style: ScreenSageTextStyles.bodySmall),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ).animate().fadeIn(delay: 700.ms),

                      const SizedBox(height: 24),

                      // ── Social Logins ───────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () => context
                                      .read<AuthBloc>()
                                      .add(AuthSignInWithGoogleRequested()),
                              icon: const Icon(Icons.g_mobiledata, size: 32),
                              label: const Text('Google'),
                              style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () => context
                                      .read<AuthBloc>()
                                      .add(AuthSignInWithAppleRequested()),
                              icon: const Icon(Icons.apple, size: 28),
                              label: const Text('Apple'),
                              style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16)),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 800.ms),

                      const Spacer(),

                      // ── Legal ────────────────────────────────────────
                      Center(
                        child: Text(
                          'By continuing you agree to our Terms & Privacy Policy.',
                          style: ScreenSageTextStyles.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ).animate().fadeIn(delay: 900.ms),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
