import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Normaliza cualquier valor (Timestamp/DateTime/String) a DateTime local.
DateTime? toLocalDate(dynamic value) {
  if (value == null) return null;

  if (value is Timestamp) {
    return value.toDate().toLocal();
  }
  if (value is DateTime) {
    return value.isUtc ? value.toLocal() : value;
  }
  if (value is String) {
    // Si viene con 'Z' es UTC iso8601; si no, asumimos local.
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    return dt.isUtc ? dt.toLocal() : dt;
  }
  return null;
}

/// Formatea en dd/MM/yyyy HH:mm en hora local.
String formatLocal(dynamic value) {
  final dt = toLocalDate(value);
  if (dt == null) return '(sin fecha)';
  return DateFormat('dd/MM/yyyy HH:mm').format(dt);
}

/// Solo fecha (para Peticiones)
String formatLocalDay(dynamic value) {
  final dt = toLocalDate(value);
  if (dt == null) return '(fecha no válida)';
  return DateFormat('dd/MM/yyyy').format(dt);
}
