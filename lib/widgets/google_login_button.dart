import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class GoogleLoginButton extends StatelessWidget {
  final VoidCallback? onSuccess;
  final ValueChanged<Object>? onError;

  const GoogleLoginButton({
    this.onSuccess,
    this.onError,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.g_mobiledata, size: 32),
      onPressed: () async {
        try {
          final credential = await AuthService.signInWithGoogle();
          if (credential == null) {
            onError?.call('Inicio con Google cancelado');
            return;
          }
          onSuccess?.call();
        } catch (e) {
          onError?.call(e);
        }
      },
    );
  }
}
