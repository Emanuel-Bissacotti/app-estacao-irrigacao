import 'package:app_estacao_irrigacao/models/irrigation_station.dart';
import 'package:app_estacao_irrigacao/models/sensor_data.dart';
import 'package:app_estacao_irrigacao/services/mqtt_service.dart';
import 'package:app_estacao_irrigacao/viewmodels/irrigation_station_viewmodel.dart';
import 'package:app_estacao_irrigacao/widgets/historical_data_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class IrrigationStationPage extends StatefulWidget {
  final MqttService mqttService;
  final IrrigationStation irrigationStation;
  final String userId;
  
  const IrrigationStationPage({
    super.key,
    required this.mqttService,
    required this.irrigationStation,
    required this.userId,
  });

  @override
  State<IrrigationStationPage> createState() => _IrrigationStationPageState();
}

class _IrrigationStationPageState extends State<IrrigationStationPage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => IrrigationStationViewModel(widget.mqttService, widget.irrigationStation, widget.userId),
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<IrrigationStationViewModel>(
            builder: (context, viewModel, child) => Text(viewModel.stationName),
          ),
          actions: [
            Consumer<IrrigationStationViewModel>(
              builder: (context, viewModel, child) {
                return ElevatedButton(
                  onPressed: viewModel.isMqttConnected 
                    ? () => _showIrrigationDialog(context)
                    : null,
                  child: const Icon(Icons.water_drop),
                );
              },
            ),
          ],
        ),
        body: Consumer<IrrigationStationViewModel>(
          builder: (context, viewModel, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Dados Atuais: ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (viewModel.hasData)
                    _buildSensorDataDisplay(viewModel.currentSensorData!)
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Aguardando dados dos sensores...'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Dados Históricos:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: viewModel.isLoadingHistoricalData 
                              ? null 
                              : () => viewModel.refreshHistoricalData(),
                            icon: viewModel.isLoadingHistoricalData 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                            tooltip: 'Atualizar dados',
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Navegação de datas
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: viewModel.isLoadingHistoricalData 
                              ? null 
                              : () => viewModel.goToPreviousDay(),
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Dia anterior',
                          ),
                          GestureDetector(
                            onTap: viewModel.isLoadingHistoricalData 
                              ? null 
                              : () => _selectDate(context, viewModel),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, 
                                vertical: 8.0
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    viewModel.isToday 
                                      ? 'Hoje' 
                                      : '${viewModel.selectedDate.day}/${viewModel.selectedDate.month}/${viewModel.selectedDate.year}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              if (!viewModel.isToday)
                                IconButton(
                                  onPressed: viewModel.isLoadingHistoricalData 
                                    ? null 
                                    : () => viewModel.goToToday(),
                                  icon: const Icon(Icons.today),
                                  tooltip: 'Ir para hoje',
                                ),
                              IconButton(
                                onPressed: viewModel.isLoadingHistoricalData 
                                  ? null 
                                  : () => viewModel.goToNextDay(),
                                icon: const Icon(Icons.chevron_right),
                                tooltip: 'Próximo dia',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Gráfico dos dados históricos
                  HistoricalDataChart(
                    data: viewModel.historicalData,
                    isLoading: viewModel.isLoadingHistoricalData,
                    selectedDate: viewModel.selectedDate,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSensorDataDisplay(SensorData sensorData) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sensorData.temperature != null)
            Chip(
              label: Text('${sensorData.temperature?.toStringAsFixed(1)}°C'),
              backgroundColor: Colors.orange[100],
              avatar: const Icon(Icons.thermostat, size: 16),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            ),
            const SizedBox(height: 4.0),
          if (sensorData.humidity != null)
            Chip(
              label: Text('${sensorData.humidity?.toStringAsFixed(1)}%'),
              backgroundColor: Colors.blue[100],
              avatar: const Icon(Icons.opacity, size: 16),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            ),
            const SizedBox(height: 4.0),
          if (sensorData.soilMoisture != null)
            Chip(
              label: Text('Solo: ${sensorData.soilMoisture?.toStringAsFixed(1) ?? '0.0'}%'),
              backgroundColor: Colors.brown[100],
              avatar: const Icon(Icons.grass, size: 16),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            ),
            const SizedBox(height: 4.0),
        ],
      ),
    );
  }

  Future<void> _showIrrigationDialog(BuildContext context) async {
    final viewModel = Provider.of<IrrigationStationViewModel>(context, listen: false);
    final TextEditingController mmController = TextEditingController(
      text: this.widget.irrigationStation.millimetersWater.toString()
    );
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Irrigação'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quantos mm de irrigação deseja iniciar?'),
              const SizedBox(height: 16),
              TextField(
                controller: mmController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Milímetros (mm)',
                  hintText: 'Ex: 5.0',
                  border: OutlineInputBorder(),
                  suffixText: 'mm',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final mmText = mmController.text.trim();
                
                if (mmText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, insira a quantidade de mm.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                final mmValue = double.tryParse(mmText);
                if (mmValue == null || mmValue <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, insira um valor válido maior que 0.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                Navigator.of(context).pop();
                
                final success = await viewModel.startIrrigation(mmText);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success 
                          ? 'Comando de irrigação ($mmText mm) enviado com sucesso!'
                          : 'Falha ao enviar comando de irrigação.',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Iniciar Irrigação'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, IrrigationStationViewModel viewModel) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: viewModel.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Selecionar data',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    
    if (picked != null && picked != viewModel.selectedDate) {
      await viewModel.changeDate(picked);
    }
  }
}