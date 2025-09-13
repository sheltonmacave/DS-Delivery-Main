import 'package:ds_delivery/widgets/countdown_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/notifications_service.dart';
import '../../services/order_completion_service.dart';
import '../../utils/order_state_navigator.dart';
import 'package:ds_delivery/wrappers/back_handler.dart';

class DeliveryOrderStatePage extends StatefulWidget {
  final String orderId;

  const DeliveryOrderStatePage({super.key, required this.orderId});

  @override
  State<DeliveryOrderStatePage> createState() => _DeliveryOrderStatePageState();
}

class _DeliveryOrderStatePageState extends State<DeliveryOrderStatePage> {
  final Color highlightColor = const Color(0xFFFF6A00);
  final OrderService _orderService = OrderService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _isLoadingRoute = true;
  bool _isUpdatingStatus = false;
  DateTime? _lastButtonPress; // Para evitar cliques múltiplos muito rápidos

  // API Key para Google Directions
  static const String googleAPIKey = 'AIzaSyCNlTXTSlKc2cCyGbWKqKCIkRN4JMiY1tQ';

  // Estilo escuro para o mapa
  static const String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#212121"}]
    },
    {
      "elementType": "labels.icon",
      "stylers": [{"visibility": "off"}]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#757575"}]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#212121"}]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry",
      "stylers": [{"color": "#757575"}]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#616161"}]
    },
    {
      "featureType": "poi.business",
      "stylers": [{"visibility": "on"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#383838"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#212121"}]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#8a8a8a"}]
    },
    {
      "featureType": "transit",
      "elementType": "geometry",
      "stylers": [{"color": "#2f3948"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#000000"}]
    }
  ]
  ''';

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // Método para obter e desenhar a rota
  Future<void> _fetchRouteAndUpdateMap(Order order) async {
    if (_mapController == null) return;

    setState(() => _isLoadingRoute = true);
    _markers = {};
    _polylines = {};

    // Adicionar marcadores de origem e destino
    final originLocation =
        LatLng(order.originLocation.latitude, order.originLocation.longitude);

    final destinationLocation = LatLng(order.destinationLocation.latitude,
        order.destinationLocation.longitude);

    _markers.add(Marker(
      markerId: const MarkerId('origin'),
      position: originLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      infoWindow: InfoWindow(title: 'Origem', snippet: order.originAddress),
    ));

    _markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: destinationLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow:
          InfoWindow(title: 'Destino', snippet: order.destinationAddress),
    ));

    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${originLocation.latitude},${originLocation.longitude}'
          '&destination=${destinationLocation.latitude},${destinationLocation.longitude}'
          '&key=$googleAPIKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final points = data['routes'][0]['overview_polyline']['points'];
          final polylinePoints = PolylinePoints().decodePolyline(points);

          final List<LatLng> polylineCoordinates = polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                color: highlightColor,
                points: polylineCoordinates,
                width: 5,
              ),
            );
            _isLoadingRoute = false;
          });

          // Ajustar o mapa para mostrar toda a rota
          _fitMapToRoute(polylineCoordinates);
        } else {
          _createStraightLine(originLocation, destinationLocation);
        }
      } else {
        _createStraightLine(originLocation, destinationLocation);
      }
    } catch (e) {
      print('Erro ao buscar rota: $e');
      _createStraightLine(originLocation, destinationLocation);
    }
  }

  // Criar uma linha reta em caso de falha
  void _createStraightLine(LatLng origin, LatLng destination) {
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: highlightColor,
          points: [origin, destination],
          width: 5,
        ),
      );
      _isLoadingRoute = false;
    });

    _fitMapToRoute([origin, destination]);
  }

  // Ajustar o mapa para mostrar toda a rota
  Future<void> _fitMapToRoute(List<LatLng> points) async {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    final padding = MediaQuery.of(context).size.width * 0.25;

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        padding,
      ),
    );
  }

  void _showCancelConfirmation(Order order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.red, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.cancel,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Cancelar Entrega',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tens certeza que queres cancelar esta entrega? Esta ação não pode ser desfeita.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Não, voltar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  FilledButton(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await _cancelOrder(order);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Sim, cancelar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Atualizar status do pedido
  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    // Verificar se há um botão pressionado recentemente para evitar múltiplos cliques
    final now = DateTime.now();
    if (_lastButtonPress != null &&
        now.difference(_lastButtonPress!).inMilliseconds < 2000) {
      return; // Ignora cliques muito rápidos (menos de 2 segundos)
    }
    _lastButtonPress = now;

    if (_isUpdatingStatus) return; // Evita múltiplas chamadas simultâneas

    try {
      setState(() => _isUpdatingStatus = true);

      // Lógica especial para marcar como entregue
      if (newStatus == OrderStatus.delivered) {
        // Usar o serviço especializado para finalização
        final completionService = OrderCompletionService();
        await completionService.markAsDelivered(
            order.id!, _auth.currentUser!.uid);
      } else {
        // Para outros status, usar o fluxo normal
        await _orderService.updateOrderStatus(order.id!, newStatus);
      }

      // Enviar notificação ao cliente (sem interromper o fluxo se falhar)
      try {
        final statusDesc = _getStatusDescription(newStatus);
        await _orderService.notifyClient(order.id!, 'Atualização do Pedido',
            'O status do seu pedido foi atualizado para: $statusDesc');

        // Notificação local para o entregador
        showLocalNotification(
          title: 'Pedido Atualizado',
          body: 'Status do pedido atualizado para: $statusDesc',
        );
      } catch (notificationError) {
        // Log do erro mas não interrompe o processo principal
        print('Erro ao enviar notificação: $notificationError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == OrderStatus.delivered
                ? 'Entrega finalizada com sucesso!'
                : 'Status atualizado com sucesso'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navegação baseada no novo status
        if (mounted) {
          // Importar o OrderStateNavigator na parte superior do arquivo
          // import '../utils/order_state_navigator.dart';
          OrderStateNavigator.navigateDriverBasedOnStatus(
            context,
            order.copyWith(status: newStatus),
            justDelivered: newStatus == OrderStatus.delivered,
          );
        }
      }
    } catch (e) {
      print('Erro real ao atualizar status: $e');
      if (mounted) {
        // Só mostra erro se realmente for um erro de atualização
        if (!e.toString().contains('Success') &&
            !e.toString().contains('success')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Erro ao atualizar status: ${e.toString().split(']').last}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _cancelOrder(Order order) async {
    if (_isUpdatingStatus) return;

    setState(() => _isUpdatingStatus = true);

    try {
      await _orderService.updateOrderStatus(
        order.id!,
        OrderStatus.cancelled,
      );

      // Notificar cliente (sem interromper o fluxo se falhar)
      try {
        await _orderService.notifyClient(
          order.id!,
          'Entrega Cancelada',
          'A sua entrega foi cancelada pelo entregador.',
        );

        // Notificação local para o entregador
        showLocalNotification(
          title: 'Entrega Cancelada',
          body: 'A entrega foi cancelada com sucesso.',
        );
      } catch (notificationError) {
        print('Erro ao enviar notificação de cancelamento: $notificationError');
      }

      // Navegar baseado no estado
      if (mounted) {
        OrderStateNavigator.navigateDriverBasedOnStatus(
            context, order.copyWith(status: OrderStatus.cancelled),
            justCancelled: true);
      }
    } catch (e) {
      print('Erro real ao cancelar pedido: $e');
      if (mounted) {
        // Só mostra erro se realmente for um erro de cancelamento
        if (!e.toString().contains('Success') &&
            !e.toString().contains('success')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Erro ao cancelar pedido: ${e.toString().split(']').last}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  // Método para obter descrição do status
  String _getStatusDescription(OrderStatus status) {
    switch (status) {
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
        return 'Pendente';
    }
  }

  // Contactar cliente
  void _contactClient(String phoneNumber) async {
    final url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível fazer a chamada')),
        );
      }
    }
  }

  // Enviar mensagem ao cliente
  void _sendMessageToClient(String clientId) {
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID do cliente não disponível'),
        ),
      );
      return;
    }

    // Navegar para o chat com o cliente
    context.go('/entregador/delivery_chat', extra: {
      'recipientId': clientId,
      'orderId': widget.orderId,
    });
  }

  // Método para construir a AppBar de forma organizada
  PreferredSizeWidget _buildAppBar(Order order) {
    final bool isCompleted = order.status == OrderStatus.delivered ||
        order.status == OrderStatus.cancelled;

    return AppBar(
      backgroundColor: Colors.black.withOpacity(0.6),
      elevation: 0,
      centerTitle: true,
      // Mostrar botão de voltar sempre, mas com comportamento diferente
      // baseado no status do pedido
      leading: IconButton(
        icon: const Icon(Symbols.arrow_back_ios, color: Colors.white),
        onPressed: () {
          // Se o pedido estiver completo, voltar para a lista
          if (isCompleted) {
            context.go('/entregador/delivery_orderslist');
          } else {
            // Se o pedido estiver ativo, mostrar diálogo de confirmação
            _showLeaveConfirmationDialog(context);
          }
        },
      ),
      title: const Text(
        'Estado do Pedido',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      actions: [
        // Status indicator badge
        if (!isCompleted)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Ativo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

        // Support button
        IconButton(
          icon: const Icon(Symbols.support_agent, color: Color(0xFFFF6A00)),
          onPressed: () => context.go('/entregador/delivery_support',
              extra: {'orderId': widget.orderId}),
        ),
      ],
    );
  }

  // Diálogo para confirmar saída quando o pedido está ativo
  void _showLeaveConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        title: const Text(
          'Sair da Entrega Ativa?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Este pedido ainda está ativo. Se sair agora, ainda será responsável por completá-lo.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ficar', style: TextStyle(color: Colors.white)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/entregador/delivery_orderslist');
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A00),
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          // Garantir que voltamos para a home do entregador e não para a lista de pedidos
          context.go('/entregador/delivery_home');
          return false;
        },
        child: BackHandler(
          alternativeRoute: '/entregador/delivery_home',
          child: Scaffold(
            backgroundColor: const Color(0xFF0F0F0F),
            body: widget.orderId.isEmpty
                ? _buildEmptyOrderIdError()
                : StreamBuilder<Order?>(
                    stream: _orderService.getOrderById(widget.orderId),
                    builder: (context, snapshot) {
                      // Estados de carregamento e erro
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        // Verificar se o erro é crítico ou apenas um problema temporário
                        final error = snapshot.error.toString();
                        final bool isCriticalError =
                            error.contains('permission-denied') ||
                                error.contains('not-found') ||
                                error.contains('unavailable');

                        if (isCriticalError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Symbols.error_outline,
                                      color: Colors.red, size: 64),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Erro ao carregar dados do pedido',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Verifique sua conexão ou tente novamente mais tarde.',
                                    style:
                                        TextStyle(color: Colors.grey.shade400),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                    onPressed: () {
                                      setState(() {}); // Forçar reconstrução
                                    },
                                    icon: const Icon(Symbols.refresh),
                                    label: const Text('Tentar Novamente'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          // Para erros não críticos, apenas loga e continua com loading
                          print('Erro não crítico no StreamBuilder: $error');
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                      }

                      final order = snapshot.data;
                      if (order == null) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.not_listed_location,
                                  color: Colors.amber, size: 64),
                              const SizedBox(height: 16),
                              const Text(
                                'Pedido não encontrado',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: () => context
                                    .go('/entregador/delivery_orderslist'),
                                child: const Text('Voltar para Pedidos'),
                              ),
                            ],
                          ),
                        );
                      }

                      // Se temos os dados do pedido, renderizar a interface
                      // AppBar depende do estado do pedido
                      return Scaffold(
                        backgroundColor: const Color(0xFF0F0F0F),
                        appBar: _buildAppBar(order),
                        body: _buildOrderDetails(order),
                      );
                    },
                  ),
          ),
        ));
  }

  // Novo método para mostrar erro quando ID do pedido está vazio
  Widget _buildEmptyOrderIdError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Symbols.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 24),
            const Text(
              'ID do pedido inválido',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Não foi possível carregar os detalhes do pedido porque o ID está vazio.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/entregador/delivery_orderslist'),
              icon: const Icon(Symbols.view_list),
              label: const Text('Voltar para a lista de pedidos'),
              style: FilledButton.styleFrom(
                backgroundColor: highlightColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails(Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mapa com a rota (agora em primeiro lugar)
          _buildMapCard(order),

          const SizedBox(height: 16),

          // Status atual do pedido (agora em segundo lugar)
          _buildStatusCard(order),

          const SizedBox(height: 16),

          // Informações do cliente
          _buildClientInfoCard(order),

          const SizedBox(height: 16),

          // Detalhes do pedido
          _buildOrderDetailsCard(order),

          const SizedBox(height: 24),

          // Ações disponíveis baseadas no status atual
          _buildActionButtons(order),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Order order) {
    final statusText = _getStatusText(order.status);
    final statusColor = _getStatusColor(order.status);

    // Formatador de data com suporte a diferentes locales
    final formattedDate =
        DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);

    // Data atual formatada para exibição
    final currentDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    List<Widget> statusCardChildren = [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Pedido #${order.id!.substring(0, 4)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Icon(Symbols.calendar_month, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            'Criado em $formattedDate',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Icon(Symbols.update, color: highlightColor, size: 16),
          const SizedBox(width: 8),
          Text(
            'Hora atual: $currentDate',
            style: TextStyle(color: highlightColor, fontSize: 13),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _buildProgressTimeline(order),
    ];

    if (order.status == OrderStatus.delivered) {
      // Check if order has auto-completion time
      if (order.autoCompletionAt != null) {
        final autoCompletionTime = DateTime.parse(order.autoCompletionAt!);
        statusCardChildren.add(const SizedBox(height: 12));
        statusCardChildren.add(OrderCountdownWidget(
          targetTime: autoCompletionTime,
        ));
      }
    }

    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: statusCardChildren,
        ),
      ),
    );
  }

  // Novo método de progresso similar ao do cliente
  Widget _buildProgressTimeline(Order order) {
    // Lista de estados possíveis para exibição
    final List<Map<String, dynamic>> etapas = [
      {
        'status': OrderStatus.driverAssigned,
        'title': 'Entregador Atribuído',
      },
      {
        'status': OrderStatus.pickedUp,
        'title': 'Encomenda Coletada',
      },
      {
        'status': OrderStatus.inTransit,
        'title': 'Entregador a Caminho',
      },
      {
        'status': OrderStatus.delivered,
        'title': 'Encomenda Entregue',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: etapas.asMap().entries.map((entry) {
        int index = entry.key;
        final etapa = entry.value;
        final OrderStatus status = etapa['status'];
        final String title = etapa['title'];

        // Verificar se esta etapa já foi concluída
        final updates = order.statusUpdates
            .where((update) => update.status == status)
            .toList();

        final bool hasUpdate = updates.isNotEmpty;
        final String timeString = hasUpdate
            ? DateFormat('HH:mm:ss').format(updates.first.timestamp)
            : '--:--:--';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(hasUpdate ? Symbols.check_circle : Symbols.circle,
                    color: hasUpdate ? highlightColor : Colors.grey, size: 16),
                if (index != etapas.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: hasUpdate
                        ? highlightColor
                        : Colors.grey.withOpacity(0.3),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: hasUpdate ? Colors.white : Colors.grey,
                    fontWeight: hasUpdate ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                if (hasUpdate && updates.isNotEmpty)
                  Text(
                    'Hora: $timeString',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  )
                else
                  const Text(
                    'Pendente',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            )
          ],
        );
      }).toList(),
    );
  }

  Widget _buildClientInfoCard(Order order) {
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Symbols.person, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Informações do Cliente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),

            // Client info with photo and details
            FutureBuilder<firestore.DocumentSnapshot>(
              future: firestore.FirebaseFirestore.instance
                  .collection('users')
                  .doc(order.clientId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // Get client data or use defaults
                final clientData =
                    snapshot.data?.data() as Map<String, dynamic>?;
                final clientName =
                    order.clientName ?? clientData?['name'] ?? 'Cliente';
                final clientPhone =
                    order.clientPhone ?? clientData?['phone'] ?? '';
                final clientPhoto = clientData?['photoURL'];

                // Client rating (placeholder or actual value if available)
                final clientRating = clientData?['rating'] ?? 5.0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client photo/avatar
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: clientPhoto != null
                          ? NetworkImage(clientPhoto)
                          : null,
                      backgroundColor: Colors.grey.shade800,
                      child: clientPhoto == null
                          ? const Icon(Symbols.person,
                              color: Colors.white54, size: 30)
                          : null,
                    ),
                    const SizedBox(width: 16),

                    // Client details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (clientPhone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              clientPhone,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Symbols.star,
                                  color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                clientRating.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Call and Message buttons
                    Column(
                      children: [
                        if (clientPhone.isNotEmpty)
                          FilledButton.icon(
                            onPressed: () => _contactClient(clientPhone),
                            style: FilledButton.styleFrom(
                              backgroundColor: highlightColor,
                            ),
                            icon: const Icon(Symbols.call, size: 16),
                            label: const Text('Ligar'),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _sendMessageToClient(order.clientId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                          ),
                          icon: const Icon(Symbols.message, size: 16),
                          label: const Text('Mensagem'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard(Order order) {
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Symbols.map, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Rota',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                const SizedBox(height: 4),
                _buildAddressRow(
                  Symbols.location_on,
                  'Origem:',
                  order.originAddress,
                  const Color(0xFFFF6A00),
                ),
                const SizedBox(height: 12),
                _buildAddressRow(
                  Symbols.flag,
                  'Destino:',
                  order.destinationAddress,
                  Colors.green,
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: SizedBox(
              height: 200,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        order.originLocation.latitude,
                        order.originLocation.longitude,
                      ),
                      zoom: 15,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: false,
                    zoomControlsEnabled: true,
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    mapToolbarEnabled: false,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      controller.setMapStyle(_darkMapStyle);
                      _fetchRouteAndUpdateMap(order);
                    },
                  ),
                  if (_isLoadingRoute)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(
      IconData icon, String label, String address, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                address,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetailsCard(Order order) {
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Symbols.info, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Detalhes do Pedido',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            _buildDetailRow('Transporte', order.transportType),
            _buildDetailRow(
                'Distância', '${order.distance.toStringAsFixed(1)} km'),
            _buildDetailRow('Tempo Estimado', order.estimatedTime),
            _buildDetailRow('Valor', '${order.price.toStringAsFixed(0)} MT'),
            if (order.observations != null &&
                order.observations!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Observações:',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.observations!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Order order) {
    // Determinar as ações baseadas no status atual do pedido
    Widget actionButton;

    switch (order.status) {
      case OrderStatus.driverAssigned:
        return Column(
          children: [
            _buildActionButton(
              'Confirmar Coleta',
              Symbols.inventory_2,
              const Color(0xFFFF6A00),
              () => _updateOrderStatus(order, OrderStatus.pickedUp),
            ),
            const SizedBox(height: 16),
            _buildCancelButton(order),
          ],
        );

      case OrderStatus.pickedUp:
        return Column(
          children: [
            _buildActionButton(
              'Iniciar Entrega',
              Symbols.local_shipping,
              Colors.green,
              () => _updateOrderStatus(order, OrderStatus.inTransit),
            ),
            const SizedBox(height: 16),
            _buildCancelButton(order),
          ],
        );

      case OrderStatus.inTransit:
        actionButton = _buildActionButton(
          'Confirmar Entrega',
          Symbols.task_alt,
          Colors.green,
          () => _updateOrderStatus(order, OrderStatus.delivered),
        );
        break;

      case OrderStatus.delivered:
        actionButton = _buildActionButton(
          'Pedido Concluído',
          Symbols.check_circle,
          Colors.green,
          () => context.go('/entregador/delivery_orderslist'),
          isDisabled: true,
        );
        break;

      case OrderStatus.cancelled:
        actionButton = _buildActionButton(
          'Pedido Cancelado',
          Symbols.cancel,
          Colors.red,
          () => context.go('/entregador/delivery_orderslist'),
          isDisabled: true,
        );
        break;

      default:
        actionButton = _buildActionButton(
          'Status Desconhecido',
          Symbols.help_outline,
          Colors.grey,
          () {},
          isDisabled: true,
        );
    }

    return Column(
      children: [
        actionButton,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isDisabled = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isUpdatingStatus || isDisabled ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: _isUpdatingStatus
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon),
        label: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildCancelButton(Order order) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed:
            _isUpdatingStatus ? null : () => _showCancelConfirmation(order),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: const Icon(Symbols.cancel, color: Colors.red),
        label: const Text(
          'Cancelar Entrega',
          style: TextStyle(color: Colors.red, fontSize: 16),
        ),
      ),
    );
  }

  String _getStatusText(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'Pendente',
      OrderStatus.driverAssigned => 'Aguardando coleta',
      OrderStatus.pickedUp => 'Coletado',
      OrderStatus.inTransit => 'Em trânsito',
      OrderStatus.delivered => 'Entregue',
      OrderStatus.cancelled => 'Cancelado'
    };
  }

  Color _getStatusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => Colors.grey,
      OrderStatus.driverAssigned => highlightColor,
      OrderStatus.pickedUp => highlightColor,
      OrderStatus.inTransit => highlightColor,
      OrderStatus.delivered => Colors.green,
      OrderStatus.cancelled => Colors.red
    };
  }
}
