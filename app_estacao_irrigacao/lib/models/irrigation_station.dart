class IrrigationStation {
  final String uid;
  final String name;
  final String urlMqtt;
  final double percentForIrrigation;
  final double millimetersWater;

  IrrigationStation({
    required this.uid,
    required this.name,
    required this.urlMqtt,
    this.percentForIrrigation = -1,
    this.millimetersWater = -1,
  });

  factory IrrigationStation.fromMap(Map<String, dynamic> data) {
    return IrrigationStation(
      uid: data['uid'],
      name: data['name'],
      urlMqtt: data['urlMqtt'],
      percentForIrrigation: (data['percentForIrrigation'] as num?)?.toDouble() ?? -1,
      millimetersWater: (data['millimetersWater'] as num?)?.toDouble() ?? -1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'urlMqtt': urlMqtt,
      'percentForIrrigation': percentForIrrigation,
      'millimetersWater': millimetersWater,
    };
  }
}