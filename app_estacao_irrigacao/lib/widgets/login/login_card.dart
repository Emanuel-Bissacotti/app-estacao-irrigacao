import 'package:flutter/material.dart';
import 'login_form.dart';
import '../common/or_divider.dart';
import '../common/secondary_button.dart';

class LoginCard extends StatefulWidget {
  final Function(String, String) onLogin;
  final Function(String, String) onSignUp;
  final bool isLoading;
  final String? errorMessage;

  const LoginCard({
    super.key,
    required this.onLogin,
    required this.onSignUp,
    required this.isLoading,
    this.errorMessage,
  });

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignUp() {
    if (_emailController.text.trim().isNotEmpty && _passwordController.text.isNotEmpty) {
      widget.onSignUp(_emailController.text.trim(), _passwordController.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha email e senha para criar conta'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          LoginForm(
            emailController: _emailController,
            passwordController: _passwordController,
            onLogin: widget.onLogin,
            isLoading: widget.isLoading,
            errorMessage: widget.errorMessage,
          ),
          const SizedBox(height: 24),
          const OrDivider(),
          const SizedBox(height: 24),
          SecondaryButton(
            onPressed: widget.isLoading ? null : _handleSignUp,
            text: 'Criar conta',
          ),
        ],
      ),
    );
  }
}
