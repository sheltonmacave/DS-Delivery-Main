import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/order_model.dart';
import '../services/notifications_service.dart';

/// Gerenciador de navegação e transições baseadas no status dos pedidos
/// Centraliza a lógica de para onde navegar quando um pedido muda de estado
class OrderStateNavigator {
  /// Determina para onde o cliente deve navegar com base no status do pedido
  static void navigateClientBasedOnStatus(
    BuildContext context,
    Order order, {
    bool autoFinalized = false,
  }) {
    switch (order.status) {
      case OrderStatus.delivered:
        // Se foi auto-finalizado, mostrar diálogo primeiro
        if (autoFinalized) {
          _showAutoFinalizationDialog(context, order);
          return;
        }

        // Se já foi confirmado manualmente, ir para a tela de resumo
        if (order.manuallyConfirmed == true) {
          context
              .go('/cliente/client_ordersummary', extra: {'orderId': order.id});
          return;
        }

        // Continuar na tela de status para confirmar manualmente
        break;

      case OrderStatus.cancelled:
        // Mostrar mensagem e opção de voltar ao início
        showLocalNotification(
          title: 'Pedido Cancelado',
          body: 'Seu pedido foi cancelado.',
        );
        break;

      default:
        // Para outros estados, permanecer na tela de status
        break;
    }
  }

  /// Determina para onde o entregador deve navegar com base no status do pedido
  static void navigateDriverBasedOnStatus(
    BuildContext context,
    Order order, {
    bool justDelivered = false,
    bool justCancelled = false,
  }) {
    switch (order.status) {
      case OrderStatus.delivered:
        if (justDelivered) {
          showLocalNotification(
            title: 'Entrega Confirmada',
            body: 'O pedido foi marcado como entregue com sucesso.',
          );
        }

        // Não navegar automaticamente, mostrar tela de sucesso
        // e permitir que o entregador decida quando voltar
        break;

      case OrderStatus.cancelled:
        if (justCancelled) {
          showLocalNotification(
            title: 'Pedido Cancelado',
            body: 'O pedido foi cancelado com sucesso.',
          );
          context.go('/entregador/delivery_orderslist');
        }
        break;

      default:
        // Para outros estados, permanecer na tela
        break;
    }
  }

  /// Mostra um diálogo de auto-finalização para o cliente
  static void _showAutoFinalizationDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.75),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFF6A00), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, color: Color(0xFFFF6A00), size: 40),
              const SizedBox(height: 16),
              const Text(
                'Pedido Auto-Finalizado',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'O entregador marcou sua entrega como finalizada há 5 minutos. Você recebeu sua encomenda?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botão NÃO - Reportar problema
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/cliente/client_support',
                          extra: {'orderId': order.id});
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Não',
                        style: TextStyle(color: Colors.white)),
                  ),

                  // Botão SIM - Confirmar recebimento
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/cliente/client_ordersummary',
                          extra: {'orderId': order.id});
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Sim',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
