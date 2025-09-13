import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../services/feedback_service.dart';

class FeedbackBottomSheet extends StatefulWidget {
  const FeedbackBottomSheet({super.key});

  // Método estático para facilitar a exibição do bottom sheet
  static void show(BuildContext context) {
    // Usar configurações que ajudam a lidar com o teclado e evitar overflow
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Ajusta o padding com base no teclado virtual
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const FeedbackBottomSheet(),
        );
      },
    );
  }

  @override
  State<FeedbackBottomSheet> createState() => _FeedbackBottomSheetState();
}

class _FeedbackBottomSheetState extends State<FeedbackBottomSheet> {
  final TextEditingController _feedbackController = TextEditingController();
  final FeedbackService _feedbackService = FeedbackService();
  bool _isSending = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _sendFeedback() async {
    final String feedbackText = _feedbackController.text.trim();

    if (feedbackText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escreva uma sugestão antes de enviar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final bool success = await _feedbackService.sendFeedback(feedbackText);

      // Verificar se o widget ainda está montado antes de atualizar o estado
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      if (success) {
        _feedbackController.clear();
        Navigator.pop(context); // Fechar o bottom sheet

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Sugestão enviada com sucesso! Obrigado pelo feedback.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Não foi possível enviar sua sugestão. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao enviar sugestão. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color highlightColor = Color(0xFFFF6A00);

    return DraggableScrollableSheet(
      initialChildSize: 0.6, // Aumentado para dar mais espaço
      minChildSize: 0.4, // Aumentado para ter mais espaço mínimo
      maxChildSize: 0.9, // Permitir mais espaço para o teclado
      expand: false, // Importante para evitar que ocupe toda a tela
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF232323),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // Handle para arrastar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Título e ícone
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: highlightColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Symbols.lightbulb, color: highlightColor),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Ajude-nos a te fornecer um serviço com mais qualidade. Diga-nos como podemos melhorar!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Campo de texto para feedback com altura fixa
              SizedBox(
                height: 150,
                child: TextField(
                  controller: _feedbackController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Escreva aqui sua sugestão...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: highlightColor),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botão para enviar
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSending ? null : _sendFeedback,
                  style: FilledButton.styleFrom(
                    backgroundColor: highlightColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: highlightColor.withOpacity(0.5),
                  ),
                  child: _isSending
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Enviando...'),
                          ],
                        )
                      : const Text('Enviar Sugestão'),
                ),
              ),

              // Espaço adicional para evitar problemas com o teclado
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
