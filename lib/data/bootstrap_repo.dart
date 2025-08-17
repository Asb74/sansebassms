import 'package:hive/hive.dart';

class BootstrapRepo {
  BootstrapRepo._();
  static Future<void>? _openFuture;

  static Future<void> ensureBoxes() {
    return _openFuture ??= _open();
  }

  static Future<void> _open() async {
    await Future.wait([
      Hive.openBox('settings'),
    ]);
  }
}
