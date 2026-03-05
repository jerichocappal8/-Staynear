import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property.dart';

class PropertyService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Property>> getProperties() {
    return _db.collection('properties').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Property.fromMap(doc.id, doc.data());
      }).toList();
    });
  }
}