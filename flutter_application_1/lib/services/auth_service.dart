import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../models/local_user.dart';
import '../utils/validators.dart';
import 'database_service.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  static final ValueNotifier<LocalUser?> currentUserNotifier =
      ValueNotifier<LocalUser?>(null);

  static final Pbkdf2 _passwordHasher = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  AuthService({DatabaseService? database})
    : _database = database ?? DatabaseService();

  final DatabaseService _database;

  Future<LocalUser?> restoreSession() async {
    final userId = await _database.getCurrentUserId();
    if (userId == null) return null;

    final user = await _database.getUserById(userId);
    if (user == null) {
      await _database.clearCurrentUser();
      return null;
    }

    currentUserNotifier.value = user;
    return user;
  }

  Future<LocalUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    final emailError = Validators.email(normalizedEmail);
    if (emailError != null) {
      throw AuthServiceException(emailError);
    }

    final passwordError = Validators.password(password);
    if (passwordError != null) {
      throw AuthServiceException(passwordError);
    }

    final credentials = await _database.getCredentialsByEmail(normalizedEmail);
    if (credentials == null) {
      throw const AuthServiceException('The email or password is incorrect.');
    }

    final user = LocalUser.fromMap(credentials);
    final storedHash = credentials['password_hash'];
    final storedSalt = credentials['password_salt'];
    if (storedHash is! String || storedSalt is! String) {
      throw const FormatException('Stored account credentials are invalid.');
    }

    final calculatedHash = await _hashPassword(password, base64Decode(storedSalt));
    if (!_constantTimeEquals(calculatedHash, base64Decode(storedHash))) {
      throw const AuthServiceException('The email or password is incorrect.');
    }

    await _database.saveCurrentUser(user.id);
    currentUserNotifier.value = user;
    return user;
  }

  Future<LocalUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim();

    final nameError = Validators.requiredText(normalizedName, fieldName: 'Name');
    if (nameError != null) {
      throw AuthServiceException(nameError);
    }

    final emailError = Validators.email(normalizedEmail);
    if (emailError != null) {
      throw AuthServiceException(emailError);
    }

    final passwordError = Validators.password(password);
    if (passwordError != null) {
      throw AuthServiceException(passwordError);
    }

    if (await _database.getUserByEmail(normalizedEmail) != null) {
      throw const AuthServiceException('An account already exists for this email.');
    }

    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final passwordHash = await _hashPassword(password, salt);
    final user = await _database.createUser(
      name: normalizedName,
      email: normalizedEmail,
      passwordHash: base64Encode(passwordHash),
      passwordSalt: base64Encode(salt),
    );

    await _database.saveCurrentUser(user.id);
    currentUserNotifier.value = user;
    return user;
  }

  Future<void> signOut() async {
    await _database.clearCurrentUser();
    currentUserNotifier.value = null;
  }

  static Future<List<int>> _hashPassword(
    String password,
    List<int> salt,
  ) async {
    final key = await _passwordHasher.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  static bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}
