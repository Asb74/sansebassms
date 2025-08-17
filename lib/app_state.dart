import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool firebaseAvailable = true;
  String? lastError;

  void setFirebaseAvailable(bool value, {String? error}) {
    firebaseAvailable = value;
    lastError = error;
    notifyListeners();
  }
}
