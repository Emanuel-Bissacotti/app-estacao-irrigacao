import 'package:app_estacao_irrigacao/models/data.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HistoricalDataChart extends StatelessWidget {
  final List<Data> data;
  final bool isLoading;
  final DateTime selectedDate;

  const HistoricalDataChart({
    super.key,
    required this.data,
    required this.isLoading,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Carregando dados históricos...'),
              ],
            ),
          ),
        ),
      );
    }

    if (data.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Nenhum dado histórico encontrado',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getDateTitle(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  lineBarsData: _buildLineBarsData(),
                  titlesData: _buildTitlesData(),
                  borderData: FlBorderData(show: true),
                  gridData: const FlGridData(show: true),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchSpotThreshold: 20, // Aumentar área sensível ao toque
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: _getTooltipItems,
                      tooltipBgColor: Colors.black87,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      maxContentWidth: 200,
                    ),
                  ),
                  // Definir limites do eixo X para mostrar 24 horas completas
                  minX: 0,
                  maxX: 24,
                  // Linhas extras incluindo irrigação
                  extraLinesData: ExtraLinesData(
                    verticalLines: _buildVerticalLines(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  String _getDateTitle() {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
                   selectedDate.month == now.month &&
                   selectedDate.day == now.day;
    
    if (isToday) {
      return 'Dados de Hoje (24 Horas)';
    } else {
      return 'Dados de ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} (24 Horas)';
    }
  }

  List<LineChartBarData> _buildLineBarsData() {
    final List<LineChartBarData> bars = [];

    // Ordenar dados por hora para garantir continuidade
    final sortedData = List<Data>.from(data)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Criar segmentos separados para cada tipo de dados
    bars.addAll(_createSegmentedLines(sortedData, 'temperature', Colors.red));
    bars.addAll(_createSegmentedLines(sortedData, 'airHumidity', Colors.cyan));
    bars.addAll(_createSegmentedLines(sortedData, 'soilHumidity', Colors.green));

    return bars;
  }

  // Método para criar linhas segmentadas que se desconectam em grandes intervalos
  List<LineChartBarData> _createSegmentedLines(List<Data> sortedData, String dataType, Color color) {
    final List<LineChartBarData> segments = [];
    List<FlSpot> currentSegment = [];
    
    for (int i = 0; i < sortedData.length; i++) {
      final dataPoint = sortedData[i];
      final hourOfDay = dataPoint.date.hour + (dataPoint.date.minute / 60.0);
      
      double? value;
      switch (dataType) {
        case 'temperature':
          value = dataPoint.temperature;
          break;
        case 'airHumidity':
          value = dataPoint.airHumidity;
          break;
        case 'soilHumidity':
          value = dataPoint.soilHumidity;
          break;
      }
      
      if (value != null) {
        // Verificar se há uma grande lacuna de tempo (mais de 2 horas)
        if (currentSegment.isNotEmpty) {
          final lastHour = currentSegment.last.x;
          final timeDiff = (hourOfDay - lastHour).abs();
          
          if (timeDiff > 2.0) {
            // Criar um segmento com os pontos atuais
            if (currentSegment.length >= 1) {
              segments.add(_createLineSegment(currentSegment, color));
            }
            currentSegment = [];
          }
        }
        
        currentSegment.add(FlSpot(hourOfDay, value));
      }
    }
    
    // Adicionar o último segmento se existir
    if (currentSegment.length >= 1) {
      segments.add(_createLineSegment(currentSegment, color));
    }
    
    return segments;
  }

  LineChartBarData _createLineSegment(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: List.from(spots),
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: true),
      preventCurveOverShooting: true,
      isCurved: false,
    );
  }


  List<VerticalLine> _buildVerticalLines() {
    final List<VerticalLine> lines = [];

    // Linha vertical para indicar meio-dia
    lines.add(
      VerticalLine(
        x: 12,
        color: Colors.grey.withOpacity(0.3),
        strokeWidth: 1,
        dashArray: [5, 5],
      ),
    );

    // Linhas verticais para irrigação
    for (final dataPoint in data) {
      if (dataPoint.irrigatedMillimeters != null && dataPoint.irrigatedMillimeters! > 0) {
        final hourOfDay = dataPoint.date.hour + (dataPoint.date.minute / 60.0);
        lines.add(
          VerticalLine(
            x: hourOfDay,
            color: Colors.blue,
            strokeWidth: 1.5,
          ),
        );
      }
    }

    return lines;
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            return Text(
              value.toInt().toString(),
              style: const TextStyle(fontSize: 12),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 4, // Mostrar a cada 4 horas (0, 4, 8, 12, 16, 20)
          getTitlesWidget: (value, meta) {
            final hour = value.toInt();
            if (hour >= 0 && hour <= 24) {
              return Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 10),
              );
            }
            return const Text('');
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  List<LineTooltipItem> _getTooltipItems(List<LineBarSpot> touchedSpots) {
    return touchedSpots.map((spot) {
      final hour = spot.x;
      final yValue = spot.y;
      
      // Encontrar o ponto de dados mais próximo baseado na hora
      Data? closestDataPoint;
      double minDifference = double.infinity;
      
      for (final dataPoint in data) {
        final dataHour = dataPoint.date.hour + (dataPoint.date.minute / 60.0);
        final difference = (dataHour - hour).abs();
        if (difference < minDifference) {
          minDifference = difference;
          closestDataPoint = dataPoint;
        }
      }
      
      if (closestDataPoint != null) {
        String label = '';
        String value = '';
        Color color = Colors.white;

        // Determinar qual tipo de dado baseado no valor Y e disponibilidade
        double? tempDiff = closestDataPoint.temperature != null ? 
            (closestDataPoint.temperature! - yValue).abs() : double.infinity;
        double? airHumDiff = closestDataPoint.airHumidity != null ? 
            (closestDataPoint.airHumidity! - yValue).abs() : double.infinity;
        double? soilHumDiff = closestDataPoint.soilHumidity != null ? 
            (closestDataPoint.soilHumidity! - yValue).abs() : double.infinity;

        // Encontrar qual tipo de dado está mais próximo do valor Y tocado
        if (tempDiff <= airHumDiff && tempDiff <= soilHumDiff && closestDataPoint.temperature != null) {
          label = 'Temperatura';
          value = '${closestDataPoint.temperature!.toStringAsFixed(1)}°C';
          color = Colors.red;
        } else if (airHumDiff <= soilHumDiff && closestDataPoint.airHumidity != null) {
          label = 'Umidade do Ar';
          value = '${closestDataPoint.airHumidity!.toStringAsFixed(1)}%';
          color = Colors.cyan;
        } else if (closestDataPoint.soilHumidity != null) {
          label = 'Umidade do Solo';
          value = '${closestDataPoint.soilHumidity!.toStringAsFixed(1)}%';
          color = Colors.green;
        }

        final time = closestDataPoint.date;
        final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        // Verificar se há irrigação neste ponto
        String irrigationInfo = '';
        if (closestDataPoint.irrigatedMillimeters != null && closestDataPoint.irrigatedMillimeters! > 0) {
          irrigationInfo = '\nIrrigação: ${closestDataPoint.irrigatedMillimeters!.toStringAsFixed(1)}mm';
        }

        return LineTooltipItem(
          '$label\n$value\n$timeString$irrigationInfo',
          TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        );
      }
      return const LineTooltipItem('', TextStyle());
    }).toList();
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem('Temperatura (°C)', Colors.red),
        _buildLegendItem('Umidade do Ar (%)', Colors.cyan),
        _buildLegendItem('Umidade do Solo (%)', Colors.green),
        _buildLegendItemVertical('Irrigação (mm)', Colors.blue),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLegendItemVertical(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 2,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
