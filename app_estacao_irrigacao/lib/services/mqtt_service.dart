import 'dart:async';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:app_estacao_irrigacao/models/sensor_data.dart';

class MqttService {
  final Map<String, MqttServerClient> _clients = {};
  final Map<String, Timer> _readSensorTimers = {};
  final Map<String, String> _stationBrokers = {};
  
  String? _lastError;
  
  final StreamController<SensorData> _sensorDataController = StreamController<SensorData>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  bool get isConnected => _clients.isNotEmpty && _clients.values.any((client) => 
    client.connectionStatus?.state == MqttConnectionState.connected);
  String? get lastError => _lastError;
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool isStationConnected(String stationId) {
    final client = _clients[stationId];
    return client != null && client.connectionStatus?.state == MqttConnectionState.connected;
  }

  Future<bool> connectToStation(String stationId, String email, String password, String brokerUrl) async {
    try {
      _lastError = null;
      
      if (brokerUrl.isEmpty || email.isEmpty || password.isEmpty) {
        throw Exception('Parâmetros de conexão inválidos');
      }
      
      if (_clients.containsKey(stationId)) {
        await disconnectStation(stationId);
      }
      
      final clientId = 'app_irrigacao_${stationId}_${Random().nextInt(10000)}';
      final client = MqttServerClient(brokerUrl, clientId);
      
      client.port = 8883;
      client.secure = true;
      client.keepAlivePeriod = 60;
      client.connectTimeoutPeriod = 30000;
      client.autoReconnect = false;
      client.resubscribeOnAutoReconnect = false;
      client.logging(on: false);
      
      client.onConnected = () => _onStationConnected(stationId);
      client.onDisconnected = () => _onStationDisconnected(stationId);
      
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .withWillTopic('lwt')
          .withWillMessage('Station $stationId disconnected')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      
      connMessage.authenticateAs(email, password);
      client.connectionMessage = connMessage;
      
      await client.connect();
      
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        _clients[stationId] = client;
        _stationBrokers[stationId] = brokerUrl;
        
        await _setupStationSubscriptions(stationId, client);
        
        _connectionController.add(true);
        
        return true;
      } else {
        _lastError = 'Falha na conexão da estação $stationId';
        return false;
      }
      
    } catch (e) {
      _lastError = 'Erro ao conectar estação $stationId: $e';
      return false;
    }
  }

  Future<Map<String, bool>> connectToMultipleStations(
    String email, 
    String password, 
    Map<String, String> stationBrokers
  ) async {
    final results = <String, bool>{};
    
    final futures = stationBrokers.entries.map((entry) async {
      final stationId = entry.key;
      final brokerUrl = entry.value;
      
      final success = await connectToStation(stationId, email, password, brokerUrl);
      results[stationId] = success;
      
      return success;
    });
    
    await Future.wait(futures);
    
    return results;
  }

  Future<bool> connectToMqtt(String email, String password, String stationMqttUrl, {String? stationId, List<String>? stationIds}) async {
    final id = stationId ?? email.split('@').first;
    return await connectToStation(id, email, password, stationMqttUrl);
  }

  void _onStationConnected(String stationId) {
    _connectionController.add(true);
  }

  void _onStationDisconnected(String stationId) {
    _clients.remove(stationId);
    _stationBrokers.remove(stationId);
    _readSensorTimers[stationId]?.cancel();
    _readSensorTimers.remove(stationId);
    
    if (_clients.isEmpty) {
      _connectionController.add(false);
    }
  }

  Future<void> _setupStationSubscriptions(String stationId, MqttServerClient client) async {
    try {
      final topics = [
        'esp32/umidade',
        'esp32/temperatura', 
        'esp32/umidade-solo',
      ];
      
      for (String topic in topics) {
        client.subscribe(topic, MqttQos.atLeastOnce);
      }
      
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        for (var message in messages) {
          final topic = message.topic;
          final payload = MqttPublishPayload.bytesToStringAsString(
            (message.payload as MqttPublishMessage).payload.message
          );
          
          _processSensorMessage(stationId, topic, payload);
        }
      });
      
      await _testStationCommunication(stationId, client);
      
      _startReadSensorTimer(stationId, client);
      
    } catch (e) {
      // Erro ao configurar subscrições
    }
  }

  void _processSensorMessage(String stationId, String topic, String payload) {
    try {
      if (topic.startsWith('teste/')) {
        return;
      }
      
      final value = double.tryParse(payload.trim());
      if (value == null) {
        return;
      }
      
      String sensorType = '';
      
      if (topic.contains('umidade-solo')) {
        sensorType = 'umidade-solo';
      } else if (topic.contains('umidade')) {
        sensorType = 'umidade';  
      } else if (topic.contains('temperatura')) {
        sensorType = 'temperatura';
      }
      
      if (topic.startsWith('esp32/') && sensorType.isNotEmpty) {
        SensorData sensorData;
        
        switch (sensorType) {
          case 'umidade':
            sensorData = SensorData(
              stationId: stationId,
              humidity: value,
            );
            break;
          case 'temperatura':
            sensorData = SensorData(
              stationId: stationId,
              temperature: value,
            );
            break;
          case 'umidade-solo':
            sensorData = SensorData(
              stationId: stationId,
              soilMoisture: value,
            );
            break;
          default:
            return;
        }
        
        _sensorDataController.add(sensorData);
      }
      
    } catch (e) {
      // Erro ao processar mensagem
    }
  }

  Future<void> _testStationCommunication(String stationId, MqttServerClient client) async {
    try {
      const testTopic = 'teste/app_flutter';
      final testMessage = 'Hello from Flutter App to $stationId!';
      
      final builder = MqttClientPayloadBuilder();
      builder.addString(testMessage);
      
      client.publishMessage(testTopic, MqttQos.atLeastOnce, builder.payload!);
      client.subscribe(testTopic, MqttQos.atLeastOnce);
      
    } catch (e) {
      // Erro no teste de comunicação
    }
  }

  void _startReadSensorTimer(String stationId, MqttServerClient client) {
    _readSensorTimers[stationId]?.cancel();
    
    _readSensorTimers[stationId] = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!isStationConnected(stationId)) {
        timer.cancel();
        _readSensorTimers.remove(stationId);
        return;
      }
      
      await _requestSensorData(stationId, client);
    });
    
    _requestSensorData(stationId, client);
  }

  Future<void> _requestSensorData(String stationId, MqttServerClient client) async {
    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString('Ler sensor');
      
      const topic = 'esp32/';
      
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      
    } catch (e) {
      // Erro ao solicitar dados
    }
  }

  Future<bool> publishToStation(String stationId, String topic, String message) async {
    final client = _clients[stationId];
    if (client == null || !isStationConnected(stationId)) {
      return false;
    }
    
    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> publishIrrigationCommand(String command) async {
    if (_clients.isEmpty) {
      return false;
    }
    
    if (_clients.length == 1) {
      final stationId = _clients.keys.first;
      return await publishToStation(stationId, 'esp32/irrigacao', command);
    }
    
    bool anySuccess = false;
    for (String stationId in _clients.keys) {
      final success = await publishToStation(stationId, 'esp32/', command);
      if (success) anySuccess = true;
    }
    
    return anySuccess;
  }

  Future<bool> publishIrrigationCommandToStation(String stationId, String command) async {
    return await publishToStation(stationId, 'esp32/', command);
  }

  Future<bool> requestSensorReading(String stationId) async {
    final client = _clients[stationId];
    if (client == null || !isStationConnected(stationId)) {
      return false;
    }
    
    await _requestSensorData(stationId, client);
    return true;
  }

  Future<void> requestAllSensorsReading() async {
    for (var entry in _clients.entries) {
      final stationId = entry.key;
      final client = entry.value;
      
      if (isStationConnected(stationId)) {
        await _requestSensorData(stationId, client);
      }
    }
  }

  Future<void> disconnectStation(String stationId) async {
    try {
      _readSensorTimers[stationId]?.cancel();
      _readSensorTimers.remove(stationId);
      
      final client = _clients[stationId];
      if (client != null) {
        client.disconnect();
        _clients.remove(stationId);
      }
      
      _stationBrokers.remove(stationId);
      
      if (_clients.isEmpty) {
        _connectionController.add(false);
      }
      
    } catch (e) {
      // Erro ao desconectar estação
    }
  }

  Future<void> disconnect() async {
    try {
      for (var timer in _readSensorTimers.values) {
        timer.cancel();
      }
      _readSensorTimers.clear();
      
      for (var client in _clients.values) {
        client.disconnect();
      }
      
      _clients.clear();
      _stationBrokers.clear();
      _lastError = null;
      _connectionController.add(false);
      
    } catch (e) {
      _lastError = 'Erro ao desconectar: $e';
    }
  }

  Future<bool> checkConnection() async {
    return _clients.values.any((client) => 
      client.connectionStatus?.state == MqttConnectionState.connected);
  }

  Map<String, bool> getAllStationsStatus() {
    final status = <String, bool>{};
    for (var entry in _clients.entries) {
      status[entry.key] = entry.value.connectionStatus?.state == MqttConnectionState.connected;
    }
    return status;
  }

  void dispose() {
    for (var timer in _readSensorTimers.values) {
      timer.cancel();
    }
    
    for (var client in _clients.values) {
      client.disconnect();
    }
    
    _clients.clear();
    _readSensorTimers.clear();
    _stationBrokers.clear();
    
    _sensorDataController.close();
    _connectionController.close();
  }
}