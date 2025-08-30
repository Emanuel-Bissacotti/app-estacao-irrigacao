import 'dart:async';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:app_estacao_irrigacao/models/sensor_data.dart';

class MqttService {
  String _brokerHost = '';
  
  MqttServerClient? _client;
  Timer? _readSensorTimer;
  
  bool _isConnected = false;
  String? _lastError;
  
  final StreamController<SensorData> _sensorDataController = StreamController<SensorData>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  String? _currentStationId;

  Future<bool> connectToMqtt(String email, String password, String stationMqttUrl) async {
    try {
      _lastError = null;
      
      await disconnect();
      
      _brokerHost = stationMqttUrl;
      
      // Validar se a URL do broker não está vazia
      if (_brokerHost.isEmpty) {
        throw Exception('URL do broker MQTT não pode estar vazia');
      }
      
      // Validar se as credenciais não estão vazias
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email e senha MQTT são obrigatórios');
      }
      _currentStationId = email.split('@').first;
      
      final clientId = 'app_irrigacao_${Random().nextInt(10000)}';
      
      _client = MqttServerClient(_brokerHost, clientId);
      
      _client!.port = 8883;
      _client!.secure = true;
      _client!.keepAlivePeriod = 60;
      _client!.connectTimeoutPeriod = 30000; // Aumentar timeout para 30 segundos
      _client!.autoReconnect = false; // Desabilitar auto-reconnect para evitar loops
      _client!.resubscribeOnAutoReconnect = false;
      
      _client!.logging(on: false);
      
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .withWillTopic('lwt')
          .withWillMessage('Client disconnected')
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      
      if (email.isNotEmpty && password.isNotEmpty) {
        connMessage.authenticateAs(email, password);
      }
            
      _client!.connectionMessage = connMessage;
      
      await _client!.connect();
      
      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _isConnected = true;
        _connectionController.add(true);
        
        await _setupSubscriptions();
        _startReadSensorTimer();
        
        return true;
      } else {
        final status = _client!.connectionStatus!;
        String errorMsg = 'Falha na conexão: State=${status.state}';
        if (status.returnCode != null) {
          errorMsg += ', Code=${status.returnCode}';
        }
        throw Exception(errorMsg);
      }
      
    } catch (e) {
      String errorMsg = 'Erro ao conectar MQTT: $e';
      
      // Tratamento específico para diferentes tipos de erro
      if (e.toString().contains('Connection reset by peer')) {
        errorMsg = 'Credenciais MQTT incorretas ou servidor indisponível. Verifique email e senha do HiveMQ Cloud.';
      } else if (e.toString().contains('Connection refused')) {
        errorMsg = 'Servidor MQTT não encontrado. Verifique a URL do broker.';
      } else if (e.toString().contains('Network is unreachable')) {
        errorMsg = 'Sem conexão com a internet. Verifique sua rede.';
      } else if (e.toString().contains('timeout')) {
        errorMsg = 'Timeout na conexão MQTT. Tente novamente.';
      }
      
      _lastError = errorMsg;
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  Future<void> _setupSubscriptions() async {
    if (_client == null || !_isConnected) return;
    
    try {
      final topics = [
        'esp32/umidade',
        'esp32/temperatura',
        'esp32/umidade-solo',
      ];
      
      for (String topic in topics) {
        _client!.subscribe(topic, MqttQos.atLeastOnce);
      }
      
      _client!.updates!.listen(_onMessageReceived);
      
      // await Future.delayed(Duration(seconds: 1));
      await testMqttCommunication();
      
    } catch (e) {
      _lastError = 'Erro ao configurar subscrições: $e';
    }
  }

  // Iniciar timer para ler sensores a cada 5 segundos
  void _startReadSensorTimer() {
    _readSensorTimer?.cancel();
    
    _readSensorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _requestSensorReading();
    });
    
    // Fazer primeira leitura imediatamente
    _requestSensorReading();
  }

  // Solicitar leitura dos sensores
  Future<void> _requestSensorReading() async {
    if (_client == null || !_isConnected) {
      return;
    }
    
    try {
      const topic = 'esp32/';
      const message = 'Ler sensor';
      
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      
    } catch (e) {
      _lastError = 'Erro ao solicitar leitura de sensores: $e';
    }
  }

  // Callback quando conectado
  void _onConnected() {
    _isConnected = true;
    _lastError = null;
    _connectionController.add(true);
  }

  // Callback quando desconectado
  void _onDisconnected() {
    _isConnected = false;
    _connectionController.add(false);
    _readSensorTimer?.cancel();
  }

  // Callback quando inscrito em tópico
  void _onSubscribed(String topic) {
    // Subscription confirmada
  }

  // Callback para auto-reconexão
  void _onAutoReconnect() {
    // Auto-reconectando
  }

  // Processar mensagens recebidas
  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage?>> messages) {
    for (var message in messages) {
      final topic = message.topic;
      final payload = MqttPublishPayload.bytesToStringAsString(
        (message.payload as MqttPublishMessage).payload.message
      );
      
      _processSensorMessage(topic, payload);
    }
  }

  // Processar mensagem de sensor específico
  void _processSensorMessage(String topic, String payload) {
    try {
      // Se for o tópico de teste, apenas retornar
      if (topic.startsWith('teste/')) {
        return;
      }
      
      final value = double.tryParse(payload.trim());
      if (value == null) {
        return;
      }
      
      final stationId = _currentStationId ?? 'unknown';
      
      // Criar ou atualizar dados do sensor baseado no tópico
      SensorData sensorData;
      
      // Determinar tipo de sensor baseado no tópico (suporte aos tópicos esp32/)
      String sensorType = '';
      
      if (topic.contains('umidade-solo')) {
        sensorType = 'umidade-solo';
      } else if (topic.contains('umidade')) {
        sensorType = 'umidade';
      } else if (topic.contains('temperatura')) {
        sensorType = 'temperatura';
      }
      
      // Aceitar mensagens dos tópicos esp32/ diretamente
      if (topic.startsWith('esp32/') && sensorType.isNotEmpty) {
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
        
        // Emitir dados do sensor
        _sensorDataController.add(sensorData);
        
      } else {
        // Tópico não reconhecido
      }
      
    } catch (e) {
      // Erro ao processar mensagem
    }
  }

  // Teste de comunicação MQTT - publicar em tópico de teste
  Future<bool> testMqttCommunication() async {
    if (_client == null || !_isConnected) {
      return false;
    }
    
    try {
      // Publicar em um tópico de teste genérico
      const testTopic = 'teste/app_flutter';
      const testMessage = 'Hello from Flutter App!';
      
      final builder = MqttClientPayloadBuilder();
      builder.addString(testMessage);
      
      _client!.publishMessage(testTopic, MqttQos.atLeastOnce, builder.payload!);
      
      // Também subscrever ao tópico de teste para ver se recebemos de volta
      _client!.subscribe(testTopic, MqttQos.atLeastOnce);
      
      return true;
      
    } catch (e) {
      return false;
    }
  }

  // Publicar comando de irrigação
  Future<bool> publishIrrigationCommand(String command) async {
    if (_client == null || !_isConnected) {
      _lastError = 'MQTT não conectado';
      return false;
    }
    
    try {
      const topic = 'esp32/';
      
      final builder = MqttClientPayloadBuilder();
      builder.addString(command);
      
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      return true;
      
    } catch (e) {
      _lastError = 'Erro ao publicar comando: $e';
      return false;
    }
  }

  // Desconectar
  Future<void> disconnect() async {
    try {
      _readSensorTimer?.cancel();
      _readSensorTimer = null;
      
      if (_client != null) {
        _client!.disconnect();
        _client = null;
      }
      
      _isConnected = false;
      _lastError = null;
      _connectionController.add(false);
      
    } catch (e) {
      _lastError = 'Erro ao desconectar: $e';
    }
  }

  // Verificar conexão
  Future<bool> checkConnection() async {
    return _client?.connectionStatus?.state == MqttConnectionState.connected;
  }

  // Limpar recursos
  void dispose() {
    _readSensorTimer?.cancel();
    _sensorDataController.close();
    _connectionController.close();
    disconnect();
  }
}
