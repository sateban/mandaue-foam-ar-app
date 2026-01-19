import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Read single data once
  static Future<Map<dynamic, dynamic>?> readData(String path) async {
    try {
      final snapshot = await _database.ref(path).get();
      if (snapshot.exists) {
        return snapshot.value as Map<dynamic, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error reading data: $e');
      return null;
    }
  }

  /// Read list data once
  static Future<List<Map<String, dynamic>>> readListData(String path) async {
    try {
      final snapshot = await _database.ref(path).get();
      List<Map<String, dynamic>> list = [];
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            list.add({
              'id': key,
              ...Map<String, dynamic>.from(value),
            });
          }
        });
      }
      return list;
    } catch (e) {
      print('Error reading list data: $e');
      return [];
    }
  }

  /// Stream data in real-time
  static Stream<Map<dynamic, dynamic>> streamData(String path) {
    return _database.ref(path).onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as Map<dynamic, dynamic>;
      }
      return {};
    });
  }

  /// Stream list data in real-time
  static Stream<List<Map<String, dynamic>>> streamListData(String path) {
    return _database.ref(path).onValue.map((event) {
      List<Map<String, dynamic>> list = [];
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            list.add({
              'id': key,
              ...Map<String, dynamic>.from(value),
            });
          }
        });
      }
      return list;
    });
  }

  /// Write data
  static Future<void> writeData(String path, Map<String, dynamic> data) async {
    try {
      await _database.ref(path).set(data);
    } catch (e) {
      print('Error writing data: $e');
    }
  }

  /// Update data
  static Future<void> updateData(String path, Map<String, dynamic> data) async {
    try {
      await _database.ref(path).update(data);
    } catch (e) {
      print('Error updating data: $e');
    }
  }

  /// Delete data
  static Future<void> deleteData(String path) async {
    try {
      await _database.ref(path).remove();
    } catch (e) {
      print('Error deleting data: $e');
    }
  }
}
