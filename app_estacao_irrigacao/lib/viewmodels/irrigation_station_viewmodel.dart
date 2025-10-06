import 'package:app_estacao_irrigacao/models/irrigation_station.dart';
import 'package:app_estacao_irrigacao/models/sensor_data.dart';
import 'package:app_estacao_irrigacao/models/data.dart';
import 'package:app_estacao_irrigacao/services/mqtt_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class IrrigationStationViewModel extends ChangeNotifier {
  final MqttService _mqttService;
  final IrrigationStation _station;
  final String _userId;
  
  SensorData? _currentSensorData;
  StreamSubscription<SensorData>? _sensorSubscription;
  List<Data> _historicalData = [];
  bool _disposed = false;
  bool _loadingHistoricalData = false;
  DateTime _selectedDate = DateTime.now();

  IrrigationStationViewModel(this._mqttService, this._station, this._userId) {
    _listenToSensorData();
    _loadHistoricalData();
  }

  @override
  void dispose() {
    _disposed = true;
    _sensorSubscription?.cancel();
    super.dispose();
  }

  void _listenToSensorData() {
    _sensorSubscription?.cancel();
    _sensorSubscription = _mqttService.sensorDataStream.listen(_onSensorDataReceived);
  }

  void _onSensorDataReceived(SensorData sensorData) {
    if (!_disposed && sensorData.stationId == _station.uid) {
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

  // Getters para expor os dados necessários para a View
  SensorData? get currentSensorData => _currentSensorData;
  
  bool get isMqttConnected => _mqttService.isStationConnected(_station.uid);
  
  bool get hasData => _currentSensorData != null;
  
  String get stationName => _station.name;

  List<Data> get historicalData => _historicalData;
  
  bool get isLoadingHistoricalData => _loadingHistoricalData;

  DateTime get selectedDate => _selectedDate;

  bool get isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
           _selectedDate.month == now.month &&
           _selectedDate.day == now.day;
  }

  // Lógica de irrigação
  Future<bool> startIrrigation(String ml) async {
    if (!_mqttService.isStationConnected(_station.uid)) {
      debugPrint('MQTT não conectado para irrigação');
      return false;
    }

    try {
      final mlValue = double.tryParse(ml);
      if (mlValue == null || mlValue <= 0) {
        debugPrint('Valor de irrigação inválido: $ml');
        return false;
      }

      // Enviar comando de irrigação via MQTT para esta estação específica
      final success = await _mqttService.publishIrrigationCommandToStation(_station.uid, 'Irrigar:$ml');
      
      if (success) {
        debugPrint('Comando de irrigação enviado para estação: ${_station.name}');
        
        // Salvar registro de irrigação no Firestore
        await _saveIrrigationRecord(mlValue);
        
        return true;
      } else {
        debugPrint('Falha ao enviar comando de irrigação');
        return false;
      }
    } catch (e) {
      debugPrint('Erro ao iniciar irrigação: $e');
      return false;
    }
  }

  // Salvar registro de irrigação no Firestore
  Future<void> _saveIrrigationRecord(double millimeters) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Criar uma referência do documento para obter um UID próprio
      final docRef = firestore
          .collection('users')
          .doc(_userId)
          .collection('irrigation_stations')
          .doc(_station.uid)
          .collection('data')
          .doc();
      
      final irrigationData = Data(
        uid: docRef.id,
        date: DateTime.now(),
        irrigatedMillimeters: millimeters,
        airHumidity: _currentSensorData?.humidity,
        soilHumidity: _currentSensorData?.soilMoisture,
        temperature: _currentSensorData?.temperature,
      );

      await docRef.set(irrigationData.toMap());

      debugPrint('Registro de irrigação salvo no Firestore: ${millimeters}ml');
      
      await _loadHistoricalData();
    } catch (e) {
      debugPrint('Erro ao salvar registro de irrigação: $e');
    }
  }

  // Carregar dados históricos do Firestore
  Future<void> _loadHistoricalData() async {
    if (_disposed) return;
    
    try {
      _loadingHistoricalData = true;
      notifyListeners();

      final firestore = FirebaseFirestore.instance;
      
      // Buscar dados da data selecionada
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final querySnapshot = await firestore
          .collection('users')
          .doc(_userId)
          .collection('irrigation_stations')
          .doc(_station.uid)
          .collection('data')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: endOfDay)
          .orderBy('date', descending: false)
          .get();

      _historicalData = querySnapshot.docs
          .map((doc) => Data.fromMap(doc.data()))
          .toList();

      final dateText = isToday ? 'hoje' : '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
      debugPrint('Carregados ${_historicalData.length} registros de $dateText');
    } catch (e) {
      debugPrint('Erro ao carregar dados históricos: $e');
      _historicalData = [];
    } finally {
      _loadingHistoricalData = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Método público para recarregar dados
  Future<void> refreshHistoricalData() async {
    await _loadHistoricalData();
  }

  // Métodos para navegação de datas
  Future<void> changeDate(DateTime newDate) async {
    _selectedDate = newDate;
    await _loadHistoricalData();
  }

  Future<void> goToPreviousDay() async {
    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    await _loadHistoricalData();
  }

  Future<void> goToNextDay() async {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    final now = DateTime.now();
    
    // Não permitir ir para o futuro
    if (tomorrow.isBefore(DateTime(now.year, now.month, now.day + 1))) {
      _selectedDate = tomorrow;
      await _loadHistoricalData();
    }
  }

  Future<void> goToToday() async {
    _selectedDate = DateTime.now();
    await _loadHistoricalData();
  }

  // Método para conectar especificamente a esta estação
  Future<bool> connectToThisStation(String emailMqtt, String passwordMqtt) async {
    try {
      return await _mqttService.connectToStation(
        _station.uid,
        emailMqtt,
        passwordMqtt,
        _station.urlMqtt,
      );
    } catch (e) {
      debugPrint('Erro ao conectar à estação ${_station.name}: $e');
      return false;
    }
  }
}