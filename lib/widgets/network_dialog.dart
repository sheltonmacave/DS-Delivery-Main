import 'package:flutter/material.dart';

class NetworkRequiredDialog extends StatelessWidget {
  const NetworkRequiredDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const NetworkRequiredDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conexão Necessária'),
      content: const Text(
        'Esta função requer conexão com a internet. '
        'Por favor, conecte-se a uma rede Wi-Fi ou de dados móveis para continuar.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}