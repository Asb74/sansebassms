import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

DateTime? _parseDay(String s) {
  // admite 'YYYY-MM-DD' y 'DD/MM/YYYY'
  try {
    if (s.contains('-')) return DateTime.parse(s); // asume local
    if (s.contains('/')) {
      final p = s.split('/');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    }
  } catch (_) {}
  return null;
}

DateTime? _parseHour(String s) {
  try {
    final p = s.split(':');
    return DateTime(0, 1, 1, int.parse(p[0]), int.parse(p[1]));
  } catch (_) {}
  return null;
}

/// Convierte cualquier valor a DateTime local (si es UTC lo pasa a local).
DateTime? toLocalDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toLocal();
  if (value is DateTime) return value.isUtc ? value.toLocal() : value;
  if (value is String) {
    final dt = DateTime.tryParse(value);
    if (dt != null) return dt.isUtc ? dt.toLocal() : dt;
  }
  return null;
}

/// Combina Día + Hora (strings) en un DateTime local.
/// Si alguno no existe/parsea, devuelve null.
DateTime? combineLocalDayHour(dynamic dia, dynamic hora) {
  final day = dia is Timestamp
      ? dia.toDate()
      : (dia is DateTime
          ? dia
          : (dia is String
              ? _parseDay(dia)
              : null));
  final hhmm = (hora is String) ? _parseHour(hora) : null;
  if (day == null || hhmm == null) return null;
  return DateTime(day.year, day.month, day.day, hhmm.hour, hhmm.minute);
}

String formatLocal(dynamic value) {
  final dt = toLocalDate(value);
  if (dt == null) return '(sin fecha)';
  return DateFormat('dd/MM/yyyy HH:mm').format(dt);
}

String formatLocalFromDayHour(dynamic dia, dynamic hora) {
  final dt = combineLocalDayHour(dia, hora);
  if (dt == null) return '(sin fecha)';
  return DateFormat('dd/MM/yyyy HH:mm').format(dt);
}
