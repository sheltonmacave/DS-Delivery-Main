import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../models/order_model.dart' as ds_order;
import '../../services/order_service.dart';

class DeliveryHistoryPage extends StatefulWidget {
  const DeliveryHistoryPage({super.key});

  @override
  State<DeliveryHistoryPage> createState() => _DeliveryHistoryPageState();
}

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage> with AutomaticKeepAliveClientMixin {
  final Color highlightColor = const Color(0xFFFF6A00);
  int _currentIndex = 0;
  final OrderService _orderService = OrderService();
  
  // Track visible items by their index
  final Set<int> _visibleItems = {};
  
  // Track which orders have their routes loaded
  final Set<int> _routesLoaded = {};
  
  // Store polylines for each order
  final Map<int, Set<Polyline>> _orderPolylines = {};
  
  // Store markers for each order
  final Map<int, Set<Marker>> _orderMarkers = {};
  
  List<ds_order.Order> _orders = [];
  bool _isLoading = true;
  
  // Scroll controller to track visible items
  final ScrollController _scrollController = ScrollController();

  // Dark mode style for Google Maps
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
    
    // Listen to scroll events to update visible items
    _scrollController.addListener(_updateVisibleItems);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateVisibleItems);
    _scrollController.dispose();
    super.dispose();
  }
  
  // Update which items are visible during scrolling
  void _updateVisibleItems() {
    // Delay the processing to avoid doing too much work during scrolling
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      // Only process if we're not currently scrolling
      if (!_scrollController.position.isScrollingNotifier.value) {
        _calculateVisibleItems();
      }
    });
  }
  
  // Calculate which items are currently visible in the viewport
  void _calculateVisibleItems() {
    if (!mounted || _orders.isEmpty) return;
    
    final Set<int> newVisibleItems = {};
    
    for (int i = 0; i < _orders.length; i++) {
      final RenderObject? renderObject = _getMapRenderObject(i);
      if (renderObject != null && _isItemVisible(renderObject)) {
        newVisibleItems.add(i);
        
        // Preload route data if not already loaded
        if (!_routesLoaded.contains(i)) {
          _preloadRouteData(i);
        }
      }
    }
    
    // Update visible items set
    setState(() {
      _visibleItems.clear();
      _visibleItems.addAll(newVisibleItems);
    });
  }
  
  // Get render object for a specific map
  RenderObject? _getMapRenderObject(int index) {
    final mapKey = GlobalKey();
    final mapContainer = _mapContainerKeys[index];
    if (mapContainer != null) {
      return mapContainer.currentContext?.findRenderObject();
    }
    return null;
  }
  
  // Check if a render object is visible in the viewport
  bool _isItemVisible(RenderObject renderObject) {
    try {
      final RenderAbstractViewport viewport = RenderAbstractViewport.of(renderObject);
      final RevealedOffset revealedOffset = viewport.getOffsetToReveal(renderObject, 0.0);
      final double deltaTop = revealedOffset.offset - _scrollController.offset;
      
      // Check if the item is within the viewport bounds
      return deltaTop < viewport.paintBounds.height && deltaTop > -renderObject.paintBounds.height;
    } catch (e) {
      return false;
    }
  }
  
  // Store map container keys for finding render objects
  final Map<int, GlobalKey> _mapContainerKeys = {};
  
  // Get or create a key for a specific map index
  GlobalKey _getMapContainerKey(int index) {
    if (!_mapContainerKeys.containsKey(index)) {
      _mapContainerKeys[index] = GlobalKey();
    }
    return _mapContainerKeys[index]!;
  }

  Future<void> _loadOrders() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      final completedOrders = await _orderService.getDriverCompletedOrdersOnce(currentUser.uid);
      
      if (mounted) {
        setState(() {
          _orders = completedOrders;
          _isLoading = false;
          
          // Pre-compute markers for all orders to avoid doing it later
          for (int i = 0; i < _orders.length; i++) {
            _createMarkersForOrder(i);
          }
          
          // After a short delay, calculate initially visible items
          Future.delayed(const Duration(milliseconds: 500), _calculateVisibleItems);
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
  
  // Preload route data for a map that's about to become visible
  Future<void> _preloadRouteData(int index) async {
    if (_routesLoaded.contains(index) || index >= _orders.length) return;
    
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
                ),
              };
              _routesLoaded.add(index);
            });
          }
        } else {
          _createStraightLineFallback(index, originLocation, destinationLocation);
        }
      } else {
        _createStraightLineFallback(index, originLocation, destinationLocation);
      }
    } catch (e) {
      debugPrint('Erro ao buscar rota para ordem $index: $e');
      _createStraightLineFallback(index, originLocation, destinationLocation);
    }
  }

  // Create straight line between points when API fails
  void _createStraightLineFallback(int index, LatLng origin, LatLng destination) {
    if (mounted) {
      setState(() {
        _orderPolylines[index] = {
          Polyline(
            polylineId: PolylineId('route_$index'),
            color: highlightColor,
            points: [origin, destination],
            width: 4,
          ),
        };
        _routesLoaded.add(index);
      });
    }
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
  
  // Handle map creation
  void _onMapCreated(GoogleMapController controller, int index) {
    controller.setMapStyle(_darkMapStyle);
    
    // If we already have route data, set the camera bounds
    if (_orderPolylines.containsKey(index) && _orderPolylines[index]!.isNotEmpty) {
      final polyline = _orderPolylines[index]!.first;
      final bounds = _calculateBounds(polyline.points);
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
    } else {
      // Otherwise, use origin and destination markers
      if (_orderMarkers.containsKey(index) && _orderMarkers[index]!.length >= 2) {
        final markers = _orderMarkers[index]!.toList();
        final bounds = _calculateBounds(
          markers.map((marker) => marker.position).toList()
        );
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
      }
    }
  }
  
  // Calculate bounds to fit all points
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

  // Widget for empty history view
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
                Symbols.local_shipping,
                color: highlightColor,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sem Entregas Anteriores',
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
                'Você ainda não realizou nenhuma entrega. Seu histórico de entregas aparecerá aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/entregador/delivery_orderslist'),
              style: FilledButton.styleFrom(
                backgroundColor: highlightColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Symbols.search, color: Colors.white),
              label: const Text(
                'Procurar Entregas',
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
  
  // Build map or static placeholder based on visibility
  Widget _buildMapForOrder(int index, ds_order.Order order) {
    final originLocation = LatLng(
      order.originLocation.latitude, 
      order.originLocation.longitude
    );
    
    final destinationLocation = LatLng(
      order.destinationLocation.latitude,
      order.destinationLocation.longitude
    );
    
    // Center position between origin and destination
    final centerPosition = LatLng(
      (originLocation.latitude + destinationLocation.latitude) / 2,
      (originLocation.longitude + destinationLocation.longitude) / 2,
    );
    
    // Use a container key to track this map's visibility
    final containerKey = _getMapContainerKey(index);
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        key: containerKey,
        height: 140,
        width: double.infinity,
        color: const Color(0xFF1A1A1A),
        child: Stack(
          children: [
            // Always show the map - it will be created and rendered when visible
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: centerPosition,
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
              liteModeEnabled: !_visibleItems.contains(index), // Use lite mode for non-visible maps
            ),
            
            // Loading indicator while route is being fetched
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
          'Histórico de Entregas',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
            color: highlightColor,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Main content
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
              ),
            )
          else if (_orders.isEmpty)
            _buildEmptyHistoryView()
          else
            // Use ListView.builder with scroll controller
            ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              itemCount: _orders.length,
              cacheExtent: 500, // Increase cache to help with scrolling
              itemBuilder: (context, index) {
                final order = _orders[index];
                
                // Formatted date
                final createdAtFormatted = DateFormat('dd/MM/yyyy HH:mm')
                    .format(order.createdAt);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      print('Navegando para resumo com orderId: ${order.id}');
                      context.go('/entregador/delivery_ordersummary', extra: {'orderId': order.id});
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
                          // Map area
                          _buildMapForOrder(index, order),
                          
                          // Card content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with ID and Date
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
                                
                                // Addresses
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
                                
                                // Footer
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Status badge
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
                                    
                                    // Rating
                                    Row(
                                      children: [
                                        Icon(Symbols.star, color: highlightColor, size: 18),
                                        const SizedBox(width: 4),
                                        Text(
                                          '4.9',
                                          style: TextStyle(
                                            color: highlightColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
          
          // Bottom navigation bar
          Positioned(
            bottom: 20,
            left: horizontalMargin,
            right: horizontalMargin,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
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
                  _buildNavItem(Symbols.history, 'Histórico', 0, _currentIndex == 0),
                  _buildNavItem(Symbols.list_alt, 'Pedidos', 1, _currentIndex == 1),
                  _buildNavItem(Symbols.home, 'Início', 2, _currentIndex == 2),
                  _buildNavItem(Symbols.person, 'Perfil', 3, _currentIndex == 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widgets
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

  // Helper for status colors
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
  
  // Helper for status text
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

  Widget _buildNavItem(IconData icon, String label, int index, bool selected) {
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