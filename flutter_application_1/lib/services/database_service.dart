import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';

import '../models/local_user.dart';
import '../models/task_model.dart';

class DatabaseService {
  DatabaseService._([this._pathOverride]);

  static final DatabaseService _instance = DatabaseService._();

  factory DatabaseService() => _instance;

  DatabaseService.withPathForTesting(String path) : this._(path);

  final String? _pathOverride;
  late final Future<Database> _database = _openDatabase();

  Future<void> initialize() async {
    await _database;
  }

  Future<Database> _openDatabase() async {
    final path =
        _pathOverride ??
        (kIsWeb
            ? 'smart_task_manager.db'
            : '${await getDatabasesPath()}/smart_task_manager.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL COLLATE NOCASE UNIQUE,
            password_hash TEXT NOT NULL,
            password_salt TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            due_date TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');
        await database.execute('''
          CREATE TABLE app_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    final database = await _database;
    await database.close();
  }

  Future<LocalUser?> getUserByEmail(String email) async {
    final database = await _database;
    final rows = await database.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalUser.fromMap(rows.first);
  }

  Future<Map<String, Object?>?> getCredentialsByEmail(String email) async {
    final database = await _database;
    final rows = await database.query(
      'users',
      columns: [
        'id',
        'name',
        'email',
        'created_at',
        'password_hash',
        'password_salt',
      ],
      where: 'email = ?',
      whereArgs: [email.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<LocalUser?> getUserById(String userId) async {
    final id = int.tryParse(userId);
    if (id == null) {
      throw ArgumentError.value(userId, 'userId', 'Must be a local user ID.');
    }

    final database = await _database;
    final rows = await database.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalUser.fromMap(rows.first);
  }

  Future<LocalUser> createUser({
    required String name,
    required String email,
    required String passwordHash,
    required String passwordSalt,
  }) async {
    final database = await _database;
    final createdAt = DateTime.now();
    final id = await database.insert('users', {
      'name': name.trim(),
      'email': email.trim(),
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
      'created_at': createdAt.toIso8601String(),
    });
    return LocalUser(
      id: id.toString(),
      name: name.trim(),
      email: email.trim(),
      createdAt: createdAt,
    );
  }

  Future<void> saveCurrentUser(String userId) async {
    final database = await _database;
    await database.insert('app_state', {
      'key': 'current_user_id',
      'value': userId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getCurrentUserId() async {
    final database = await _database;
    final rows = await database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['current_user_id'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> clearCurrentUser() async {
    final database = await _database;
    await database.delete(
      'app_state',
      where: 'key = ?',
      whereArgs: ['current_user_id'],
    );
  }

  Future<List<TaskModel>> getTasks(String userId) async {
    final id = int.tryParse(userId);
    if (id == null) {
      throw ArgumentError.value(userId, 'userId', 'Must be a local user ID.');
    }

    final database = await _database;
    final rows = await database.query(
      'tasks',
      where: 'user_id = ?',
      whereArgs: [id],
      orderBy: 'due_date ASC, id ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<void> createTask(String userId, TaskModel task) async {
    final id = int.tryParse(userId);
    if (id == null) {
      throw ArgumentError.value(userId, 'userId', 'Must be a local user ID.');
    }

    final database = await _database;
    await database.insert('tasks', {...task.toDatabaseMap(), 'user_id': id});
  }

  Future<void> updateTask(String userId, TaskModel task) async {
    final userIdValue = int.tryParse(userId);
    final taskId = int.tryParse(task.id);
    if (userIdValue == null || taskId == null) {
      throw ArgumentError('Task and user IDs must be local SQLite IDs.');
    }

    final database = await _database;
    final updatedRows = await database.update(
      'tasks',
      task.toDatabaseMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [taskId, userIdValue],
    );
    if (updatedRows != 1) {
      throw StateError('The task no longer exists in the local database.');
    }
  }

  Future<void> deleteTask(String userId, String taskId) async {
    final userIdValue = int.tryParse(userId);
    final taskIdValue = int.tryParse(taskId);
    if (userIdValue == null || taskIdValue == null) {
      throw ArgumentError('Task and user IDs must be local SQLite IDs.');
    }

    final database = await _database;
    final deletedRows = await database.delete(
      'tasks',
      where: 'id = ? AND user_id = ?',
      whereArgs: [taskIdValue, userIdValue],
    );
    if (deletedRows != 1) {
      throw StateError('The task no longer exists in the local database.');
    }
  }
}
