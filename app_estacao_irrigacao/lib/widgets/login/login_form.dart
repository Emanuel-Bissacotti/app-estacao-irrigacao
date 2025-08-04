import 'package:flutter/material.dart';
import '../common/custom_text_field.dart';
import '../common/primary_button.dart';
import '../common/error_message.dart';

class LoginForm extends StatefulWidget {
  final TextEditingController? emailController;
  final TextEditingController? passwordController;
  final Function(String, String) onLogin;
  final bool isLoading;
  final String? errorMessage;

  const LoginForm({
    super.key,
    this.emailController,
    this.passwordController,
    required this.onLogin,
    required this.isLoading,
    this.errorMessage,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _emailController = widget.emailController ?? TextEditingController();
    _passwordController = widget.passwordController ?? TextEditingController();
  }

  @override
  void dispose() {
    // Só dispose se criamos os controllers internamente
    if (widget.emailController == null) _emailController.dispose();
    if (widget.passwordController == null) _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState?.validate() == true) {
      widget.onLogin(_emailController.text.trim(), _passwordController.text);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, insira seu email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Por favor, insira um email válido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, insira sua senha';
    }
    if (value.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          CustomTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'Digite seu email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _passwordController,
            label: 'Senha',
            hint: 'Digite sua senha',
            icon: Icons.lock_outlined,
            obscureText: true,
            validator: _validatePassword,
          ),
          const SizedBox(height: 24),
          ErrorMessage(errorMessage: widget.errorMessage),
          if (widget.errorMessage != null && widget.errorMessage?.isNotEmpty == true)
            const SizedBox(height: 16),
          PrimaryButton(
            onPressed: widget.isLoading ? null : _handleLogin,
            text: 'Entrar',
            isLoading: widget.isLoading,
          ),
        ],
      ),
    );
  }
}
