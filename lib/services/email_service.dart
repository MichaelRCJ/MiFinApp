import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static Map<String, dynamic>? _config;
  static SmtpServer? _server;

  // Expected JSON at assets/config/email_smtp.json (no credenciales sensibles)
  // {
  //   "host": "smtp.example.com",
  //   "port": 587,
  //   "ssl": false,
  //   "name": "MiFinApp"
  // }
  static Future<void> _ensureLoaded() async {
    if (_config != null && _server != null) return;
    final raw = await rootBundle.loadString('assets/config/email_smtp.json');
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      throw StateError('Config SMTP inválida');
    }
    _config = data;
    final host = (data['host'] ?? '').toString();
    final port = int.tryParse((data['port'] ?? '').toString()) ?? 587;
    // Credenciales: usa --dart-define si están presentes; de lo contrario, usa estas constantes.
    const smtpUsername = 'upecmaicol@gmail.com';
    const smtpPassword = 'qdwwbxuevslpaeep';
    final envUsername = const String.fromEnvironment('SMTP_USERNAME');
    final envPassword = const String.fromEnvironment('SMTP_PASSWORD');
    final username = envUsername.isNotEmpty ? envUsername : smtpUsername;
    final password = envPassword.isNotEmpty ? envPassword : smtpPassword;
    final ssl = (data['ssl'] ?? false) == true;

    if (host.isEmpty || username.isEmpty || password.isEmpty) {
      throw StateError('Faltan credenciales SMTP. Defina SMTP_USERNAME y SMTP_PASSWORD con --dart-define o configure los fallbacks.');
    }
    _server = SmtpServer(host,
        port: port,
        ssl: ssl,
        username: username,
        password: password,
        ignoreBadCertificate: false);
  }

  static Future<void> sendTemporaryPasswordEmail({
    required String toEmail,
    required String username,
    required String temp,
    required DateTime expiresAt,
  }) async {
    await _ensureLoaded();
    final name = (_config?['name'] ?? 'MiFinApp').toString();
    // Usar la misma cuenta SMTP como remitente
    final fromUser = _server?.username ?? const String.fromEnvironment('SMTP_USERNAME');
    final from = (fromUser.isNotEmpty) ? fromUser : 'no-reply@example.com';

    final minutesLeft = expiresAt.difference(DateTime.now()).inMinutes;
    final subject = 'Tu contraseña temporal';
    final textBody = 'Hola $username,\n\n'
        'Tu contraseña temporal es: $temp\n'
        'Vence en aproximadamente ${minutesLeft <= 0 ? 1 : minutesLeft} minuto(s).\n\n'
        'Úsala para iniciar sesión y cámbiala desde la app.\n\n'
        '$name';

    final message = Message()
      ..from = Address(from, name)
      ..recipients.add(toEmail)
      ..subject = subject
      ..text = textBody;

    try {
      final sendReport = await send(message, _server!);
      if (sendReport == null) {
        throw StateError('No se pudo enviar el correo');
      }
    } on MailerException catch (e) {
      // Primer error con configuración actual
      final primaryReasons = (e.problems.isNotEmpty)
          ? e.problems.map((p) => '[${p.code}] ${p.msg}').join('; ')
          : e.toString();

      // Intento de reintento con configuración alterna (cambia SSL/puerto)
      try {
        final host = (_config?['host'] ?? '').toString();
        final basePort = int.tryParse((_config?['port'] ?? '').toString()) ?? 587;
        final baseSsl = (_config?['ssl'] ?? false) == true;
        final altServer = SmtpServer(
          host,
          port: baseSsl ? 587 : 465,
          ssl: !baseSsl,
          username: _server?.username,
          password: _server?.password,
          ignoreBadCertificate: false,
        );
        final retryReport = await send(message, altServer);
        if (retryReport == null) {
          throw StateError('No se pudo enviar el correo en reintento');
        }
        return; // Reintento exitoso
      } on MailerException catch (e2) {
        final retryReasons = (e2.problems.isNotEmpty)
            ? e2.problems.map((p) => '[${p.code}] ${p.msg}').join('; ')
            : e2.toString();
        throw StateError('Error SMTP (primario): $primaryReasons\nError SMTP (reintento): $retryReasons');
      } catch (e2) {
        throw StateError('Error SMTP (primario): $primaryReasons\nError (reintento): $e2');
      }
    } catch (e) {
      // Cualquier otra excepción no MailerException
      throw StateError('Error de envío: $e');
    }
  }
}

