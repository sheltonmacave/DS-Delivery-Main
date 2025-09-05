import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../services/notifications_service.dart';
import '../../services/order_service.dart';
import '../../models/order_model.dart' as ds_order;

class ClientOrderStatePage extends StatefulWidget {
  final String orderId;
  
  const ClientOrderStatePage({super.key, required this.orderId});

  @override
  State<ClientOrderStatePage> createState() => _ClientOrderStatePageState();
}

class _ClientOrderStatePageState extends State<ClientOrderStatePage> with AutomaticKeepAliveClientMixin {
  final Color highlightColor = const Color(0xFFFF6A00);
  final OrderService _orderService = OrderService();
  
  // Dados do pedido
  ds_order.Order? _orderData;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Google Maps controlador
  GoogleMapController? _mapController;
  
  // Markers e polylines
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Estado de carregamento
  bool _isLoadingRoute = false;
  bool _mapReady = false;
  bool _isFirstBuild = true;
  
  // Stream subscription para atualizações de pedido
  StreamSubscription<ds_order.Order?>? _orderSubscription;
  
  // Estilo do mapa escuro
  static const String _mapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#212121"}]
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
      "featureType": "administrative.country",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#9e9e9e"}]
    },
    {
      "featureType": "administrative.land_parcel",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#bdbdbd"}]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#757575"}]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [{"color": "#181818"}]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#616161"}]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#1b1b1b"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry.fill",
      "stylers": [{"color": "#2c2c2c"}]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#8a8a8a"}]
    },
    {
      "featureType": "road.arterial",
      "elementType": "geometry",
      "stylers": [{"color": "#373737"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [{"color": "#3c3c3c"}]
    },
    {
      "featureType": "road.highway.controlled_access",
      "elementType": "geometry",
      "stylers": [{"color": "#4e4e4e"}]
    },
    {
      "featureType": "road.local",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#616161"}]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#757575"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#000000"}]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#3d3d3d"}]
    }
  ]
  ''';
  
  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }
  
  // Carregar dados do pedido usando Future primeiro
  Future<void> _loadOrderData() async {
    try {
      final order = await _orderService.getOrderByIdOnce(widget.orderId);
      
      if (mounted) {
        setState(() {
          _orderData = order;
          _isLoading = false;
          
          // Se os dados foram carregados com sucesso, configurar listeners
          if (order != null) {
            _setupOrderListener();
          } else {
            _hasError = true;
            _errorMessage = 'Pedido não encontrado';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Erro ao carregar pedido: $e';
        });
      }
    }
  }
  
  // Configurar listener para atualizações de pedido (apenas para atualizações)
  void _setupOrderListener() {
    _orderSubscription = _orderService.getOrderById(widget.orderId).listen(
      (updatedOrder) {
        // Só atualizar se houver dados novos e o widget ainda estiver montado
        if (mounted && updatedOrder != null && 
            (_orderData == null || updatedOrder.status != _orderData!.status)) {
          setState(() {
            _orderData = updatedOrder;
            _updateMapMarkers();
          });
        }
      },
      onError: (e) {
        // Ignorar erros aqui, já temos os dados iniciais carregados
        print('Erro ao receber atualização de pedido: $e');
      }
    );
  }
  
  @override
  void dispose() {
    _orderSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
  
  // Atualiza os marcadores e a rota no mapa quando houver atualização do pedido
  void _updateMapMarkers() {
    if (_orderData == null || !_mapReady || _mapController == null) return;
    
    try {
      final originLocation = LatLng(
        _orderData!.originLocation.latitude,
        _orderData!.originLocation.longitude,
      );
      
      final destinationLocation = LatLng(
        _orderData!.destinationLocation.latitude,
        _orderData!.destinationLocation.longitude,
      );
      
      // Definir posição do entregador com base no status
      LatLng driverPosition;
      switch (_orderData!.status) {
        case ds_order.OrderStatus.driverAssigned:
          driverPosition = originLocation;
          break;
        case ds_order.OrderStatus.pickedUp:
          driverPosition = originLocation;
          break;
        case ds_order.OrderStatus.inTransit:
          // Em uma posição intermediária entre origem e destino (60% do caminho)
          driverPosition = LatLng(
            originLocation.latitude + (destinationLocation.latitude - originLocation.latitude) * 0.6,
            originLocation.longitude + (destinationLocation.longitude - originLocation.longitude) * 0.6,
          );
          break;
        case ds_order.OrderStatus.delivered:
          driverPosition = destinationLocation;
          break;
        default:
          driverPosition = originLocation;
      }
      
      // Atualizar marcadores sem re-renderizar o mapa inteiro
      _markers.clear();
      _markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: originLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: "Origem"),
      ));
      
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destinationLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: "Destino"),
      ));
      
      // Adicionar marcador do entregador se houver um atribuído e pedido estiver ativo
      if (_orderData!.driverId != null && 
          _orderData!.status != ds_order.OrderStatus.delivered && 
          _orderData!.status != ds_order.OrderStatus.cancelled) {
        _markers.add(Marker(
          markerId: const MarkerId('driver'),
          position: driverPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: "Entregador"),
          zIndex: 2,
        ));
      }
      
      // Se for a primeira construção, buscar a rota
      if (_isFirstBuild) {
        _fetchRoutePoints(originLocation, destinationLocation);
        _isFirstBuild = false;
      }
    } catch (e) {
      print('Erro ao atualizar marcadores: $e');
    }
  }
  
  // Busca pontos de rota da API do Google Directions
  Future<void> _fetchRoutePoints(LatLng origin, LatLng destination) async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingRoute = true;
    });
    
    try {
      const apiKey = 'AIzaSyCNlTXTSlKc2cCyGbWKqKCIkRN4JMiY1tQ';
      final url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/directions/json',
        {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'key': apiKey,
        },
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final points = data['routes'][0]['overview_polyline']['points'];
          final polylinePoints = PolylinePoints().decodePolyline(points);
          
          if (polylinePoints.isNotEmpty) {
            final polylineCoordinates = polylinePoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
            
            if (mounted) {
              setState(() {
                _polylines.clear();
                _polylines.add(
                  Polyline(
                    polylineId: const PolylineId('route'),
                    color: highlightColor,
                    points: polylineCoordinates,
                    width: 5,
                    patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                  ),
                );
                _isLoadingRoute = false;
              });
              
              // Ajustar zoom para mostrar a rota
              _fitBoundsWithPadding(polylineCoordinates);
            }
          } else {
            _createStraightLine(origin, destination);
          }
        } else {
          _createStraightLine(origin, destination);
        }
      } else {
        _createStraightLine(origin, destination);
      }
    } catch (e) {
      print('Erro ao buscar rota: $e');
      _createStraightLine(origin, destination);
    }
  }
  
  // Cria uma linha reta quando falha ao buscar rota
  void _createStraightLine(LatLng origin, LatLng destination) {
    if (!mounted) return;
    
    setState(() {
      _polylines.clear();
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
    
    _fitBoundsWithPadding([origin, destination]);
  }
  
  // Ajusta a câmera para mostrar todos os pontos
  Future<void> _fitBoundsWithPadding(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;
    
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
      
      // Adicionar uma pequena margem para melhor visualização
      const double padding = 0.02;
      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - padding, minLng - padding),
        northeast: LatLng(maxLat + padding, maxLng + padding),
      );
      
      await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } catch (e) {
      print('Erro ao ajustar limites do mapa: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.6),
        elevation: 0,
        title: const Text(
          'Estado do Pedido',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Symbols.support_agent, color: highlightColor),
            onPressed: () => context.go('/cliente/client_support', extra: {'orderId': widget.orderId}),
          )
        ],
      ),
      body: _isLoading 
        ? _buildLoadingView()
        : _hasError 
          ? _buildErrorView()
          : _buildMainContent(),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
          ),
          const SizedBox(height: 16),
          const Text(
            'Carregando detalhes do pedido...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Symbols.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar pedido',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _loadOrderData();
              },
              style: FilledButton.styleFrom(
                backgroundColor: highlightColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMainContent() {
    if (_orderData == null) {
      return const Center(child: Text('Pedido não disponível', style: TextStyle(color: Colors.white)));
    }
    
    final originLocation = LatLng(
      _orderData!.originLocation.latitude,
      _orderData!.originLocation.longitude,
    );
    
    final destinationLocation = LatLng(
      _orderData!.destinationLocation.latitude,
      _orderData!.destinationLocation.longitude,
    );
    
    return Stack(
      children: [
        // Mapa em cache para evitar reconstruções
        RepaintBoundary(
          child: AbsorbPointer(
            absorbing: false,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (originLocation.latitude + destinationLocation.latitude) / 2,
                  (originLocation.longitude + destinationLocation.longitude) / 2,
                ),
                zoom: 13,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                controller.setMapStyle(_mapStyle);
                setState(() {
                  _mapReady = true;
                  _updateMapMarkers();
                });
              },
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              compassEnabled: true,
              markers: _markers,
              polylines: _polylines,
              mapToolbarEnabled: false,
            ),
          ),
        ),
        
        // Indicador de carregamento da rota
        if (_isLoadingRoute)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Carregando rota...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Bottom Sheet com os detalhes do pedido
        DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.2,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildProgressTimeline(_orderData!),
                const SizedBox(height: 24),
                if (_orderData!.driverId != null) _buildDeliveryInfo(_orderData!),
                const SizedBox(height: 24),
                _buildOrderDetails(context, _orderData!),
                
                // Botões de ação baseados no status
                _buildActionButtons(_orderData!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTimeline(ds_order.Order order) {
    // Se ainda não tem entregador atribuído
    if (order.status == ds_order.OrderStatus.pending) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF232323),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: highlightColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Aguardando entregador aceitar o pedido...',
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Symbols.info, color: highlightColor),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Os entregadores disponíveis na sua área já foram notificados sobre o seu pedido.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  
    // Lista de estados possíveis para exibição
    final List<Map<String, dynamic>> etapas = [
      {
        'status': ds_order.OrderStatus.driverAssigned,
        'title': 'Entregador Encontrado',
      },
      {
        'status': ds_order.OrderStatus.pickedUp,
        'title': 'Encomenda Coletada',
      },
      {
        'status': ds_order.OrderStatus.inTransit,
        'title': 'Entregador a Caminho',
      },
      {
        'status': ds_order.OrderStatus.delivered,
        'title': 'Encomenda Entregue',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: etapas.asMap().entries.map((entry) {
        int index = entry.key;
        final etapa = entry.value;
        final ds_order.OrderStatus status = etapa['status'];
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
                Icon(
                  hasUpdate ? Symbols.check_circle : Symbols.circle,
                  color: hasUpdate ? highlightColor : Colors.grey,
                  size: 16
                ),
                if (index != etapas.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: hasUpdate ? highlightColor : Colors.grey.withOpacity(0.3),
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

  Widget _buildDeliveryInfo(ds_order.Order order) {
    // Use FutureBuilder em vez de reconstruir o widget inteiro
    return FutureBuilder<firestore.DocumentSnapshot>(
      future: firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(order.driverId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey,
                  child: Icon(Symbols.person, color: Colors.white54, size: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 16,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
                  strokeWidth: 2,
                ),
              ],
            ),
          );
        }
        
        final driverData = snapshot.data!.data() as Map<String, dynamic>?;
        final driverName = driverData?['name'] ?? 'Entregador';
        final driverPhone = driverData?['phone'] ?? '';
        final driverPhoto = driverData?['photoURL'];
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: driverPhoto != null 
                    ? NetworkImage(driverPhoto)
                    : null,
                backgroundColor: Colors.grey.shade800,
                child: driverPhoto == null ? const Icon(Symbols.person, color: Colors.white54, size: 40) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName, 
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seu entregador',
                      style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    if (driverPhone.isNotEmpty)
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Symbols.call, color: highlightColor),
                            onPressed: () async {
                              final Uri phoneUri = Uri.parse('tel:$driverPhone');
                              try {
                                await launchUrl(phoneUri);
                              } catch (e) {
                                print('Erro ao fazer chamada: $e');
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Symbols.sms, color: highlightColor),
                            onPressed: () async {
                              final Uri smsUri = Uri.parse('sms:$driverPhone');
                              try {
                                await launchUrl(smsUri);
                              } catch (e) {
                                print('Erro ao enviar SMS: $e');
                              }
                            },
                          )
                        ],
                      )
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: highlightColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Symbols.star, color: highlightColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '4.8',
                      style: TextStyle(color: highlightColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderDetails(BuildContext context, ds_order.Order order) {
    final createdAt = DateFormat('dd/MM/yyyy às HH:mm')
        .format(order.createdAt);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(icon: Symbols.timer, text: 'Duração: ${order.estimatedTime}'),
          _DetailRow(icon: Symbols.confirmation_number, text: 'ID: #${order.id!.substring(0, 4)}'),
          _DetailRow(icon: Symbols.calendar_today, text: 'Data: $createdAt'),
          _DetailRow(icon: Symbols.location_on, text: 'Origem: ${order.originAddress}'),
          _DetailRow(icon: Symbols.flag, text: 'Destino: ${order.destinationAddress}'),
          _DetailRow(icon: Symbols.local_shipping, text: 'Transporte: ${order.transportType}'),
          _DetailRow(
            icon: Symbols.straighten,
            text: 'Distância: ${order.distance.toStringAsFixed(1)} km',
          ),
          _DetailRow(
            icon: Symbols.attach_money,
            text: 'Valor: ${order.price.toStringAsFixed(0)} MT',
          ),
          
          if (order.observations != null && order.observations!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Symbols.note, color: highlightColor, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Observações:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    order.observations!,
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // Botões de ação dinâmicos baseados no status
  Widget _buildActionButtons(ds_order.Order order) {
    // Botões para pedido entregue
    if (order.status == ds_order.OrderStatus.delivered) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green),
          ),
          child: Column(
            children: [
              const Icon(Symbols.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Pedido finalizado!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Obrigado por utilizar nossos serviços.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  // Navegar para tela de avaliação ou home
                  context.go('/cliente/client_home');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                icon: const Icon(Symbols.home),
                label: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Botão de confirmação para pedido que chegou mas não foi marcado como entregue
    if (order.status == ds_order.OrderStatus.inTransit) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            // Botão para confirmar recebimento
            FilledButton(
              onPressed: () => _showConfirmationDialog(
                context,
                title: 'Confirmar Recebimento',
                message: 'Confirma que recebeu a sua encomenda?',
                confirmAction: () async {
                  try {
                    await _orderService.confirmDelivery(order.id!);
                    
                    showLocalNotification(
                      title: 'Pedido Finalizado',
                      body: 'Obrigado por usar o nosso serviço! Avalie a sua experiência.',
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erro ao confirmar recebimento: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              style: FilledButton.styleFrom(
                backgroundColor: highlightColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: highlightColor),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Symbols.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Confirmar Recebimento', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    // Botão de cancelamento (se não estiver finalizado ou cancelado e ainda não tiver sido coletado)
    if (order.status != ds_order.OrderStatus.delivered && 
        order.status != ds_order.OrderStatus.cancelled &&
        order.status != ds_order.OrderStatus.inTransit) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: FilledButton(
          onPressed: () => _showConfirmationDialog(
            context,
            title: 'Cancelar Pedido',
            message: 'Tens a certeza que queres cancelar o pedido?',
            isCancel: true,
            confirmAction: () async {
              try {
                await _orderService.cancelOrder(
                  order.id!,
                  reason: 'Cancelado pelo cliente',
                );
                showLocalNotification(
                  title: 'Pedido Cancelado',
                  body: 'O seu pedido foi cancelado com sucesso.',
                );
                if (mounted) {
                  context.go('/cliente/client_home');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao cancelar pedido: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Symbols.cancel, color: Colors.white),
              SizedBox(width: 8),
              Text('Cancelar Pedido', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    
    // Status cancelado
    if (order.status == ds_order.OrderStatus.cancelled) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red),
          ),
          child: Column(
            children: [
              const Icon(Symbols.cancel, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Pedido cancelado',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  context.go('/cliente/client_home');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: highlightColor,
                ),
                icon: const Icon(Symbols.home),
                label: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Estado padrão - em trânsito, sem botões específicos
    return const SizedBox.shrink();
  }

  void _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool isCancel = false,
    bool showOnlyClose = false,
    Function()? confirmAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.75),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: highlightColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCancel ? Symbols.cancel : Symbols.info,
                color: isCancel ? Colors.red : highlightColor,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              if (showOnlyClose)
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: highlightColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Fechar', style: TextStyle(color: Colors.white)),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Não', style: TextStyle(color: Colors.white)),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (confirmAction != null) {
                          confirmAction();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: isCancel ? Colors.red : highlightColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sim', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
    );
  }
}