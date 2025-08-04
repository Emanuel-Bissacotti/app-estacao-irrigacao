import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_estacao_irrigacao/models/irrigation_station.dart';

class IrrigationStationsStream {
  /// Stream em tempo real das estações de irrigação do usuário
  static Stream<List<IrrigationStation>> getStationsStream(String clientUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(clientUid)
        .collection('irrigation_stations')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id; // Garantir que o UID do documento seja incluído
        return IrrigationStation.fromMap(data);
      }).toList();
    });
  }
}
