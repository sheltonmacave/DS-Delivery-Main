import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/order_model.dart' as ds_order;
import '../../services/order_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientHistoryPage extends StatefulWidget {
  const ClientHistoryPage({super.key});

  @override
  State<ClientHistoryPage> createState() => _ClientHistoryPageState();
}

class _ClientHistoryPageState extends State<ClientHistoryPage> with AutomaticKeepAliveClientMixin {
  final Color highlightColor = const Color(0xFFFF6A00);
  int _currentIndex = 0;
  final OrderService _orderService = OrderService();
  
  // Map of controllers for each map index
  final Map<int, GoogleMapController> _mapControllers = {};
  
  // Map of route polylines for each order
  final Map<int, Set<Polyline>> _orderPolylines = {};
  
  // Map of markers for each order
  final Map<int, Set<Marker>> _orderMarkers = {};
  
  // Track which orders have their routes loaded
  final Set<int> _routesLoaded = {};
  
  List<ds_order.Order> _orders = [];
  bool _isLoading = true;

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
  
  static const String googleAPIKey = 'AIzaSyCNlTXTSlKc2cCyGbWKqKCIkRN4JMiY1tQ';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    // Dispose all map controllers
    for (final controller in _mapControllers.values) {
      controller.dispose();
    }
    _mapControllers.clear();
    super.dispose();
  }
  
  Future<void> _loadOrders() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      // Simplified query to avoid index requirement
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('clientId', isEqualTo: currentUser.uid)
          .get();
      
      if (mounted) {
        setState(() {
          // Process and filter in memory
          _orders = snapshot.docs
              .map((doc) => ds_order.Order.fromJson({...doc.data(), 'id': doc.id}))
              .where((order) => 
                  order.status == ds_order.OrderStatus.delivered || 
                  order.status == ds_order.OrderStatus.cancelled)
              .toList();
              
          // Sort in memory
          _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          _isLoading = false;
          
          // Pre-compute markers for all orders
          for (int i = 0; i < _orders.length; i++) {
            _createMarkersForOrder(i);
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar pedidos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Create markers for an order
  void _createMarkersForOrder(int index) {
    if (index >= _orders.length) return;
    
    final order = _orders[index];
    
    final originLocation = LatLng(
      order.originLocation.latitude, 
      order.originLocation.longitude
    );
    
    final destinationLocation = LatLng(
      order.destinationLocation.latitude,
      order.destinationLocation.longitude
    );
    
    _orderMarkers[index] = {
      Marker(
        markerId: MarkerId('origin_$index'),
        position: originLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
      Marker(
        markerId: MarkerId('destination_$index'),
        position: destinationLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    };
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) return; // Já está na página atual
    
    if (index == 1) context.go('/cliente/client_home');
    if (index == 2) context.go('/cliente/client_profile');
  }

  // Handle map creation
  void _onMapCreated(GoogleMapController controller, int index) {
    _mapControllers[index] = controller;
    controller.setMapStyle(_darkMapStyle);
    
    // Fetch route after map is created
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _mapControllers[index] != null) {
        _fetchRouteForOrder(index);
      }
    });
  }

  Future<void> _fetchRouteForOrder(int index) async {
    if (index < 0 || index >= _orders.length || !_mapControllers.containsKey(index)) {
      return;
    }
    
    // If we've already fetched this route, no need to do it again
    if (_routesLoaded.contains(index)) return;
    
    final order = _orders[index];
    
    final originLocation = LatLng(
      order.originLocation.latitude, 
      order.originLocation.longitude
    );
    
    final destinationLocation = LatLng(
      order.destinationLocation.latitude,
      order.destinationLocation.longitude
    );
    
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${originLocation.latitude},${originLocation.longitude}'
        '&destination=${destinationLocation.latitude},${destinationLocation.longitude}'
        '&mode=driving'
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
          
          if (mounted) {
            setState(() {
              _orderPolylines[index] = {
                Polyline(
                  polylineId: PolylineId('route_$index'),
                  color: highlightColor,
                  points: polylineCoordinates,
                  width: 4,
                  patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                )
              };
              _routesLoaded.add(index);
            });
            
            // Adjust camera to show the route
            if (_mapControllers.containsKey(index)) {
              final bounds = _calculateBounds(polylineCoordinates);
              _mapControllers[index]!.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 50)
              );
            }
          }
        } else {
          _createStraightLine(index, originLocation, destinationLocation);
        }
      } else {
        _createStraightLine(index, originLocation, destinationLocation);
      }
    } catch (e) {
      debugPrint('Erro ao buscar rota para índice $index: $e');
      _createStraightLine(index, originLocation, destinationLocation);
    }
  }

  void _createStraightLine(int index, LatLng origin, LatLng destination) {
    if (mounted && _mapControllers.containsKey(index)) {
      setState(() {
        _orderPolylines[index] = {
          Polyline(
            polylineId: PolylineId('route_$index'),
            color: highlightColor,
            points: [origin, destination],
            width: 4,
          )
        };
        _routesLoaded.add(index);
      });
      
      // Adjust the camera
      final bounds = _calculateBounds([origin, destination]);
      _mapControllers[index]!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50)
      );
    }
  }

  Widget _buildEmptyHistoryView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.history,
                color: highlightColor,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Histórico Vazio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Você ainda não realizou nenhum pedido. Seus pedidos anteriores aparecerão aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/cliente/client_createorder'),
              style: FilledButton.styleFrom(
                backgroundColor: highlightColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Symbols.add_circle, color: Colors.white),
              label: const Text(
                'Criar Pedido',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (LatLng point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final double horizontalMargin = MediaQuery.of(context).size.width * 0.05;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.6),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Histórico',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
            color: highlightColor,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Conteúdo principal
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
              ),
            )
          else if (_orders.isEmpty)
            _buildEmptyHistoryView()
          else
            ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                
                // Data formatada
                final createdAtFormatted = DateFormat('dd/MM/yyyy HH:mm')
                    .format(order.createdAt);
                
                // Coordenadas
                final originLocation = LatLng(
                  order.originLocation.latitude, 
                  order.originLocation.longitude
                );
                
                final destinationLocation = LatLng(
                  order.destinationLocation.latitude,
                  order.destinationLocation.longitude
                );
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      print('Navegando para resumo com orderId: ${order.id}');
                      context.go('/cliente/client_ordersummary', extra: {'orderId': order.id});
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: highlightColor.withOpacity(0.4), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mapa no topo - Always visible
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: SizedBox(
                              height: 140,
                              width: double.infinity,
                              child: Stack(
                                children: [
                                  // Always show the map
                                  GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: LatLng(
                                        (originLocation.latitude + destinationLocation.latitude) / 2,
                                        (originLocation.longitude + destinationLocation.longitude) / 2,
                                      ),
                                      zoom: 12,
                                    ),
                                    mapType: MapType.normal,
                                    zoomControlsEnabled: false,
                                    mapToolbarEnabled: false,
                                    compassEnabled: false,
                                    rotateGesturesEnabled: false,
                                    scrollGesturesEnabled: false,
                                    zoomGesturesEnabled: false,
                                    tiltGesturesEnabled: false,
                                    myLocationEnabled: false,
                                    polylines: _orderPolylines[index] ?? {},
                                    markers: _orderMarkers[index] ?? {},
                                    onMapCreated: (controller) => _onMapCreated(controller, index),
                                    liteModeEnabled: true, // Use lite mode for better performance
                                  ),
                                  
                                  // Show loading indicator while route is being fetched
                                  if (!_routesLoaded.contains(index))
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(16),
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
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Carregando rota...',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Conteúdo do card
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header com ID e Data
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Symbols.numbers, color: highlightColor, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '#${order.id!.substring(0, 4)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Symbols.calendar_month, color: Colors.white70, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          createdAtFormatted,
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Endereços com Wrap
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _buildAddressChip(
                                      Symbols.location_on, 
                                      order.originAddress, 
                                      Colors.orange
                                    ),
                                    _buildAddressChip(
                                      Symbols.flag, 
                                      order.destinationAddress, 
                                      Colors.blue
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(order.status).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(order.status),
                                    style: TextStyle(
                                      color: _getStatusColor(order.status),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          
          // Bottom Navigation Bar
          Positioned(
            bottom: 20,
            left: horizontalMargin,
            right: horizontalMargin,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
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
                  _buildNavItem(Symbols.history, 'Histórico', 0, _currentIndex == 0, highlightColor),
                  _buildNavItem(Symbols.home, 'Início', 1, _currentIndex == 1, highlightColor),
                  _buildNavItem(Symbols.person, 'Perfil', 2, _currentIndex == 2, highlightColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para exibir endereço como chip
  Widget _buildAddressChip(IconData icon, String address, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              address,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Helper para cores de status
  Color _getStatusColor(ds_order.OrderStatus status) {
    switch (status) {
      case ds_order.OrderStatus.delivered:
        return Colors.green;
      case ds_order.OrderStatus.cancelled:
        return Colors.red;
      case ds_order.OrderStatus.inTransit:
        return highlightColor;
      case ds_order.OrderStatus.driverAssigned:
      case ds_order.OrderStatus.pickedUp:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  // Helper para texto de status
  String _getStatusText(ds_order.OrderStatus status) {
    switch (status) {
      case ds_order.OrderStatus.pending:
        return 'Pendente';
      case ds_order.OrderStatus.driverAssigned:
        return 'Entregador atribuído';
      case ds_order.OrderStatus.pickedUp:
        return 'Coletado';
      case ds_order.OrderStatus.inTransit:
        return 'Em trânsito';
      case ds_order.OrderStatus.delivered:
        return 'Entregue';
      case ds_order.OrderStatus.cancelled:
        return 'Cancelado';
      default:
        return 'Desconhecido';
    }
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool selected, Color highlightColor) {
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
  
  @override
  bool get wantKeepAlive => true;
}