import 'dart:async';

class LogBuffer {
  static final LogBuffer I = LogBuffer._();
  LogBuffer._();

  final _lines = <String>[];
  final _ctrl = StreamController<List<String>>.broadcast();

  Stream<List<String>> get stream => _ctrl.stream;
  List<String> get lines => List.unmodifiable(_lines);

  void add(String line) {
    final ts = DateTime.now().toIso8601String();
    _lines.add("[$ts] $line");
    if (_lines.length > 2000) _lines.removeRange(0, _lines.length - 2000);
    _ctrl.add(lines);
  }
}

void installGlobalLogCapture() {
  // Captura prints
  Zone.current
      .fork(specification: ZoneSpecification(print: (self, parent, zone, message) {
    LogBuffer.I.add(message);
    parent.print(zone, message);
  })).run(() {});
}

