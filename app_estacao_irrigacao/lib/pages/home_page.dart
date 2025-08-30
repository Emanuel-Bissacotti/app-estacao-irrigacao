import 'package:app_estacao_irrigacao/models/user.dart';
import 'package:app_estacao_irrigacao/models/irrigation_station.dart';
import 'package:app_estacao_irrigacao/models/sensor_data.dart';
import 'package:app_estacao_irrigacao/viewmodels/home_viewmodel.dart';
import 'package:app_estacao_irrigacao/services/auth_service.dart';
import 'package:app_estacao_irrigacao/services/mqtt_service.dart';
import 'package:app_estacao_irrigacao/services/stations_stream.dart';
import 'package:app_estacao_irrigacao/widgets/mqtt_config_dialog.dart';
import 'package:app_estacao_irrigacao/widgets/add_irrigation_station.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  final Client client;
  
  const HomePage({super.key, required this.client});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _hasAttemptedAutoConnect = false;

  void _resetAutoConnectFlag() {
    setState(() {
      _hasAttemptedAutoConnect = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<List<IrrigationStation>>(
          create: (_) => IrrigationStationsStream.getStationsStream(widget.client.uid),
          initialData: const [],
          catchError: (context, error) {
            debugPrint('Erro no stream de estações: $error');
            return const [];
          },
        ),
        // ChangeNotifierProvider para MQTT e outras funcionalidades
        ChangeNotifierProvider(
          create: (context) => HomeViewModel(
            widget.client,
            AuthService(),
            MqttService(),
          ),
        ),
      ],
      child: Consumer2<List<IrrigationStation>, HomeViewModel>(
        builder: (context, stations, viewModel, child) {
          // Auto-conectar às estações quando carregarem (apenas uma vez)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (stations.isNotEmpty && 
                viewModel.isMqttConfigured && 
                !viewModel.isMqttConnected &&
                viewModel.activeStation == null &&
                !_hasAttemptedAutoConnect) {
              _hasAttemptedAutoConnect = true;
              viewModel.connectToAllStations(stations);
            }
            
            // Reset do flag se uma conexão manual foi estabelecida
            if (viewModel.isMqttConnected && _hasAttemptedAutoConnect) {
              _resetAutoConnectFlag();
            }
          });

          return Scaffold(
            appBar: AppBar(
              title: const Text('Estações de Irrigação'),
              leading: IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await viewModel.signOut();
                },
                tooltip: 'Sair',
              ),
              actions: [
                IconButton(
                  onPressed: viewModel.isLoading ? null : () async {
                    await _showMqttConfigDialog(context, viewModel);
                  },
                  icon: viewModel.isLoading 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2)
                      )
                    : const Icon(Icons.cloud_sync),
                  tooltip: 'Configurar MQTT',
                ),
                IconButton(
                  onPressed: viewModel.isLoading ? null : () async {
                    await _showAddStationDialog(context, viewModel);
                  },
                  icon: viewModel.isMqttConfigured
                      ? const Icon(Icons.add, color: Colors.green)
                      : const Icon(Icons.add, color: Colors.red),
                  tooltip: 'Adicionar Estação de Irrigação',
                ),
              ],
            ),
            body: _buildBody(context, stations, viewModel),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<IrrigationStation> stations, HomeViewModel viewModel) {
    if (viewModel.errorMessage != null && viewModel.errorMessage?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bool isMqttConnectionError = viewModel.errorMessage!.contains('Connection refused') ||
                                   viewModel.errorMessage!.contains('SocketException') ||
                                   viewModel.errorMessage!.contains('MQTT');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMqttConnectionError ? 'Erro de Conexão MQTT' : 'Erro'),
                const SizedBox(height: 4),
                Text(
                  isMqttConnectionError 
                    ? 'Verifique suas credenciais MQTT e conexão com a internet'
                    : (viewModel.errorMessage ?? 'Erro desconhecido'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: isMqttConnectionError ? Colors.red[700] : Colors.orange[800],
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: isMqttConnectionError ? 'Configurar' : 'OK',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (isMqttConnectionError) {
                  _showMqttConfigDialog(context, viewModel);
                }
              },
            ),
          ),
        );
      });
    }

    if (stations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Nenhuma estação de irrigação cadastrada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Toque no botão + para adicionar uma estação',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stations.length,
      itemBuilder: (context, index) {
        final station = stations[index];
        final isActive = viewModel.activeStation?.uid == station.uid;
        final isConnected = viewModel.isMqttConfigured;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isConnected && isActive ? Colors.green[50] : 
                 isConnected ? Colors.blue[50] : 
                 Colors.grey[50],
          child: Slidable(
            startActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) async {
                    await _showEditStationDialog(context, viewModel, station);
                  },
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: Icons.edit_square,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    topLeft: Radius.circular(16),
                  ),
                ),
              ],
            ),
            child: ListTile(
              leading: Stack(
                children: [
                  Icon(
                    Icons.water_drop, 
                    color: isConnected ? Colors.blue : Colors.grey
                  ),
                  if (isActive && viewModel.isMqttConnected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(station.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive && viewModel.isMqttConnected ? 'Conectado via MQTT' :
                    isConnected ? 'MQTT configurado' : 
                    'Aguardando configuração MQTT',
                    style: TextStyle(
                      color: isActive && viewModel.isMqttConnected ? Colors.green :
                             isConnected ? Colors.blue : 
                             Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isActive && viewModel.currentSensorData != null)
                    _buildSensorDataDisplay(viewModel.currentSensorData ?? SensorData(stationId: ''))
                  else if (isActive && isConnected)
                    const Text(
                      'Aguardando dados dos sensores...',
                      style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
              onTap: () async {
                viewModel.stationControllerPage(context, station);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSensorDataDisplay(SensorData sensorData) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Wrap(
        spacing: 4.0,
        runSpacing: 4.0,
        children: [
          if (sensorData.temperature != null)
            Chip(
              label: Text('${sensorData.temperature?.toStringAsFixed(1)}°C'),
              backgroundColor: Colors.orange[100],
              avatar: const Icon(Icons.thermostat, size: 16),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            ),
          if (sensorData.humidity != null)
            Chip(
              label: Text('${sensorData.humidity?.toStringAsFixed(1)}%'),
              backgroundColor: Colors.blue[100],
              avatar: const Icon(Icons.opacity, size: 16),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            ),
          if (sensorData.soilMoisture != null)
            Chip(
              label: Text('Solo: ${sensorData.soilMoisture?.toStringAsFixed(1) ?? '0.0'}%'),
              backgroundColor: Colors.brown[100],
              avatar: const Icon(Icons.grass, size: 16),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            ),
        ],
      ),
    );
  }

  Future<void> _showMqttConfigDialog(BuildContext context, HomeViewModel viewModel) async {
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return MqttConfigDialog(viewModel: viewModel);
      },
    );
  }

  Future<void> _showAddStationDialog(BuildContext context, HomeViewModel viewModel) async {
    if (!viewModel.isMqttConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure o MQTT primeiro antes de adicionar estações'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return AddIrrigationStationDialog(viewModel: viewModel);
      },
    );
  }

  Future<void> _showEditStationDialog(BuildContext context, HomeViewModel viewModel, IrrigationStation station) async {
    await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return AddIrrigationStationDialog(
          viewModel: viewModel,
          station: station,
        );
      },
    );
  }
}