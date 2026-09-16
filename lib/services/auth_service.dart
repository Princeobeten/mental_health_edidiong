import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../data/local/database_helper.dart';
import '../data/models/app_user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Local authentication for the Login/Register flow (Chapter 4). Accounts are
/// stored on-device in SQLite; passwords are salted and SHA-256 hashed (never
/// stored in plain text). The very first account created becomes the admin.
class AuthService {
  final DatabaseHelper _dbHelper;
  AuthService(this._dbHelper);

  static const _sessionKey = 'logged_in_user_id';

  String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  String _newSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Inserts the default admin account (from [AppConfig]) on first run, if it
  /// is not already present. Idempotent — safe to call on every startup.
  Future<void> seedDefaultAdmin() async {
    final db = await _dbHelper.database;
    final email = AppConfig.adminEmail.toLowerCase();
    final existing = await db.query('users',
        where: 'email = ?', whereArgs: [email], limit: 1);
    if (existing.isNotEmpty) return;

    final salt = _newSalt();
    await db.insert('users', {
      'full_name': AppConfig.adminName,
      'email': email,
      'password_hash': _hash(AppConfig.adminPassword, salt),
      'salt': salt,
      'is_admin': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final db = await _dbHelper.database;
    final normalizedEmail = email.trim().toLowerCase();

    final existing = await db.query('users',
        where: 'email = ?', whereArgs: [normalizedEmail], limit: 1);
    if (existing.isNotEmpty) {
      throw AuthException('An account with this email already exists.');
    }

    // First registered user is the admin (for the Admin Panel demo).
    final count =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users')) ??
            0;

    final salt = _newSalt();
    final id = await db.insert('users', {
      'full_name': fullName.trim(),
      'email': normalizedEmail,
      'password_hash': _hash(password, salt),
      'salt': salt,
      'is_admin': count == 0 ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _setSession(id);
    return AppUser(
      id: id,
      fullName: fullName.trim(),
      email: normalizedEmail,
      isAdmin: count == 0,
      createdAt: DateTime.now(),
    );
  }

  Future<AppUser> login(String email, String password) async {
    final db = await _dbHelper.database;
    final normalizedEmail = email.trim().toLowerCase();

    final rows = await db.query('users',
        where: 'email = ?', whereArgs: [normalizedEmail], limit: 1);
    if (rows.isEmpty) {
      throw AuthException('No account found for this email.');
    }
    final row = rows.first;
    final salt = row['salt'] as String;
    if (_hash(password, salt) != row['password_hash']) {
      throw AuthException('Incorrect password. Please try again.');
    }

    await _setSession(row['id'] as int);
    return AppUser.fromMap(row);
  }

  Future<AppUser?> currentUser() async {
    final db = await _dbHelper.database;
    final idRows = await db.query('app_settings',
        where: 'key = ?', whereArgs: [_sessionKey], limit: 1);
    if (idRows.isEmpty) return null;
    final id = int.tryParse(idRows.first['value'] as String? ?? '');
    if (id == null) return null;

    final rows =
        await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<void> logout() async {
    final db = await _dbHelper.database;
    await db.delete('app_settings',
        where: 'key = ?', whereArgs: [_sessionKey]);
  }

  Future<void> _setSession(int userId) async {
    final db = await _dbHelper.database;
    await db.insert(
      'app_settings',
      {'key': _sessionKey, 'value': '$userId'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- Admin helpers -----------------------------------------------------
  Future<List<AppUser>> getAllUsers() async {
    final db = await _dbHelper.database;
    final rows = await db.query('users', orderBy: 'created_at DESC');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<int> countAdmins() async {
    final db = await _dbHelper.database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM users WHERE is_admin = 1')) ??
        0;
  }

  Future<AppUser?> getUser(int id) async {
    final db = await _dbHelper.database;
    final rows =
        await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  /// Grants or revokes admin rights. Refuses to remove the last admin, which
  /// would lock the Admin Panel away with no way back in.
  Future<void> setAdmin(int id, bool isAdmin) async {
    final db = await _dbHelper.database;
    if (!isAdmin && await countAdmins() <= 1) {
      throw AuthException(
          'This is the only admin account — promote someone else first.');
    }
    await db.update('users', {'is_admin': isAdmin ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Sets a new password for a user (admin-initiated reset). Re-salts rather
  /// than reusing the old salt, so the stored hash changes completely.
  Future<void> resetPassword(int id, String newPassword) async {
    if (newPassword.trim().length < 6) {
      throw AuthException('Password must be at least 6 characters.');
    }
    final db = await _dbHelper.database;
    final salt = _newSalt();
    final updated = await db.update(
      'users',
      {'password_hash': _hash(newPassword, salt), 'salt': salt},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) throw AuthException('That account no longer exists.');
  }

  /// Deletes a user. Guards against removing the last admin or the account the
  /// admin is currently signed in as.
  Future<void> deleteUser(int id) async {
    final db = await _dbHelper.database;

    final me = await currentUser();
    if (me?.id == id) {
      throw AuthException('You cannot delete the account you are signed in as.');
    }

    final user = await getUser(id);
    if (user == null) throw AuthException('That account no longer exists.');
    if (user.isAdmin && await countAdmins() <= 1) {
      throw AuthException('This is the only admin account and cannot be deleted.');
    }

    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
