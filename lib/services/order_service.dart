import 'package:cloud_firestore/cloud_firestore.dart' hide Order; // Esconde a classe Order do Firestore
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Criar um novo pedido
  Future<String> createOrder(Order order) async {
    try {
      print('Tentando criar pedido para usuário: ${order.clientId}');
      print('Dados do pedido: ${order.toJson()}');
      
      final docRef = await _firestore.collection('orders').add(order.toJson());
      print('Pedido criado com ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Erro detalhado ao criar pedido: $e');
      if (e.toString().contains('PERMISSION_DENIED')) {
        print('Erro de permissão no Firestore. Verifique as regras de segurança.');
      }
      throw Exception('Não foi possível criar o pedido: $e');
    }
  }

  // Método para notificar o cliente sobre o status da entrega
  Future<void> notifyClient(String orderId, String title, String message) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Pedido não encontrado');
      }
      
      final orderData = orderDoc.data()!;
      final clientId = orderData['clientId'];
      
      // Aqui você pode implementar o envio de notificação para o cliente
      // usando FCM ou armazenando a notificação no Firestore
      
      await _firestore.collection('notifications').add({
        'userId': clientId,
        'title': title,
        'body': message,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'orderId': orderId,
      });
      
      // Se você tem FCM implementado, pode enviar uma notificação push aqui
    } catch (e) {
      print('Erro ao notificar cliente: $e');
      rethrow;
    }
  }

  // Método para obter pedido por ID (retorna Stream para atualizações em tempo real)
  Stream<Order?> getOrderById(String orderId) {
    return _firestore
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data()!;
          return Order.fromJson({...data, 'id': snapshot.id});
        }
        return null;
      });
  }
  
  // Método para obter pedido por ID uma única vez (não como stream)
  Future<Order?> getOrderByIdOnce(String orderId) async {
    try {
      final docRef = _firestore.collection('orders').doc(orderId);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        return Order.fromJson({...data, 'id': docSnapshot.id});
      }
      return null;
    } catch (e) {
      print('Erro ao buscar pedido: $e');
      rethrow;
    }
  }
  
  // Busca pedidos ativos do cliente de forma robusta
  Future<List<Order>> getClientActiveOrdersOnce(String userId) async {
    try {
      if (userId.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('orders')
          .where('clientId', isEqualTo: userId)
          .where('status', whereNotIn: [
            OrderStatus.delivered.index,
            OrderStatus.cancelled.index
          ])
          .limit(1) // Limitamos a 1 para performance
          .get();
      
      if (snapshot.docs.isEmpty) return [];
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Order.fromJson({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      print('Erro ao buscar pedidos ativos do cliente: $e');
      // Retornar lista vazia em vez de propagar erro
      return [];
    }
  }

  // Busca entregas ativas do entregador com melhor tratamento de erro
  Future<List<Order>> getDriverActiveOrdersOnce(String driverId) async {
    try {
      if (driverId.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('orders')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereNotIn: [
            OrderStatus.delivered.index,
            OrderStatus.cancelled.index
          ])
          .limit(1) // Limitamos a 1 para performance
          .get();
      
      if (snapshot.docs.isEmpty) return [];
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Order.fromJson({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      print('Erro ao buscar entregas ativas do entregador: $e');
      // Retornar lista vazia em vez de propagar erro
      return [];
    }
  }

  // Listar pedidos do cliente atual
  Stream<List<Order>> getClientOrders() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('orders')
        .where('clientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Order.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  Stream<List<Order>> getUserCompletedOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('clientId', isEqualTo: userId)
        .where('status', whereIn: [
          OrderStatus.delivered.index,
          OrderStatus.cancelled.index
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Order.fromJson({...data, 'id': doc.id});
          }).toList();
        });
  }
  
  // In order_service.dart - modify this method
  Future<List<Order>> getDriverCompletedOrdersOnce(String driverId) async {
    try {
      if (driverId.isEmpty) return [];
      
      // Simplified query that doesn't require complex indexes
      // We get all orders for the driver first, then filter in memory
      final snapshot = await _firestore
          .collection('orders')
          .where('driverId', isEqualTo: driverId)
          .get();
      
      if (snapshot.docs.isEmpty) return [];
      
      // Filter completed/cancelled orders in application code instead of in the query
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return Order.fromJson({...data, 'id': doc.id});
          })
          .where((order) => 
              order.status == OrderStatus.delivered || 
              order.status == OrderStatus.cancelled)
          .toList()
          // Sort in memory instead of in the query
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Erro ao buscar histórico do entregador: $e');
      return [];
    }
  }

  // Listar pedidos para entregadores disponíveis
  Stream<List<Order>> getAvailableOrders() {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.pending.index)
        .where('driverId', isNull: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Order.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  // Listar pedidos do entregador atual
  Stream<List<Order>> getDriverOrders() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Order.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  // Método mais robusto para aceitar pedidos
  Future<void> acceptOrder(String orderId) async {
    try {
      if (orderId.isEmpty) {
        throw Exception('ID do pedido inválido');
      }
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Usuário não autenticado');
      }
      
      // Verificar se o pedido existe e está disponível
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Pedido não encontrado');
      }
      
      final orderData = orderDoc.data()!;
      final status = orderData['status'] as int;
      
      // Verificar se o pedido já foi aceito
      if (status != OrderStatus.pending.index) {
        throw Exception('Este pedido já foi aceito por outro entregador');
      }
      
      // Transação para evitar conflitos
      await _firestore.runTransaction((transaction) async {
        // Verificar novamente dentro da transação
        final freshOrder = await transaction.get(_firestore.collection('orders').doc(orderId));
        if (freshOrder.data()?['status'] != OrderStatus.pending.index) {
          throw Exception('Este pedido já foi aceito por outro entregador');
        }
        
        // Atualizar pedido com o ID do entregador
        transaction.update(_firestore.collection('orders').doc(orderId), {
          'driverId': currentUser.uid,
          'status': OrderStatus.driverAssigned.index,
          'statusUpdates': FieldValue.arrayUnion([
            {
              'status': OrderStatus.driverAssigned.index,
              'timestamp': DateTime.now().toIso8601String(),
              'description': 'Entregador atribuído ao pedido'
            }
          ])
        });
      });
      
      return;
    } catch (e) {
      print('Erro ao aceitar pedido: $e');
      rethrow;
    }
  }

  // Método para atualizar o status de um pedido
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      final statusUpdate = StatusUpdate(
        status: newStatus,
        timestamp: DateTime.now(),
        description: 'Status atualizado para ${_getStatusDescription(newStatus)}',
      );

      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus.index,
        'statusUpdates': FieldValue.arrayUnion([statusUpdate.toJson()]),
      });
    } catch (e) {
      print('Erro ao atualizar status: $e');
      throw Exception('Não foi possível atualizar o status do pedido: $e');
    }
  }

  // Cancelar um pedido
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    try {
      final statusUpdate = StatusUpdate(
        status: OrderStatus.cancelled,
        timestamp: DateTime.now(),
        description: reason ?? 'Pedido cancelado pelo cliente',
      );

      await _firestore.collection('orders').doc(orderId).update({
        'status': OrderStatus.cancelled.index,
        'statusUpdates': FieldValue.arrayUnion([statusUpdate.toJson()]),
      });
    } catch (e) {
      print('Erro ao cancelar pedido: $e');
      throw Exception('Não foi possível cancelar o pedido');
    }
  }

  // Confirmar entrega de um pedido
  Future<void> confirmDelivery(String orderId) async {
    try {
      final statusUpdate = StatusUpdate(
        status: OrderStatus.delivered,
        timestamp: DateTime.now(),
        description: 'Cliente confirmou a entrega',
      );

      await _firestore.collection('orders').doc(orderId).update({
        'status': OrderStatus.delivered.index,
        'statusUpdates': FieldValue.arrayUnion([statusUpdate.toJson()]),
      });
    } catch (e) {
      print('Erro ao confirmar entrega: $e');
      throw Exception('Não foi possível confirmar a entrega');
    }
  }
  
  // Método auxiliar para obter descrição de status
  String _getStatusDescription(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pendente';
      case OrderStatus.driverAssigned:
        return 'Entregador atribuído';
      case OrderStatus.pickedUp:
        return 'Pedido coletado';
      case OrderStatus.inTransit:
        return 'Em trânsito';
      case OrderStatus.delivered:
        return 'Entregue';
      case OrderStatus.cancelled:
        return 'Cancelado';
      default:
        return 'Status desconhecido';
    }
  }
}