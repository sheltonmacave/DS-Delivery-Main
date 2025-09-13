import 'dart:async';
import 'package:flutter/material.dart';

class FeedbackService {
  // Email para o qual as sugestões serão enviadas
  static const String feedbackEmail = 'sheltonelias992@gmail.com';

  // Método para enviar a sugestão - usando uma simulação de API de email
  Future<bool> sendFeedback(String feedbackText) async {
    // Em um cenário real, você usaria uma API de envio de email como SendGrid, MailChimp, etc.
    // Aqui vamos simular um atraso de envio para mostrar feedback visual ao usuário

    try {
      // Simula um atraso de rede
      await Future.delayed(const Duration(seconds: 2));

      // Em uma implementação real, você enviaria uma requisição HTTP para um endpoint de API
      // Por exemplo:
      /*
      final response = await http.post(
        Uri.parse('https://seu-backend.com/api/enviar-sugestao'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': feedbackEmail,
          'message': feedbackText,
        }),
      );
      
      return response.statusCode == 200;
      */

      // Para fins de demonstração, retornamos true para simular sucesso
      return true;
    } catch (e) {
      debugPrint('Erro ao enviar feedback: $e');
      return false;
    }
  }
}
