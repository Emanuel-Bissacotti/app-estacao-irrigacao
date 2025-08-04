import 'package:cloud_firestore/cloud_firestore.dart';

class Data {
  String uid;
  DateTime date;
  double? airHumidity;
  double? irrigatedMillimeters;
  double? soilHumidity;
  double? temperature;

  Data({
    required this.uid,
    required this.date,
    this.airHumidity,
    this.irrigatedMillimeters,
    this.soilHumidity,
    this.temperature,
  });

  factory Data.fromMap(Map<String, dynamic> data) {
    return Data(
      uid: data['uid'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      airHumidity: (data['airHumidity'] as num?)?.toDouble(),
      irrigatedMillimeters: (data['irrigatedMillimeters'] as num?)?.toDouble(),
      soilHumidity: (data['soilHumidity'] as num?)?.toDouble(),
      temperature: (data['temperature'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'date': date,
      if (airHumidity != null) 'airHumidity': airHumidity,
      if (irrigatedMillimeters != null) 'irrigatedMillimeters': irrigatedMillimeters,
      if (soilHumidity != null) 'soilHumidity': soilHumidity,
      if (temperature != null) 'temperature': temperature,
    };
  }
}