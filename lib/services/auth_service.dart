import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _kUsersKey = 'auth_users_v1';
  static const String _kLastUsernameKey = 'auth_last_username_v1';
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Estructura interna: { "username": {"password": "...", "email": "...", "name": "...", "surname": "..." } }
  static Future<Map<String, dynamic>> _readUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsersKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _upsertFirebaseUser(User user) async {
    final username = (user.email?.trim().toLowerCase().isNotEmpty ?? false)
        ? user.email!.trim().toLowerCase()
        : user.uid;

    final users = await _readUsers();
    final existing = users[username];
    final data = existing is Map<String, dynamic>
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};

    data['email'] = user.email ?? data['email'] ?? '';
    data['name'] = user.displayName ?? data['name'] ?? '';
    data['surname'] = data['surname'] ?? '';
    data['photoUrl'] = user.photoURL ?? data['photoUrl'];
    data['authProvider'] = 'google';
    data['lastLogin'] = DateTime.now().toIso8601String();

    users[username] = data;
    await _writeUsers(users);
    await setLastUsername(username);
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        await _upsertFirebaseUser(user);
      }
      return userCredential;
    } on Exception {
      rethrow;
    }
  }

  static Future<void> _writeUsers(Map<String, dynamic> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsersKey, jsonEncode(users));
  }

  static Future<bool> usernameExists(String username) async {
    final users = await _readUsers();
    return users.containsKey(username);
  }

  static Future<void> setLastUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastUsernameKey, username);
  }

  static Future<String?> getLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastUsernameKey);
  }

  static Future<void> register({
    required String username,
    required String password,
    required String name,
    required String surname,
    required String email,
  }) async {
    final users = await _readUsers();
    if (users.containsKey(username)) {
      throw Exception('El usuario ya existe');
    }
    users[username] = {
      'password': password,
      'name': name,
      'surname': surname,
      'email': email,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _writeUsers(users);
    await setLastUsername(username);
  }

  static Future<bool> login({
    required String username,
    required String password,
  }) async {
    final users = await _readUsers();
    if (!users.containsKey(username)) return false;
    final data = users[username];
    if (data is Map && data['password'] == password) {
      await setLastUsername(username);
      return true;
    }
    // Permitir contraseña temporal si está vigente
    if (data is Map) {
      final temp = data['tempPassword']?.toString();
      final expStr = data['tempExpiresAt']?.toString();
      if (temp != null && expStr != null && temp == password) {
        try {
          final exp = DateTime.parse(expStr);
          if (DateTime.now().isBefore(exp)) {
            // Login válido con temporal; invalidar inmediatamente
            final newData = Map<String, dynamic>.from(data);
            newData.remove('tempPassword');
            newData.remove('tempExpiresAt');
            users[username] = newData;
            await _writeUsers(users);
            await setLastUsername(username);
            return true;
          }
        } catch (_) {}
      }
    }
    return false;
  }

  // Obtiene los datos de un usuario por username
  static Future<Map<String, dynamic>?> getUser(String username) async {
    final users = await _readUsers();
    final data = users[username];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  // Obtiene los datos del último usuario usado (sesión reciente)
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final u = await getLastUsername();
    if (u == null || u.isEmpty) return null;
    return getUser(u);
  }

  // Cierra la sesión actual eliminando el último usuario usado
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastUsernameKey);
    await _firebaseAuth.signOut();
    final google = GoogleSignIn();
    if (await google.isSignedIn()) {
      await google.signOut();
    }
  }

  // Actualiza nombre/correo y opcionalmente cambia el username (si no está ocupado)
  static Future<void> updateProfile({
    required String username,
    String? newUsername,
    String? name,
    String? email,
  }) async {
    final users = await _readUsers();
    if (!users.containsKey(username)) {
      throw Exception('Usuario no encontrado');
    }
    // Evitar colisión de nombre de usuario
    if (newUsername != null && newUsername != username && users.containsKey(newUsername)) {
      throw Exception('El nuevo usuario ya existe');
    }

    final data = Map<String, dynamic>.from(users[username] as Map);
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;

    if (newUsername != null && newUsername != username) {
      users.remove(username);
      users[newUsername] = data;
      await _writeUsers(users);
      await setLastUsername(newUsername);
    } else {
      users[username] = data;
      await _writeUsers(users);
    }
  }

  // Busca el username a partir de un identificador que puede ser username o correo
  static Future<String?> findUsernameByIdentifier(String identifier) async {
    final id = identifier.trim();
    if (id.isEmpty) return null;
    final users = await _readUsers();
    // Coincidencia directa por username
    if (users.containsKey(id)) return id;
    // Buscar por correo
    for (final entry in users.entries) {
      final data = entry.value;
      if (data is Map && (data['email']?.toString().toLowerCase() ?? '') == id.toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }

  // Restablece la contraseña de un usuario existente
  static Future<void> resetPassword({
    required String username,
    required String newPassword,
  }) async {
    final users = await _readUsers();
    if (!users.containsKey(username)) {
      throw Exception('Usuario no encontrado');
    }
    final data = Map<String, dynamic>.from(users[username] as Map);
    data['password'] = newPassword;
    data['updatedAt'] = DateTime.now().toIso8601String();
    // Al cambiar contraseña, invalidar temporales
    data.remove('tempPassword');
    data.remove('tempExpiresAt');
    users[username] = data;
    await _writeUsers(users);
  }

  // Genera y guarda una contraseña temporal con expiración (minutos)
  static Future<({String username, String email, String temp, DateTime expiresAt})> generateTemporaryPassword({
    required String username,
    int durationMinutes = 10,
  }) async {
    final users = await _readUsers();
    if (!users.containsKey(username)) {
      throw Exception('Usuario no encontrado');
    }
    final data = Map<String, dynamic>.from(users[username] as Map);
    final email = (data['email']?.toString() ?? '').trim();
    if (email.isEmpty) {
      throw Exception('El usuario no tiene correo registrado');
    }
    // Generar un código temporal de 6 caracteres alfanuméricos
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String gen() {
      final now = DateTime.now().microsecondsSinceEpoch;
      int x = now ^ (now >> 7);
      final buf = StringBuffer();
      for (int i = 0; i < 6; i++) {
        x = 1664525 * x + 1013904223; // LCG simple
        buf.write(chars[x.abs() % chars.length]);
      }
      return buf.toString();
    }
    final temp = gen();
    final exp = DateTime.now().add(Duration(minutes: durationMinutes));
    data['tempPassword'] = temp;
    data['tempExpiresAt'] = exp.toIso8601String();
    users[username] = data;
    await _writeUsers(users);
    return (username: username, email: email, temp: temp, expiresAt: exp);
  }

  // Flujo conveniente: acepta usuario o correo, retorna datos para envío
  static Future<({String username, String email, String temp, DateTime expiresAt})?> requestTemporaryPasswordByIdentifier(
    String identifier, {int durationMinutes = 10}
  ) async {
    final u = await findUsernameByIdentifier(identifier);
    if (u == null) return null;
    return generateTemporaryPassword(username: u, durationMinutes: durationMinutes);
  }

  // Busca username por nombre y apellidos (dentro de 'name') y correo
  static Future<String?> findUsernameByNameSurnameEmail({
    required String name,
    required String surname,
    required String email,
  }) async {
    final n = name.trim().toLowerCase();
    final s = surname.trim().toLowerCase();
    final e = email.trim().toLowerCase();
    if (n.isEmpty || s.isEmpty || e.isEmpty) return null;
    final users = await _readUsers();
    for (final entry in users.entries) {
      final data = entry.value;
      if (data is Map) {
        final firstName = (data['name']?.toString() ?? '').toLowerCase();
        final storedSurname = (data['surname']?.toString() ?? '').toLowerCase();
        final mail = (data['email']?.toString() ?? '').toLowerCase();
        final nameMatches = firstName == n || firstName.contains(n);
        final surnameMatches = storedSurname.isNotEmpty
            ? (storedSurname == s || storedSurname.contains(s))
            : ((firstName + ' ').contains(s + ' ') || firstName.contains(s));
        if (nameMatches && surnameMatches && mail == e) {
          return entry.key;
        }
      }
    }
    return null;
  }

  // Flujo: acepta nombre, apellidos y correo; retorna datos para envío
  static Future<({String username, String email, String temp, DateTime expiresAt})?> requestTemporaryPasswordByNameSurnameEmail({
    required String name,
    required String surname,
    required String email,
    int durationMinutes = 10,
  }) async {
    final u = await findUsernameByNameSurnameEmail(name: name, surname: surname, email: email);
    if (u == null) return null;
    return generateTemporaryPassword(username: u, durationMinutes: durationMinutes);
  }
}
