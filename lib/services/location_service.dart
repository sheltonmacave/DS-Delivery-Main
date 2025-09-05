import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final _firestore = FirebaseFirestore.instance;

  Future<Position> getCurrentLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Localização desativada');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permissões permanentemente negadas');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> updateLocation(String userId, double lat, double lng) async {
    await _firestore.collection('locations').doc(userId).set({
      'lat': lat,
      'lng': lng,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> trackUser(String userId) {
    return _firestore.collection('locations').doc(userId).snapshots();
  }
}
