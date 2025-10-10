import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_estacao_irrigacao/models/user.dart';
import 'package:app_estacao_irrigacao/services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  LoginViewModel(this._authService);

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Fazer login
  Future<Client?> signIn(String email, String password) async {
    if (!_validateInputs(email, password)) return null;

    try {
      _setLoading(true);
      _clearError();

      UserCredential userCredential = await _authService.signInWithEmailAndPassword(email, password);
      
      // Buscar dados do usuário no Firestore
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();
      
      if (doc.exists) {
        return Client.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        _setError("Dados do usuário não encontrados");
        return null;
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      return null;
    } catch (e) {
      _setError("Erro inesperado: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Criar conta
  Future<Client?> signUp(String email, String password) async {
    if (!_validateInputs(email, password)) return null;

    try {
      _setLoading(true);
      _clearError();

      UserCredential userCredential = await _authService.createUserWithEmailAndPassword(email, password);
      
      // Criar dados do usuário no Firestore
      Client newClient = Client(
        uid: userCredential.user?.uid ?? '',
        email: email,
      );

      await _firestore.collection('users').doc(userCredential.user?.uid).set(newClient.toMap());
      
      return newClient;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      return null;
    } catch (e) {
      _setError("Erro ao criar conta: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Validar entradas
  bool _validateInputs(String email, String password) {
    if (email.isEmpty) {
      _setError("Por favor, digite o email");
      return false;
    }
    
    if (!email.contains('@')) {
      _setError("Por favor, digite um email válido");
      return false;
    }
    
    if (password.isEmpty) {
      _setError("Por favor, digite a senha");
      return false;
    }
    
    if (password.length < 6) {
      _setError("A senha deve ter pelo menos 6 caracteres");
      return false;
    }
    
    return true;
  }

  // Tratar exceções de autenticação
  void _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        _setError('Usuário não encontrado. Verifique seu email.');
        break;
      case 'wrong-password':
        _setError('Senha incorreta. Tente novamente.');
        break;
      case 'invalid-credential':
        _setError('Email ou senha incorretos.');
        break;
      case 'too-many-requests':
        _setError('Muitas tentativas. Tente novamente mais tarde.');
        break;
      case 'user-disabled':
        _setError('Esta conta foi desabilitada.');
        break;
      case 'email-already-in-use':
        _setError('Este email já está em uso');
        break;
      case 'weak-password':
        _setError('A senha é muito fraca. Use pelo menos 6 caracteres.');
        break;
      case 'invalid-email':
        _setError('Email inválido');
        break;
      case 'network-request-failed':
        _setError('Erro de conexão. Verifique sua internet.');
        break;
      default:
        _setError('Erro de autenticação. Tente novamente.');
    }
  }

  // Métodos privados para gerenciar estado
  void _setLoading(bool loading) {
    if (_disposed) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    if (_disposed) return;
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    if (_disposed) return;
    _errorMessage = null;
    notifyListeners();
  }
}
