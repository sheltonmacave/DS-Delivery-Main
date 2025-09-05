import 'package:flutter/material.dart';
// Esconde apenas a classe Order do Firestore
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/notifications_service.dart';

class DeliveryOrderStatePage extends StatefulWidget {
  final String orderId;

  const DeliveryOrderStatePage({super.key, required this.orderId});

  @override
  State<DeliveryOrderStatePage> createState() => _DeliveryOrderStatePageState();
}

class _DeliveryOrderStatePageState extends State<DeliveryOrderStatePage> {
  final Color highlightColor = const Color(0xFFFF6A00);
  final OrderService _orderService = OrderService();
  
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _isLoadingRoute = true;
  bool _isUpdatingStatus = false;
  
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
    final originLocation = LatLng(
      order.originLocation.latitude, 
      order.originLocation.longitude
    );
    
    final destinationLocation = LatLng(
      order.destinationLocation.latitude,
      order.destinationLocation.longitude
    );
    
    _markers.add(
      Marker(
        markerId: const MarkerId('origin'),
        position: originLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: 'Origem', snippet: order.originAddress),
      )
    );
    
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: destinationLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Destino', snippet: order.destinationAddress),
      )
    );
    
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${originLocation.latitude},${originLocation.longitude}'
        '&destination=${destinationLocation.latitude},${destinationLocation.longitude}'
        '&key=$googleAPIKey'
      );
      
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

  // Atualizar status do pedido
  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    try {
      setState(() => _isUpdatingStatus = true);
      
      await _orderService.updateOrderStatus(order.id!, newStatus);
      
      // Enviar notificação ao cliente
      final statusDesc = _getStatusDescription(newStatus);
      await _orderService.notifyClient(
        order.id!,
        'Atualização do Pedido',
        'O status do seu pedido foi atualizado para: $statusDesc'
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status atualizado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Notificação para o entregador também
        showLocalNotification(
          title: 'Pedido Atualizado',
          body: 'Status do pedido atualizado para: $statusDesc',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar status: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.6),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_ios, color: Colors.white),
          onPressed: () => context.go('/entregador/delivery_orderslist'),
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
          IconButton(
            icon: const Icon(Symbols.help_outline, color: Colors.white),
            onPressed: () => context.go('/entregador/delivery_support', extra: {'orderId': widget.orderId}),
          ),
        ],
      ),
      body: StreamBuilder<Order?>(
        stream: _orderService.getOrderById(widget.orderId),
        builder: (context, snapshot) {
          // Estados de carregamento e erro
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.error_outline, color: Colors.red, size: 64),
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
                      'Verifique sua conexão ou tente novamente mais tarde.\n${snapshot.error}',
                      style: TextStyle(color: Colors.grey.shade400),
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
          }
          
          final order = snapshot.data;
          if (order == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.not_listed_location, color: Colors.amber, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Pedido não encontrado',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/entregador/delivery_orderslist'),
                    child: const Text('Voltar para Pedidos'),
                  ),
                ],
              ),
            );
          }
          
          // Se temos os dados do pedido, renderizar a interface
          return _buildOrderDetails(order);
        },
      ),
    );
  }

  Widget _buildOrderDetails(Order order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status atual do pedido
          _buildStatusCard(order),
          
          const SizedBox(height: 16),
          
          // Informações do cliente
          _buildClientInfoCard(order),
          
          const SizedBox(height: 16),
          
          // Mapa com a rota
          _buildMapCard(order),
          
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
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm')
        .format(order.createdAt);
    
    // Data atual formatada para exibição
    final currentDate = DateFormat('dd/MM/yyyy HH:mm')
        .format(DateTime.now());
    
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
            
            // Hora atual (para referência do entregador)
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
            
            // Progresso visual do pedido
            const SizedBox(height: 24),
            _buildOrderProgress(order.status),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderProgress(OrderStatus status) {
    final int currentStep = status.index - 1; // -1 porque começamos em "Aguardando" (index 1)
    
    return Row(
      children: [
        _buildProgressStep(0, currentStep >= 0, "Atribuído"),
        _buildProgressLine(currentStep >= 1),
        _buildProgressStep(1, currentStep >= 1, "Coletado"),
        _buildProgressLine(currentStep >= 2),
        _buildProgressStep(2, currentStep >= 2, "Em Trânsito"),
        _buildProgressLine(currentStep >= 3),
        _buildProgressStep(3, currentStep >= 3, "Entregue"),
      ],
    );
  }
  
  Widget _buildProgressStep(int step, bool isActive, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? highlightColor : Colors.grey.shade800,
              border: Border.all(
                color: isActive ? highlightColor : Colors.grey.shade600,
                width: 2,
              ),
            ),
            child: isActive
                ? const Icon(Symbols.check, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? highlightColor : Colors.grey.shade800,
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.clientName ?? 'Cliente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (order.clientPhone != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          order.clientPhone!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
                if (order.clientPhone != null)
                  FilledButton.icon(
                    onPressed: () => _contactClient(order.clientPhone!),
                    style: FilledButton.styleFrom(
                      backgroundColor: highlightColor,
                    ),
                    icon: const Icon(Symbols.call, size: 16),
                    label: const Text('Ligar'),
                  ),
              ],
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
                  Colors.orange,
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
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
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
                    zoomControlsEnabled: false,
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

  Widget _buildAddressRow(IconData icon, String label, String address, Color iconColor) {
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
            _buildDetailRow('Distância', '${order.distance.toStringAsFixed(1)} km'),
            _buildDetailRow('Tempo Estimado', order.estimatedTime),
            _buildDetailRow('Valor', '${order.price.toStringAsFixed(0)} MT'),
            
            if (order.observations != null && order.observations!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Observações:',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
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
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
        actionButton = _buildActionButton(
          'Confirmar Coleta',
          Symbols.inventory_2,
          Colors.orange,
          () => _updateOrderStatus(order, OrderStatus.pickedUp),
        );
        break;
        
      case OrderStatus.pickedUp:
        actionButton = _buildActionButton(
          'Iniciar Entrega',
          Symbols.local_shipping,
          Colors.green,
          () => _updateOrderStatus(order, OrderStatus.inTransit),
        );
        break;
        
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
        if (order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled)
          OutlinedButton.icon(
            onPressed: _isUpdatingStatus ? null : () => _showCancelDialog(order),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Symbols.warning),
            label: const Text('Reportar Problema'),
          ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _showCancelDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Reportar Problema',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tem certeza que deseja reportar um problema com este pedido? Um agente de suporte entrará em contato.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/entregador/delivery_support', extra: {'orderId': order.id});
            },
            style: FilledButton.styleFrom(backgroundColor: highlightColor),
            child: const Text('Continuar'),
          ),
        ],
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
      OrderStatus.driverAssigned => Colors.orange,
      OrderStatus.pickedUp => Colors.green,
      OrderStatus.inTransit => highlightColor,
      OrderStatus.delivered => Colors.green,
      OrderStatus.cancelled => Colors.red
    };
  }
}