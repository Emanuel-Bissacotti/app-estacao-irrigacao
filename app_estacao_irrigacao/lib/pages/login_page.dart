import 'package:app_estacao_irrigacao/viewmodels/login_viewmodel.dart';
import 'package:app_estacao_irrigacao/services/auth_service.dart';
import 'package:app_estacao_irrigacao/widgets/login/app_logo.dart';
import 'package:app_estacao_irrigacao/widgets/login/login_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginViewModel(AuthService()),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF8F9FA),
                Color(0xFFE9ECEF),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Consumer<LoginViewModel>(
                  builder: (context, viewModel, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppLogo(),
                        const SizedBox(height: 48),
                        LoginCard(
                          onLogin: (email, password) => viewModel.signIn(email, password),
                          onSignUp: (email, password) => viewModel.signUp(email, password),
                          isLoading: viewModel.isLoading,
                          errorMessage: viewModel.errorMessage,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
