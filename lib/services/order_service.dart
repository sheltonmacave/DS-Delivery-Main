import 'package:cloud_firestore/cloud_firestore.dart'
    hide Order; // Esconde a classe Order do Firestore
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
        print(
            'Erro de permissão no Firestore. Verifique as regras de segurança.');
      }
      throw Exception('Não foi possível criar o pedido: $e');
    }
  }

  // Método para notificar o cliente sobre o status da entrega
  Future<void> notifyClient(
      String orderId, String title, String message) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        print('Pedido não encontrado para notificação: $orderId');
        return; // Não lança exceção, apenas retorna
      }

      final orderData = orderDoc.data()!;
      final clientId = orderData['clientId'];

      if (clientId == null || clientId.isEmpty) {
        print('Cliente ID não encontrado para notificação');
        return; // Não lança exceção, apenas retorna
      }

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

      print('Notificação enviada com sucesso para o cliente');
      // Se você tem FCM implementado, pode enviar uma notificação push aqui
    } catch (e) {
      print('Erro ao notificar cliente: $e');
      // Não relança a exceção para não interromper o fluxo principal
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

  // Obter pedido ativo do cliente atual
  Stream<Order?> getClientActiveOrder() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('orders')
        .where('clientId', isEqualTo: userId)
        .where('status', whereIn: [
          OrderStatus.pending.index,
          OrderStatus.driverAssigned.index,
          OrderStatus.pickedUp.index,
          OrderStatus.inTransit.index
        ])
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          final doc = snapshot.docs.first;
          return Order.fromJson({...doc.data(), 'id': doc.id});
        });
  }

  Stream<List<Order>> getUserCompletedOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('clientId', isEqualTo: userId)
        .where('status',
            whereIn: [OrderStatus.delivered.index, OrderStatus.cancelled.index])
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
  Stream<List<Order>> getAvailableOrders() async* {
    // Obter o tipo de veículo do entregador atual
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      yield [];
      return;
    }

    // Buscar o tipo de veículo do entregador no Firestore
    DocumentSnapshot driverDoc;
    try {
      driverDoc = await _firestore.collection('users').doc(userId).get();
    } catch (e) {
      print('Erro ao buscar dados do entregador: $e');
      yield [];
      return;
    }

    if (!driverDoc.exists) {
      yield [];
      return;
    }

    final driverData = driverDoc.data() as Map<String, dynamic>?;
    final driverVehicleType = driverData?['veiculo']?['tipo'] as String? ?? '';

    // Se não tiver tipo de veículo, não mostrar pedidos
    if (driverVehicleType.isEmpty) {
      yield [];
      return;
    }

    // Obter todos os pedidos pendentes sem entregador
    final ordersStream = _firestore
        .collection('orders')
        .where('status', isEqualTo: OrderStatus.pending.index)
        .where('driverId', isNull: true)
        .snapshots();

    // Filtrar pedidos pelo tipo de transporte compatível
    await for (final snapshot in ordersStream) {
      final allOrders = snapshot.docs
          .map((doc) => Order.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Filtrar pedidos compatíveis com o tipo de veículo do entregador
      final compatibleOrders = allOrders.where((order) {
        // Correspondência exata (Carro com Carro, Motorizada com Motorizada)
        if (order.transportType == driverVehicleType) {
          return true;
        }

        // Entregadores de Carro podem aceitar pedidos de Motorizada
        // (assumindo que Carro é mais versátil que Motorizada)
        if (driverVehicleType == 'Carro' &&
            order.transportType == 'Motorizada') {
          return true;
        }

        return false;
      }).toList();

      yield compatibleOrders;
    }
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

  // Obter pedido ativo do entregador atual
  Stream<Order?> getDriverActiveOrder() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: userId)
        .where('status', whereIn: [
          OrderStatus.driverAssigned.index,
          OrderStatus.pickedUp.index,
          OrderStatus.inTransit.index
        ])
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          final doc = snapshot.docs.first;
          return Order.fromJson({...doc.data(), 'id': doc.id});
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
      final clientId = orderData['clientId'] as String;

      // Verificar se o entregador é o mesmo que criou o pedido
      if (currentUser.uid == clientId) {
        throw Exception('Não é possível aceitar o seu próprio pedido');
      }

      // Verificar se o pedido já foi aceito
      if (status != OrderStatus.pending.index) {
        throw Exception('Este pedido já foi aceito por outro entregador');
      }

      // Transação para evitar conflitos
      await _firestore.runTransaction((transaction) async {
        // Verificar novamente dentro da transação
        final freshOrder =
            await transaction.get(_firestore.collection('orders').doc(orderId));

        if (freshOrder.data()?['status'] != OrderStatus.pending.index) {
          throw Exception('Este pedido já foi aceito por outro entregador');
        }

        // Verificar novamente se o entregador é o mesmo que criou o pedido
        if (freshOrder.data()?['clientId'] == currentUser.uid) {
          throw Exception('Não é possível aceitar o seu próprio pedido');
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
      // Verificar se o pedido existe
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Pedido não encontrado');
      }

      // Create a status update
      final statusUpdate = {
        'status': newStatus.index,
        'timestamp': DateTime.now().toIso8601String(),
        'description': _getStatusDescription(newStatus)
      };

      // Update using atomic operation
      Map<String, dynamic> updateData = {
        'status': newStatus.index,
        'statusUpdates': FieldValue.arrayUnion([statusUpdate]),
      };

      // If status is delivered, set autoCompletionAt time (5 minutes from now)
      if (newStatus == OrderStatus.delivered) {
        final autoCompletionTime =
            DateTime.now().add(const Duration(minutes: 5));
        updateData['autoCompletionAt'] = autoCompletionTime.toIso8601String();
      }

      await _firestore.collection('orders').doc(orderId).update(updateData);

      print(
          'Status atualizado com sucesso para: ${_getStatusDescription(newStatus)}');
    } catch (e) {
      print('Error updating order status: $e');
      // Só lança exceção se for um erro real
      if (e.toString().contains('not-found') ||
          e.toString().contains('permission-denied') ||
          e.toString().contains('unavailable')) {
        throw Exception('Falha ao atualizar status: Verifique sua conexão');
      }
      // Para outros erros, apenas logamos mas não interrompemos o fluxo
      print('Erro não crítico ao atualizar status: $e');
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

  // Confirmar entrega de um pedido manualmente pelo cliente
  Future<void> confirmDelivery(String orderId) async {
    try {
      // Get current order
      final currentOrder = await getOrderByIdOnce(orderId);
      if (currentOrder == null) {
        throw Exception('Pedido não encontrado');
      }

      // Update the order with completion info
      await _firestore.collection('orders').doc(orderId).update({
        'manuallyConfirmed': true,
        'clientConfirmationTime': FieldValue.serverTimestamp(),
        'autoCompleted': false,
      });

      // Notify driver
      if (currentOrder.driverId != null) {
        await notifyDriver(
          currentOrder.driverId!,
          'Entrega confirmada',
          'O cliente confirmou o recebimento do pedido #${orderId.substring(0, 4)}',
        );
      }
    } catch (e) {
      print('Erro ao confirmar entrega: $e');
      rethrow;
    }
  }

  // Marcar pedido como automaticamente finalizado quando o cliente não confirma em 5 minutos
  Future<void> autoCompleteOrder(String orderId) async {
    try {
      final currentOrder = await getOrderByIdOnce(orderId);
      if (currentOrder == null) {
        throw Exception('Pedido não encontrado');
      }

      // Verificar se já foi confirmado manualmente
      if (currentOrder.manuallyConfirmed) {
        return;
      }

      // Update order with auto-completion info
      await _firestore.collection('orders').doc(orderId).update({
        'autoCompleted': true,
        'completionTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erro ao finalizar pedido automaticamente: $e');
      // Não propaga erro para não afetar fluxo do app
    }
  }

  // Método para notificar o entregador sobre o status da entrega
  Future<void> notifyDriver(
      String driverId, String title, String message) async {
    try {
      if (driverId.isEmpty) {
        print('Driver ID vazio para notificação');
        return;
      }

      // Aqui você pode implementar o envio de notificação para o entregador
      // usando FCM ou armazenando a notificação no Firestore

      await _firestore.collection('notifications').add({
        'userId': driverId,
        'title': title,
        'body': message,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Notificação enviada com sucesso para o entregador');
      // Se você tem FCM implementado, pode enviar uma notificação push aqui
    } catch (e) {
      print('Erro ao notificar entregador: $e');
      // Não relança a exceção para não interromper o fluxo principal
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
    }
  }
}
