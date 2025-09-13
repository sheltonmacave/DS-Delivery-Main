import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notifications_service.dart';
import '../../services/order_service.dart';
import '../../models/order_model.dart' as ds_order;
import 'package:ds_delivery/wrappers/back_handler.dart';

class DeliveryOrdersListPage extends StatefulWidget {
  const DeliveryOrdersListPage({super.key});

  @override
  State<DeliveryOrdersListPage> createState() => _DeliveryOrdersListPageState();
}

class _DeliveryOrdersListPageState extends State<DeliveryOrdersListPage> {
  final Color highlightColor = const Color(0xFFFF6A00);
  int _currentIndex = 1;
  final OrderService _orderService = OrderService();
  ds_order.Order? _activeOrder;
  bool _isLoadingActiveOrder = true;
  bool _showActiveOrderOverlay = true;

  // Para o min()
  int min(int a, int b) {
    return a < b ? a : b;
  }

  // Controladores e estados para o Google Maps no bottom sheet
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;

  // API key para Google Directions
  static const String googleAPIKey = 'AIzaSyCNlTXTSlKc2cCyGbWKqKCIkRN4JMiY1tQ';

  // Estilo do mapa escuro para Google Maps
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
  void initState() {
    super.initState();

    // Verificar se há uma entrega ativa
    _orderService.getDriverActiveOrder().listen((order) {
      if (mounted) {
        setState(() {
          _activeOrder = order;
          _isLoadingActiveOrder = false;

          // Não redireciona mais automaticamente, apenas mostra o card
        });
      }
    }, onError: (error) {
      debugPrint('Erro ao buscar entrega ativa: $error');
      if (mounted) {
        setState(() {
          _isLoadingActiveOrder = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go('/entregador/delivery_history');
        break;
      case 1:
        context.go('/entregador/delivery_orderslist');
        break;
      case 2:
        context.go('/entregador/delivery_home');
        break;
      case 3:
        context.go('/entregador/delivery_profile');
        break;
    }
  }

  // Método para buscar e desenhar rota no mapa
  Future<void> _fetchRouteForOrder(LatLng origin, LatLng destination) async {
    setState(() {
      _isLoadingRoute = true;
      _polylines = {}; // Limpar rotas anteriores
    });

    try {
      final url =
          Uri.parse('https://maps.googleapis.com/maps/api/directions/json'
              '?origin=${origin.latitude},${origin.longitude}'
              '&destination=${destination.latitude},${destination.longitude}'
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

          if (mounted) {
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

            // Ajustar zoom para mostrar a rota completa
            if (_mapController != null && polylineCoordinates.isNotEmpty) {
              _fitBoundsToRoute(polylineCoordinates);
            }
          }
        } else {
          print("API respondeu, mas com status: ${data['status']}");
          _createStraightLine(origin, destination);
        }
      } else {
        print("Erro na requisição: ${response.statusCode}");
        _createStraightLine(origin, destination);
      }
    } catch (e) {
      print("Exceção ao buscar rota: $e");
      _createStraightLine(origin, destination);
    }
  }

  // Cria uma linha reta quando falha ao buscar a rota
  void _createStraightLine(LatLng origin, LatLng destination) {
    if (mounted) {
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('straight_route'),
            color: highlightColor,
            points: [origin, destination],
            width: 5,
          ),
        );
        _isLoadingRoute = false;
      });

      // Ajustar zoom para mostrar ambos os pontos
      if (_mapController != null) {
        _fitBoundsToRoute([origin, destination]);
      }
    }
  }

  // Ajusta o zoom do mapa para mostrar toda a rota
  Future<void> _fitBoundsToRoute(List<LatLng> points) async {
    if (points.isEmpty) return;

    try {
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

      await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01), // Adicionar margem
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        50, // padding
      ));
    } catch (e) {
      print('Erro ao ajustar zoom: $e');
    }
  }

  void _showOrderDetails(ds_order.Order order) {
    // Limpar estado anterior
    _markers = {};
    _polylines = {};
    _isLoadingRoute = false;

    final originLocation = LatLng(
      order.originLocation.latitude,
      order.originLocation.longitude,
    );

    final destinationLocation = LatLng(
      order.destinationLocation.latitude,
      order.destinationLocation.longitude,
    );

    // Adicionar marcadores
    _markers = {
      Marker(
        markerId: const MarkerId('origin'),
        position: originLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: 'Origem', snippet: order.originAddress),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destinationLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow:
            InfoWindow(title: 'Destino', snippet: order.destinationAddress),
      ),
    };

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => StatefulBuilder(
              // Usar StatefulBuilder para atualizar o estado do bottom sheet
              builder: (context, setModalState) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _buildDetailChip(Symbols.confirmation_number, 'ID',
                            order.id!.substring(0, 4)),
                        _buildDetailChip(Symbols.straighten, 'Distância',
                            '${order.distance.toStringAsFixed(1)} km'),
                        _buildDetailChip(Symbols.access_time, 'Duração',
                            order.estimatedTime),
                        _buildDetailChip(Symbols.directions_car, 'Transporte',
                            order.transportType),
                        _buildDetailChip(Symbols.attach_money, 'Valor',
                            '${order.price.toStringAsFixed(0)} MT'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildAddressSection(
                        Symbols.location_on, 'Origem:', order.originAddress),
                    const SizedBox(height: 8),
                    _buildAddressSection(
                        Symbols.flag, 'Destino:', order.destinationAddress),

                    const SizedBox(height: 16),
                    if (order.observations != null &&
                        order.observations!.isNotEmpty) ...[
                      const Text('Observações:',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
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
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Google Maps com rota
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  (originLocation.latitude +
                                          destinationLocation.latitude) /
                                      2,
                                  (originLocation.longitude +
                                          destinationLocation.longitude) /
                                      2,
                                ),
                                zoom: 12,
                              ),
                              myLocationEnabled: false,
                              zoomControlsEnabled: true,
                              zoomGesturesEnabled: true,
                              scrollGesturesEnabled: true,
                              mapToolbarEnabled: false,
                              markers: _markers,
                              polylines: _polylines,
                              onMapCreated: (GoogleMapController controller) {
                                _mapController = controller;
                                controller.setMapStyle(_darkMapStyle);

                                // Buscar e desenhar a rota após o mapa ser criado
                                _fetchRouteForOrder(
                                    originLocation, destinationLocation);
                              },
                            ),

                            // Indicador de carregamento enquanto busca a rota
                            if (_isLoadingRoute)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black38,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          highlightColor),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botão para aceitar pedido
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            // Verificar se já existe um pedido ativo
                            final activeOrder = await _orderService
                                .getDriverActiveOrder()
                                .first;
                            if (activeOrder != null) {
                              // Fechar o bottom sheet
                              Navigator.pop(context);

                              // Mostrar mensagem sobre pedido já ativo
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Você já tem uma entrega em andamento'),
                                    backgroundColor: Colors.orange,
                                    action: SnackBarAction(
                                      label: 'Ver Entrega',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        context.go(
                                            '/entregador/delivery_orderstate',
                                            extra: {'orderId': activeOrder.id});
                                      },
                                    ),
                                  ),
                                );
                              }
                              return;
                            }

                            // Fechar o bottom sheet
                            Navigator.pop(context);

                            // Mostrar indicador de progresso
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      highlightColor),
                                ),
                              ),
                            );

                            // Aceitar o pedido
                            await _orderService.acceptOrder(order.id!);

                            // Fechar o indicador de progresso
                            if (context.mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                            }

                            // Mostrar notificação
                            showLocalNotification(
                              title: 'Pedido Aceito',
                              body:
                                  'Você aceitou o pedido #${order.id!.substring(0, 4)}',
                            );

                            // Navegar para a tela de detalhe do pedido
                            if (context.mounted) {
                              context.go('/entregador/delivery_orderstate',
                                  extra: {'orderId': order.id});
                            }
                          } catch (e) {
                            // Fechar o indicador de progresso em caso de erro
                            if (context.mounted) {
                              Navigator.of(context, rootNavigator: true).pop();

                              // Mostrar snackbar com o erro
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao aceitar pedido: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: highlightColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Aceitar Pedido',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    )
                  ],
                ),
              ),
            ));
  }

  // Widget para mostrar um chip de detalhe no bottom sheet
  Widget _buildDetailChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: highlightColor, size: 16),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Widget para mostrar endereços no bottom sheet
  Widget _buildAddressSection(IconData icon, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: highlightColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget para construir o card de entrega ativa
  Widget _buildActiveOrderCard() {
    if (_activeOrder == null) return const SizedBox.shrink();

    // Verifica o ID
    final String orderId = _activeOrder!.id ?? 'N/A';
    final String displayId =
        orderId != 'N/A' ? orderId.substring(0, min(4, orderId.length)) : 'N/A';

    // Verifica os endereços
    final String originAddress = _activeOrder!.originAddress.isNotEmpty
        ? _activeOrder!.originAddress
        : 'Endereço de origem indisponível';

    final String destinationAddress =
        _activeOrder!.destinationAddress.isNotEmpty
            ? _activeOrder!.destinationAddress
            : 'Endereço de destino indisponível';

    String statusText;
    IconData statusIcon;

    switch (_activeOrder!.status) {
      case ds_order.OrderStatus.driverAssigned:
        statusText = 'Entrega aceita';
        statusIcon = Symbols.person;
        break;
      case ds_order.OrderStatus.pickedUp:
        statusText = 'Pedido coletado';
        statusIcon = Symbols.inventory;
        break;
      case ds_order.OrderStatus.inTransit:
        statusText = 'Em trânsito';
        statusIcon = Symbols.local_shipping;
        break;
      default:
        statusText = 'Status desconhecido';
        statusIcon = Symbols.help;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlightColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: highlightColor.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Stack(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: highlightColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: highlightColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Entrega em Andamento',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: highlightColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ID #$displayId',
                        style: TextStyle(
                          color: highlightColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Botão para fechar o card
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Symbols.close,
                      color: Colors.white60, size: 20),
                  onPressed: () {
                    // Temporariamente esconde o card
                    setState(() {
                      _showActiveOrderOverlay = false;
                    });

                    // Mostra um snackbar informando que o card está oculto temporariamente
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'Card minimizado. A entrega continua ativa.'),
                        action: SnackBarAction(
                          label: 'Mostrar',
                          onPressed: () {
                            setState(() {
                              _showActiveOrderOverlay = true;
                            });
                          },
                        ),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  },
                  tooltip: 'Ocultar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Endereços
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Symbols.location_on,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Origem:',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text(originAddress,
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Symbols.flag, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Destino:',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text(destinationAddress,
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),

                // Botão para acompanhar pedido
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      context.go('/entregador/delivery_orderstate',
                          extra: {'orderId': _activeOrder!.id});
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: highlightColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Symbols.map, size: 18),
                    label: const Text('Continuar Entrega'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double horizontalMargin = 16.0;

    return BackHandler(
        alternativeRoute: '/entregador/delivery_home',
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          appBar: AppBar(
            backgroundColor: Colors.black.withOpacity(0.6),
            elevation: 0,
            centerTitle: true,
            title: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String vehicleType = '';
                  if (snapshot.hasData && snapshot.data != null) {
                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    vehicleType = userData?['veiculo']?['tipo'] ?? '';
                  }

                  return Column(
                    children: [
                      Text(
                        'Pedidos Disponíveis',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w700,
                          color: highlightColor,
                        ),
                      ),
                      if (vehicleType.isNotEmpty)
                        Text(
                          'Compatíveis com seu $vehicleType',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  );
                }),
          ),
          body: Stack(
            children: [
              // Conteúdo principal
              _isLoadingActiveOrder
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(highlightColor),
                      ),
                    )
                  : _activeOrder != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Symbols.info,
                                    color: Colors.white70, size: 50),
                                const SizedBox(height: 16),
                                const Text(
                                  'Você já possui uma entrega em andamento',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: () {
                                    context.go(
                                        '/entregador/delivery_orderstate',
                                        extra: {'orderId': _activeOrder!.id});
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: highlightColor,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 16),
                                  ),
                                  icon: const Icon(Symbols.navigation),
                                  label: const Text('Continuar Entrega'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : StreamBuilder<List<ds_order.Order>>(
                          stream: _orderService.getAvailableOrders(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      highlightColor),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Symbols.error,
                                          color: Colors.red, size: 64),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Erro ao carregar pedidos',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Verifique sua conexão e tente novamente.',
                                        style: TextStyle(
                                            color: Colors.grey.shade400),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      FilledButton.icon(
                                        onPressed: () {
                                          setState(
                                              () {}); // Força reconstrução do widget
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: highlightColor,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 16),
                                        ),
                                        icon: const Icon(Symbols.refresh),
                                        label: const Text('Tentar Novamente'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final orders = snapshot.data ?? [];

                            if (orders.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey.withOpacity(0.1),
                                      ),
                                      padding: const EdgeInsets.all(32),
                                      child: const Icon(
                                        Symbols.search_off_rounded,
                                        color: Colors.white54,
                                        size: 64,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Nenhum pedido disponível',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 40),
                                      child: Text(
                                        'Não há pedidos disponíveis para entrega no momento. Volte mais tarde para verificar novos pedidos.',
                                        style: TextStyle(
                                            color: Colors.grey.shade400),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    FilledButton.icon(
                                      onPressed: () {
                                        setState(
                                            () {}); // Força reconstrução do widget
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: highlightColor,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 16),
                                      ),
                                      icon: const Icon(Symbols.refresh),
                                      label: const Text('Atualizar'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 20, horizontal: 16),
                              itemCount: orders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final order = orders[index];
                                return _buildOrderCard(order);
                              },
                            );
                          },
                        ),

              // Card de entrega ativa como overlay
              if (!_isLoadingActiveOrder &&
                  _activeOrder != null &&
                  _showActiveOrderOverlay)
                Positioned(
                  top: 100,
                  left: horizontalMargin,
                  right: horizontalMargin,
                  child: Hero(
                    tag: 'active_order_${_activeOrder!.id}',
                    child: GestureDetector(
                      onTap: () {
                        context.go('/entregador/delivery_orderstate',
                            extra: {'orderId': _activeOrder!.id});
                      },
                      child: Material(
                        color: Colors.transparent,
                        elevation: 16,
                        shadowColor: highlightColor.withOpacity(0.3),
                        child: _buildActiveOrderCard(),
                      ),
                    ),
                  ),
                ),

              // Botão para mostrar entrega ativa
              if (!_isLoadingActiveOrder &&
                  _activeOrder != null &&
                  !_showActiveOrderOverlay)
                Positioned(
                  right: horizontalMargin,
                  top: 100,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: highlightColor,
                    onPressed: () {
                      setState(() {
                        _showActiveOrderOverlay = true;
                      });
                    },
                    child:
                        const Icon(Symbols.local_shipping, color: Colors.white),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: Container(
            margin: const EdgeInsets.only(
                bottom: 30,
                left: 20,
                right: 20), // Aumentado para evitar overflow
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
            height: 70,
            decoration: BoxDecoration(
              color: const Color.fromARGB(200, 15, 15, 15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: highlightColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: highlightColor.withAlpha(100),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(Symbols.history, 'Histórico', 0,
                    _currentIndex == 0, highlightColor),
                _buildNavItem(Symbols.list_alt, 'Pedidos', 1,
                    _currentIndex == 1, highlightColor),
                _buildNavItem(Symbols.home, 'Início', 2, _currentIndex == 2,
                    highlightColor),
                _buildNavItem(Symbols.person, 'Perfil', 3, _currentIndex == 3,
                    highlightColor),
              ],
            ),
          ),
        ));
  }

  Widget _buildOrderCard(ds_order.Order order) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlightColor.withOpacity(0.4), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pedido #${order.id!.substring(0, 4)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${order.price.toStringAsFixed(0)} MT',
                style: TextStyle(
                  color: highlightColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24),
          // Usando Wrap para textos
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildOrderDetailChip(Symbols.straighten,
                  '${order.distance.toStringAsFixed(1)} km'),
              _buildOrderDetailChip(Symbols.timer, order.estimatedTime),
              _buildTransportTypeChip(order.transportType),
            ],
          ),
          const SizedBox(height: 12),

          // Origem e destino com Expanded para permitir quebra de texto
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Symbols.location_on, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.originAddress,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Symbols.flag, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.destinationAddress,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () => _showOrderDetails(order),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color.fromARGB(255, 165, 165, 165),
                  side: BorderSide(color: highlightColor),
                ),
                child: const Text('Ver Detalhes'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    // Mostrar indicador de progresso
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(highlightColor),
                        ),
                      ),
                    );

                    // Aceitar o pedido
                    await _orderService.acceptOrder(order.id!);

                    // Fechar o indicador de progresso
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }

                    showLocalNotification(
                      title: 'Pedido Aceito',
                      body:
                          'Recebeste o pedido #${order.id!.substring(0, 4)}, entregue com qualidade.',
                    );

                    if (context.mounted) {
                      context.go('/entregador/delivery_orderstate',
                          extra: {'orderId': order.id});
                    }
                  } catch (e) {
                    // Fechar o indicador de progresso em caso de erro
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao aceitar pedido: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: highlightColor),
                child: const Text('Aceitar Pedido',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Chip para os detalhes nos cards
  Widget _buildOrderDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Chip especial para o tipo de transporte com cores diferentes
  Widget _buildTransportTypeChip(String transportType) {
    Color bgColor;
    Color borderColor;
    IconData transportIcon;

    // Definir cores e ícone com base no tipo
    if (transportType == 'Motorizada') {
      bgColor = Colors.blue.withOpacity(0.2);
      borderColor = Colors.blue;
      transportIcon = Symbols.two_wheeler;
    } else if (transportType == 'Carro') {
      bgColor = Colors.green.withOpacity(0.2);
      borderColor = Colors.green;
      transportIcon = Symbols.directions_car;
    } else {
      // Padrão para outros tipos
      bgColor = Colors.black26;
      borderColor = Colors.white10;
      transportIcon = Symbols.local_shipping;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(transportIcon, color: borderColor, size: 14),
          const SizedBox(width: 4),
          Text(
            transportType,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool selected,
      Color highlightColor) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: selected ? highlightColor : Colors.white54),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected ? highlightColor : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
