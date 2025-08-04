class SensorData {
  final String stationId;
  final double? humidity;
  final double? temperature;
  final double? soilMoisture;
  final DateTime timestamp;

  SensorData({
    required this.stationId,
    this.humidity,
    this.temperature,
    this.soilMoisture,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  SensorData copyWith({
    String? stationId,
    double? humidity,
    double? temperature,
    double? soilMoisture,
    DateTime? timestamp,
  }) {
    return SensorData(
      stationId: stationId ?? this.stationId,
      humidity: humidity ?? this.humidity,
      temperature: temperature ?? this.temperature,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
