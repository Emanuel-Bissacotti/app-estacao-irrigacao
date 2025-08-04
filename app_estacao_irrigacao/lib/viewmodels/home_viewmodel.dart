import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_estacao_irrigacao/models/user.dart';
import 'package:app_estacao_irrigacao/models/irrigation_station.dart';
import 'package:app_estacao_irrigacao/models/sensor_data.dart';
import 'package:app_estacao_irrigacao/services/auth_service.dart';
import 'package:app_estacao_irrigacao/services/mqtt_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class HomeViewModel extends ChangeNotifier {
  final AuthService _authService;
  final MqttService _mqttService;
  
  Client _client;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;
  bool _isConnecting = false; // Prevenir conexões simultâneas
  DateTime? _lastConnectionAttempt; // Cooldown entre tentativas
  
  // Dados dos sensores da estação ativa
  IrrigationStation? _activeStation;
  SensorData? _currentSensorData;
  StreamSubscription<SensorData>? _sensorSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  HomeViewModel(this._client, this._authService, this._mqttService) {
    // Escutar mudanças na conexão MQTT
    _connectionSubscription = _mqttService.connectionStream.listen(_onMqttConnectionChanged);
  }

  // Getters
  Client get client => _client;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  IrrigationStation? get activeStation => _activeStation;
  SensorData? get currentSensorData => _currentSensorData;
  bool get isMqttConnected => _mqttService.isConnected;
  
  bool get isMqttConfigured {
    final emailMqtt = _client.emailMqtt;
    final passwordMqtt = _client.passwordMqtt;
    return emailMqtt != null && emailMqtt.isNotEmpty && 
           passwordMqtt != null && passwordMqtt.isNotEmpty;
  }

  @override
  void dispose() {
    _disposed = true;
    _sensorSubscription?.cancel();
    _connectionSubscription?.cancel();
    _mqttService.dispose();
    super.dispose();
  }

  // Callback para mudanças na conexão MQTT
  void _onMqttConnectionChanged(bool isConnected) {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // Conectar MQTT para uma estação específica
  Future<bool> connectToStation(IrrigationStation station, {bool isManualConnection = false}) async {
    if (!isMqttConfigured) {
      _setError('Configure o MQTT primeiro');
      return false;
    }

    // Prevenir conexões simultâneas
    if (_isConnecting) {
      return false;
    }

    final emailMqtt = _client.emailMqtt;
    final passwordMqtt = _client.passwordMqtt;
    
    if (emailMqtt == null || passwordMqtt == null) {
      _setError('Credenciais MQTT não configuradas');
      return false;
    }

    try {
      _isConnecting = true;
      _setLoading(true);
      _clearError();

      // Se é conexão manual, atualizar o timestamp para evitar conflitos com auto-conexão
      if (isManualConnection) {
        _lastConnectionAttempt = DateTime.now();
      }

      bool success = await _mqttService.connectToMqtt(
        emailMqtt,
        passwordMqtt,
        station.urlMqtt,
      );

      if (success) {
        _activeStation = station;
        _currentSensorData = null;
        
        // Escutar dados dos sensores
        _sensorSubscription?.cancel();
        _sensorSubscription = _mqttService.sensorDataStream.listen(_onSensorDataReceived);
        
        if (!_disposed) notifyListeners();
        return true;
      } else {
        _setError(_mqttService.lastError ?? 'Erro ao conectar com a estação');
        return false;
      }
    } catch (e) {
      _setError('Erro ao conectar: $e');
      return false;
    } finally {
      _isConnecting = false;
      _setLoading(false);
    }
  }

  void _onSensorDataReceived(SensorData sensorData) {
    if (!_disposed) {
      if (_currentSensorData == null) {
        _currentSensorData = sensorData;
      } else {
        final currentData = _currentSensorData!;
        _currentSensorData = currentData.copyWith(
          temperature: sensorData.temperature ?? currentData.temperature,
          humidity: sensorData.humidity ?? currentData.humidity,
          soilMoisture: sensorData.soilMoisture ?? currentData.soilMoisture,
          timestamp: sensorData.timestamp,
        );
      }
      
      notifyListeners();
    }
  }

  Future<void> disconnectFromStation() async {
    try {
      await _mqttService.disconnect();
      _activeStation = null;
      _currentSensorData = null;
      _sensorSubscription?.cancel();
      
      if (!_disposed) notifyListeners();
    } catch (e) {
      _setError('Erro ao desconectar: $e');
    }
  }

  // TODO: Isso sera em outra tela
  Future<bool> sendIrrigationCommand(String command) async {
    if (!_mqttService.isConnected) {
      _setError('MQTT não conectado');
      return false;
    }

    try {
      return await _mqttService.publishIrrigationCommand(command);
    } catch (e) {
      _setError('Erro ao enviar comando: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      
      // Desconectar do protocolo MQTT antes de sair
      if (isMqttConnected) {
        await _mqttService.disconnect();
        _activeStation = null;
        notifyListeners();
      }
      
      await _authService.signOut();
    } catch (e) {
      _setError('Erro ao fazer logout: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateIrrigationStation({
    required IrrigationStation station,
    required String name,
    required String urlMqtt,
    double percentForIrrigation = -1,
    double millimetersWater = -1,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final updatedStation = IrrigationStation(
        uid: station.uid,
        name: name,
        urlMqtt: urlMqtt,
        percentForIrrigation: percentForIrrigation,
        millimetersWater: millimetersWater,
      );

      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(_client.uid)
          .collection('irrigation_stations')
          .doc(station.uid)
          .set(updatedStation.toMap(), SetOptions(merge: true));

      return true;
    } catch (e) {
      _setError('Erro ao atualizar estação de irrigação: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addIrrigationStation({
    required String name,
    required String urlMqtt,
    double percentForIrrigation = -1,
    double millimetersWater = -1,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final irrigationStation = IrrigationStation(
        uid: '',
        name: name,
        urlMqtt: urlMqtt,
        percentForIrrigation: percentForIrrigation,
        millimetersWater: millimetersWater,
      );

      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(_client.uid)
          .collection('irrigation_stations')
          .add(irrigationStation.toMap());

      // StreamProvider irá detectar automaticamente a nova estação
      return true;
    } catch (e) {
      _setError('Erro ao adicionar estação de irrigação: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Conectar automaticamente à primeira estação quando estações estão disponíveis
  Future<void> connectToAllStations(List<IrrigationStation> stations) async {    
    if (!isMqttConfigured || stations.isEmpty) {
      return;
    }
    
    if (_mqttService.isConnected) {
      return;
    }

    if (_isConnecting) {
      return;
    }

    // Cooldown de 10 segundos entre tentativas automáticas (não se aplica à primeira tentativa)
    if (_lastConnectionAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastConnectionAttempt!);
      if (timeSinceLastAttempt.inSeconds < 10) {
        return;
      }
    }

    _lastConnectionAttempt = DateTime.now();
    final firstStation = stations.first;
    await connectToStation(firstStation);
  }
  
  Future<bool> updateMqttConfig(String emailMqtt, String passwordMqtt) async {
    try {
      _setLoading(true);
      _clearError();

      if (emailMqtt.trim().isEmpty) {
        _setError('Email MQTT é obrigatório');
        return false;
      }
      
      if (passwordMqtt.trim().isEmpty) {
        _setError('Senha MQTT é obrigatória');
        return false;
      }

      Client updatedClient = Client(
        uid: _client.uid,
        email: _client.email,
        emailMqtt: emailMqtt.trim(),
        passwordMqtt: passwordMqtt.trim(),
      );

      await _saveClientToFirestore(updatedClient);
      
      _client = updatedClient;
      
      if (!_disposed) notifyListeners();
      return true;
    } catch (e) {
      _setError('Erro ao configurar MQTT: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _saveClientToFirestore(Client client) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(client.uid).set(
      client.toMap(), 
      SetOptions(merge: true)
    );
  }

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

  void updateClient(Client newClient) {
    if (_disposed) return;
    _client = newClient;
    notifyListeners();
  }
}
