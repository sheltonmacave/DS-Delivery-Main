import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

/// Serviço especializado para lidar com a finalização de pedidos
/// Centraliza todas as regras de negócio relacionadas à finalização
class OrderCompletionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Marca um pedido como entregue pelo entregador
  /// - Define o timestamp de auto-finalização (5 minutos no futuro)
  /// - Registra todas as informações relevantes sobre a entrega
  Future<void> markAsDelivered(String orderId, String driverId) async {
    try {
      // Buscar pedido atual para validar estado
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Pedido não encontrado');
      }

      final orderData = orderDoc.data()!;
      final currentStatus = orderData['status'] as int? ?? 0;

      // Validar status atual (deve estar em trânsito)
      if (currentStatus != OrderStatus.inTransit.index) {
        throw Exception('Status inválido para marcar como entregue');
      }

      // Validar entregador
      if (orderData['driverId'] != driverId) {
        throw Exception('Entregador não autorizado para esta ação');
      }

      // Criar timestamp de auto-finalização (5 minutos no futuro)
      final autoCompletionTime = DateTime.now().add(const Duration(minutes: 5));

      // Criar um timestamp atual para usar no objeto statusUpdate
      final now = DateTime.now().toIso8601String();

      // Registrar entrega com timestamp manual em vez de serverTimestamp
      final statusUpdate = {
        'status': OrderStatus.delivered.index,
        'timestamp': now,
        'description': 'Pedido entregue pelo entregador',
      };

      // Atualizar pedido diretamente para evitar problemas com a transação
      await _firestore.collection('orders').doc(orderId).update({
        'status': OrderStatus.delivered.index,
        'statusUpdates': FieldValue.arrayUnion([statusUpdate]),
        'autoCompletionAt': autoCompletionTime.toIso8601String(),
        'deliveryConfirmationTime':
            now, // Usando string ISO em vez de serverTimestamp
        'autoCompleted': false,
        'manuallyConfirmed': false,
      });

      // Registrar log de ação (não impede o fluxo principal)
      try {
        final logTimestamp = DateTime.now().toIso8601String();
        await _firestore.collection('delivery_logs').add({
          'orderId': orderId,
          'driverId': driverId,
          'action': 'mark_as_delivered',
          'timestamp':
              logTimestamp, // Usando string ISO em vez de serverTimestamp
        });
      } catch (logError) {
        // Log do erro mas não interrompe o fluxo
        print('Erro ao registrar log de entrega: $logError');
      }
    } catch (e) {
      print('Erro ao marcar como entregue: $e');
      rethrow;
    }
  }

  /// Confirma o recebimento manualmente pelo cliente
  /// - Define manuallyConfirmed como true
  /// - Registra a confirmação explícita do cliente
  Future<void> confirmDeliveryByClient(String orderId, String clientId) async {
    try {
      print(
          'Debug - Iniciando confirmação de entrega para pedido: $orderId por cliente: $clientId');

      // Buscar pedido atual
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderDoc = await orderRef.get();

      if (!orderDoc.exists) {
        print('Debug - Pedido não encontrado: $orderId');
        throw Exception('Pedido não encontrado');
      }

      final orderData = orderDoc.data()!;
      print(
          'Debug - Dados do pedido recuperados: ${orderData.keys.join(', ')}');

      // Validar cliente
      final String docClientId = orderData['clientId'] as String? ?? '';
      print(
          'Debug - Cliente do pedido: $docClientId, cliente solicitante: $clientId');

      if (docClientId != clientId) {
        print(
            'Debug - Cliente não autorizado. Esperado: $docClientId, Recebido: $clientId');
        throw Exception('Cliente não autorizado para esta ação');
      }

      // Validar status (deve estar entregue ou em trânsito)
      final int currentStatus = orderData['status'] as int? ?? 0;

      // Imprimir informações de debug
      print('Debug - Status atual do pedido: $currentStatus');
      print('Debug - Status entregue: ${OrderStatus.delivered.index}');
      print('Debug - Status em trânsito: ${OrderStatus.inTransit.index}');

      // Permitir confirmação em estados de trânsito ou entregue
      if (currentStatus != OrderStatus.delivered.index &&
          currentStatus != OrderStatus.inTransit.index) {
        print('Debug - Status inválido para confirmação: $currentStatus');
        throw Exception(
            'Pedido não está pronto para confirmação (status atual: $currentStatus)');
      }

      // Criar um timestamp atual para usar consistentemente
      final now = DateTime.now().toIso8601String();

      // Atualizar com confirmação do cliente e finalizar o pedido
      await _firestore.collection('orders').doc(orderId).update({
        'status': OrderStatus.delivered.index, // Confirma status como entregue
        'manuallyConfirmed': true,
        'clientConfirmationTime':
            now, // Usando string ISO em vez de serverTimestamp
        'completionTime': now, // Usando string ISO em vez de serverTimestamp
        // Adiciona registro de atualização de status com timestamp manual
        'statusUpdates': FieldValue.arrayUnion([
          {
            'status': OrderStatus.delivered.index,
            'timestamp': now,
            'description': 'Entrega confirmada pelo cliente',
          }
        ]),
      });

      // Registrar log
      try {
        final logTimestamp = DateTime.now().toIso8601String();
        await _firestore.collection('delivery_logs').add({
          'orderId': orderId,
          'clientId': clientId,
          'action': 'confirm_delivery',
          'timestamp':
              logTimestamp, // Usando string ISO em vez de serverTimestamp
        });
      } catch (logError) {
        // Log do erro mas não interrompe o fluxo
        print('Erro ao registrar log de confirmação: $logError');
      }
    } catch (e) {
      print('Erro ao confirmar recebimento: $e');
      throw Exception('erro ao atualizar status: $e');
    }
  }

  /// Auto-finaliza o pedido quando o cliente não confirmou no prazo
  /// - Chamado automaticamente após o período de auto-finalização
  /// - Define autoCompleted como true
  Future<void> autoCompleteOrder(String orderId) async {
    try {
      // Buscar pedido atual
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Pedido não encontrado');
      }

      final orderData = orderDoc.data()!;

      // Validar status (deve estar entregue ou em trânsito)
      final int currentStatus = orderData['status'] as int? ?? 0;

      // Permite confirmar em estados de trânsito ou entregue
      if (currentStatus != OrderStatus.delivered.index &&
          currentStatus != OrderStatus.inTransit.index) {
        throw Exception(
            'Pedido não está pronto para auto-finalização (status atual: $currentStatus)');
      }

      // Verificar se já foi confirmado manualmente
      if (orderData['manuallyConfirmed'] == true) {
        return; // Não faz nada se já foi confirmado manualmente
      }

      // Verificar se auto-completion já foi executada
      if (orderData['autoCompleted'] == true) {
        return; // Não faz nada se já foi auto-finalizado
      }

      // Criar um timestamp atual para usar consistentemente
      final now = DateTime.now().toIso8601String();

      // Atualizar pedido como auto-finalizado
      await _firestore.collection('orders').doc(orderId).update({
        'status': OrderStatus.delivered.index, // Confirma status como entregue
        'autoCompleted': true,
        'completionTime': now, // Usando string ISO em vez de serverTimestamp
        // Adiciona registro de atualização de status com timestamp manual
        'statusUpdates': FieldValue.arrayUnion([
          {
            'status': OrderStatus.delivered.index,
            'timestamp': now,
            'description': 'Entrega auto-finalizada pelo sistema',
          }
        ]),
      });

      // Registrar log
      try {
        final logTimestamp = DateTime.now().toIso8601String();
        await _firestore.collection('delivery_logs').add({
          'orderId': orderId,
          'action': 'auto_complete',
          'timestamp':
              logTimestamp, // Usando string ISO em vez de serverTimestamp
        });
      } catch (logError) {
        // Log do erro mas não interrompe o fluxo
        print('Erro ao registrar log de auto-finalização: $logError');
      }
    } catch (e) {
      print('Erro ao auto-finalizar pedido: $e');
      // Não propaga erro para não afetar fluxo do app
    }
  }

  /// Reporta problema com entrega quando o cliente nega recebimento
  /// - Registra a reclamação do cliente
  /// - Redireciona para suporte
  Future<void> reportDeliveryIssue(
      String orderId, String clientId, String reason) async {
    try {
      // Buscar pedido atual
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Pedido não encontrado');
      }

      final orderData = orderDoc.data()!;

      // Validar cliente
      if (orderData['clientId'] != clientId) {
        throw Exception('Cliente não autorizado para esta ação');
      }

      // Criar timestamp para uso consistente
      final reportTimestamp = DateTime.now().toIso8601String();

      // Criar relatório de problema
      await _firestore.collection('delivery_issues').add({
        'orderId': orderId,
        'clientId': clientId,
        'reason': reason,
        'resolved': false,
        'reportedAt':
            reportTimestamp, // Usando string ISO em vez de serverTimestamp
        'orderStatus': orderData['status'],
      });

      // Atualizar pedido com flag de problema reportado
      await _firestore.collection('orders').doc(orderId).update({
        'issueReported': true,
        'issueReportTime':
            reportTimestamp, // Usando string ISO em vez de serverTimestamp
      });
    } catch (e) {
      print('Erro ao reportar problema com entrega: $e');
      rethrow;
    }
  }

  /// Verifica se um pedido pode ser finalizado manualmente pelo cliente
  Future<bool> canClientFinalize(String orderId, String clientId) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        return false;
      }

      final orderData = orderDoc.data()!;

      // Validar cliente
      if (orderData['clientId'] != clientId) {
        return false;
      }

      // Verificar status (deve estar entregue)
      if (orderData['status'] != OrderStatus.delivered.index) {
        return false;
      }

      // Verificar se já foi confirmado ou auto-finalizado
      if (orderData['manuallyConfirmed'] == true ||
          orderData['autoCompleted'] == true) {
        return false;
      }

      return true;
    } catch (e) {
      print('Erro ao verificar possibilidade de finalização: $e');
      return false;
    }
  }
}
