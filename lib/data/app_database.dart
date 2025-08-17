import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  bool _opening = false;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    if (_opening) {
      while (_opening) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_db == null || !_db!.isOpen) {
        throw StateError('DB should be open after wait but is not.');
      }
      return _db!;
    }
    _opening = true;
    try {
      final dir = await getDatabasesPath();
      final path = p.join(dir, 'app.db');
      _db = await openDatabase(
        path,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, v) async {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS items(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)');
        },
        onUpgrade: (db, oldV, newV) async {
          // TODO: migraciones si aplican
        },
      );
      return _db!;
    } finally {
      _opening = false;
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) await db.close();
    _db = null;
  }
}
