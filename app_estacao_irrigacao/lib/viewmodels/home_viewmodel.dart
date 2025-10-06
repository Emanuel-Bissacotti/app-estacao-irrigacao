import 'package:app_estacao_irrigacao/pages/irrigation_station_page.dart';
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
  bool _isConnecting = false;
  DateTime? _lastConnectionAttempt;
  
  final Map<String, SensorData> _stationsData = {};
  final Set<String> _connectedStations = {};
  StreamSubscription<SensorData>? _sensorSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  HomeViewModel(this._client, this._authService, this._mqttService) {
    _connectionSubscription = _mqttService.connectionStream.listen(_onMqttConnectionChanged);
  }

  Client get client => _client;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isMqttConnected => _mqttService.isConnected;
  
  bool get isMqttConfigured {
    final emailMqtt = _client.emailMqtt;
    final passwordMqtt = _client.passwordMqtt;
    return emailMqtt != null && emailMqtt.isNotEmpty && 
           passwordMqtt != null && passwordMqtt.isNotEmpty;
  }
  
  SensorData? get currentSensorData {
    if (_stationsData.isNotEmpty) {
      return _stationsData.values.first;
    }
    return null;
  }

  SensorData? getSensorDataForStation(String stationId) {
    return _stationsData[stationId];
  }
  
  bool isStationConnected(String stationId) {
    return _mqttService.isStationConnected(stationId);
  }

  @override
  void dispose() {
    _disposed = true;
    _sensorSubscription?.cancel();
    _connectionSubscription?.cancel();
    _mqttService.dispose();
    super.dispose();
  }

  void _onMqttConnectionChanged(bool isConnected) {
    if (!_disposed) {
      if (!isConnected) {
        _connectedStations.clear();
        _stationsData.clear();
      }
      notifyListeners();
    }
  }

  Future<void> connectToAllStations(List<IrrigationStation> stations) async {    
    if (!isMqttConfigured || stations.isEmpty) {
      return;
    }
    
    if (_mqttService.isConnected) {
      _connectedStations.clear();
      for (var station in stations) {
        _connectedStations.add(station.uid);
      }
      notifyListeners();
      return;
    }

    if (_isConnecting) {
      return;
    }

    if (_lastConnectionAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastConnectionAttempt!);
      if (timeSinceLastAttempt.inSeconds < 10) {
        return;
      }
    }

    final emailMqtt = _client.emailMqtt;
    final passwordMqtt = _client.passwordMqtt;
    
    if (emailMqtt == null || passwordMqtt == null) {
      _setError('Credenciais MQTT não configuradas');
      return;
    }

    try {
      _isConnecting = true;
      _setLoading(true);
      _clearError();
      _lastConnectionAttempt = DateTime.now();

      Map<String, String> stationBrokers = {};
      for (var station in stations) {
        stationBrokers[station.uid] = station.urlMqtt;
      }
      
      final results = await _mqttService.connectToMultipleStations(
        emailMqtt,
        passwordMqtt,
        stationBrokers,
      );
      
      bool hasAnyConnection = results.values.any((success) => success);

      if (hasAnyConnection) {
        _connectedStations.clear();
        for (var entry in results.entries) {
          if (entry.value) {
            _connectedStations.add(entry.key);
          }
        }
        
        _sensorSubscription?.cancel();
        _sensorSubscription = _mqttService.sensorDataStream.listen(_onSensorDataReceived);
        
        final connectedCount = _connectedStations.length;
        debugPrint('🔗 Conectado a $connectedCount/${stations.length} estação(ões): ${_connectedStations.join(", ")}');
        
        if (!_disposed) notifyListeners();
      } else {
        _setError(_mqttService.lastError ?? 'Erro ao conectar com as estações');
      }
    } catch (e) {
      _setError('Erro ao conectar: $e');
      debugPrint('❌ Erro na conexão: $e');
    } finally {
      _isConnecting = false;
      _setLoading(false);
    }
  }

  Future<bool> connectToStation(IrrigationStation station) async {
    await connectToAllStations([station]);
    return _connectedStations.contains(station.uid);
  }

  void _onSensorDataReceived(SensorData sensorData) {
    if (!_disposed) {
      String stationId = sensorData.stationId;
      
      if (!_connectedStations.contains(stationId) && _connectedStations.isNotEmpty) {
        stationId = _connectedStations.first;
      }
      
      debugPrint('📡 Dados recebidos para estação: $stationId - Temp: ${sensorData.temperature}, Umidade: ${sensorData.humidity}, Solo: ${sensorData.soilMoisture}');
      
      if (_stationsData.containsKey(stationId)) {
        final currentData = _stationsData[stationId]!;
        _stationsData[stationId] = currentData.copyWith(
          temperature: sensorData.temperature ?? currentData.temperature,
          humidity: sensorData.humidity ?? currentData.humidity,
          soilMoisture: sensorData.soilMoisture ?? currentData.soilMoisture,
          timestamp: sensorData.timestamp,
        );
      } else {
        _stationsData[stationId] = sensorData.copyWith(stationId: stationId);
      }
      
      debugPrint('💾 Total de estações com dados: ${_stationsData.length}');
      notifyListeners();
    }
  }

  Future<void> disconnectFromStation() async {
    try {
      await _mqttService.disconnect();
      _connectedStations.clear();
      _stationsData.clear();
      _sensorSubscription?.cancel();
      
      if (!_disposed) notifyListeners();
    } catch (e) {
      _setError('Erro ao desconectar: $e');
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      
      if (isMqttConnected) {
        await _mqttService.disconnect();
        _connectedStations.clear();
        _stationsData.clear();
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

      final firestore = FirebaseFirestore.instance;
      
      // Criar uma referência do documento para obter o UID
      final docRef = firestore
          .collection('users')
          .doc(_client.uid)
          .collection('irrigation_stations')
          .doc();

      final irrigationStation = IrrigationStation(
        uid: docRef.id, // Usar o UID do documento
        name: name,
        urlMqtt: urlMqtt,
        percentForIrrigation: percentForIrrigation,
        millimetersWater: millimetersWater,
      );

      // Usar set() em vez de add() para garantir que o UID seja o mesmo
      await docRef.set(irrigationStation.toMap());

      // StreamProvider irá detectar automaticamente a nova estação
      return true;
    } catch (e) {
      _setError('Erro ao adicionar estação de irrigação: $e');
      return false;
    } finally {
      _setLoading(false);
    }
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

  Future<void> requestSensorReading({String? stationId}) async {
    if (stationId != null) {
      await _mqttService.requestSensorReading(stationId);
    } else {
      await _mqttService.requestAllSensorsReading();
    }
  }

  void stationControllerPage(BuildContext context, IrrigationStation irrigationStation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IrrigationStationPage(
          mqttService: _mqttService,
          irrigationStation: irrigationStation,
          userId: _client.uid,
        ),
      ),
    );
  }
}
