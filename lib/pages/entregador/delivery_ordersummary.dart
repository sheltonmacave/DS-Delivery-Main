import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import 'package:ds_delivery/wrappers/back_handler.dart';

class DeliveryOrderSummaryPage extends StatefulWidget {
  final Map<String, dynamic>? extra;

  const DeliveryOrderSummaryPage({super.key, this.extra});

  @override
  State<DeliveryOrderSummaryPage> createState() =>
      _DeliveryOrderSummaryPageState();
}

class _DeliveryOrderSummaryPageState extends State<DeliveryOrderSummaryPage> {
  final Color highlightColor = const Color(0xFFFF6A00);
  final OrderService _orderService = OrderService();

  bool _isLoading = true;
  Order? _order;
  String? _orderId;

  // Google Maps variables
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _mapLoaded = false;

  @override
  void initState() {
    super.initState();
    // Extrair o orderId do objeto extra
    _orderId = widget.extra?['orderId'] as String?;
    print('OrderID recebido: $_orderId');
    _loadOrderDetails();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    try {
      if (_orderId == null || _orderId!.isEmpty) {
        print('OrderID nulo ou vazio');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      print('Buscando detalhes do pedido: $_orderId');
      final order = await _orderService.getOrderByIdOnce(_orderId!);

      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });

        print('Dados carregados: ${order?.id ?? 'null'}');
      }
    } catch (e) {
      print('Erro ao carregar detalhes do pedido: $e');
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar detalhes do pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler(
        alternativeRoute: '/entregador/delivery_history',
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          appBar: AppBar(
            backgroundColor: Colors.black.withOpacity(0.6),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Symbols.arrow_back_ios, color: Colors.white),
              onPressed: () => context.go('/entregador/delivery_history'),
            ),
            title: const Text(
              'Resumo da Entrega',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
                  ),
                )
              : _order == null
                  ? _buildErrorView()
                  : _buildOrderSummary(_order!),
        ));
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Pedido não encontrado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'ID: ${_orderId ?? 'Desconhecido'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/entregador/delivery_history'),
            style: FilledButton.styleFrom(
              backgroundColor: highlightColor,
            ),
            child: const Text('Voltar para Histórico'),
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfo(Order order) {
    return FutureBuilder<firestore.DocumentSnapshot>(
      future: firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(order.clientId)
          .get(),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informações do Cliente',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (!snapshot.hasData)
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey,
                      child:
                          Icon(Symbols.person, color: Colors.white54, size: 30),
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
                )
              else ...[
                Builder(
                  builder: (context) {
                    final clientData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    final clientName =
                        order.clientName ?? clientData?['name'] ?? 'Cliente';
                    final clientPhone =
                        order.clientPhone ?? clientData?['phone'] ?? '';
                    final clientPhoto = clientData?['photoURL'];
                    final clientRating = clientData?['rating'] ?? 5.0;

                    return Row(
                      children: [
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clientName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Seu cliente',
                                style: TextStyle(
                                    color: Colors.grey.shade300, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                        if (clientPhone.isNotEmpty)
                          Row(
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Symbols.call,
                                    color: highlightColor, size: 20),
                                onPressed: () async {
                                  final Uri phoneUri =
                                      Uri.parse('tel:$clientPhone');
                                  try {
                                    await launchUrl(phoneUri);
                                  } catch (e) {
                                    print('Erro ao fazer chamada: $e');
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Symbols.sms,
                                    color: highlightColor, size: 20),
                                onPressed: () async {
                                  final Uri smsUri =
                                      Uri.parse('sms:$clientPhone');
                                  try {
                                    await launchUrl(smsUri);
                                  } catch (e) {
                                    print('Erro ao enviar SMS: $e');
                                  }
                                },
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary(Order order) {
    // Data formatada
    final createdAtFormatted =
        DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);

    // Valor do ganho do entregador (80% do valor do pedido)
    final earnings = order.price * 0.8;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card principal com estilo similar ao do histórico
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: highlightColor.withOpacity(0.4), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mapa no topo com rota
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: _buildMapWithRoute(order),
                  ),
                ),

                // Informações do pedido
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status do pedido
                      _buildStatusRow(order.status),
                      const SizedBox(height: 16),

                      // ID e Data
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailChip(Symbols.numbers,
                              'ID: #${order.id!.substring(0, 4)}'),
                          _buildDetailChip(
                              Symbols.calendar_month, createdAtFormatted),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Endereços
                      _buildAddressRow(
                        Symbols.location_on,
                        'Origem:',
                        order.originAddress,
                        const Color(0xFFFF6A00),
                      ),
                      const SizedBox(height: 8),
                      _buildAddressRow(
                        Symbols.flag,
                        'Destino:',
                        order.destinationAddress,
                        Colors.blue,
                      ),

                      const Divider(color: Colors.white10, height: 24),

                      // Detalhes do pedido
                      _buildDetailRow('Transporte', order.transportType),
                      _buildDetailRow('Distância',
                          '${order.distance.toStringAsFixed(1)} km'),
                      _buildDetailRow('Tempo', order.estimatedTime),
                      _buildDetailRow(
                          'Ganhos', '${earnings.toStringAsFixed(0)} MT'),

                      if (order.observations != null &&
                          order.observations!.isNotEmpty) ...[
                        const Divider(color: Colors.white10, height: 24),
                        const Text(
                          'Observações:',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            order.observations!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Informações do cliente
          ...[
            _buildClientInfo(order),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // Interactive map with route
  Widget _buildMapWithRoute(Order order) {
    final originLocation =
        LatLng(order.originLocation.latitude, order.originLocation.longitude);

    final destinationLocation = LatLng(order.destinationLocation.latitude,
        order.destinationLocation.longitude);

    // Center position between origin and destination
    final centerPosition = LatLng(
      (originLocation.latitude + destinationLocation.latitude) / 2,
      (originLocation.longitude + destinationLocation.longitude) / 2,
    );

    // Create markers if they haven't been created yet
    if (_markers.isEmpty) {
      _markers = {
        Marker(
          markerId: const MarkerId('origin'),
          position: originLocation,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: destinationLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      };
    }

    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: centerPosition,
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            mapType: MapType.normal,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;

              // Apply dark style
              controller.setMapStyle('''
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
              ''');

              // Fetch route after map is ready
              _fetchRoutePoints(order);
            },
          ),

          // Loading indicator
          if (!_mapLoaded)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(highlightColor),
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
    );
  }

  // Add this method to fetch route points
  Future<void> _fetchRoutePoints(Order order) async {
    if (_mapController == null) return;

    final originLocation =
        LatLng(order.originLocation.latitude, order.originLocation.longitude);

    final destinationLocation = LatLng(order.destinationLocation.latitude,
        order.destinationLocation.longitude);

    try {
      const String googleAPIKey = 'AIzaSyCNlTXTSlKc2cCyGbWKqKCIkRN4JMiY1tQ';

      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${originLocation.latitude},${originLocation.longitude}'
          '&destination=${destinationLocation.latitude},${destinationLocation.longitude}'
          '&mode=driving'
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
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  color: highlightColor,
                  points: polylineCoordinates,
                  width: 4,
                  patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                ),
              );
              _mapLoaded = true;
            });

            // Adjust camera to show the whole route
            _mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(
                _calculateBounds(polylineCoordinates),
                50,
              ),
            );
          }
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

  // Create a straight line fallback
  void _createStraightLine(LatLng origin, LatLng destination) {
    if (mounted && _mapController != null) {
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: highlightColor,
            points: [origin, destination],
            width: 4,
          ),
        );
        _mapLoaded = true;
      });

      // Adjust the camera
      final bounds = _calculateBounds([origin, destination]);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  // Calculate bounds for the map
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

  Widget _buildStatusRow(OrderStatus status) {
    final isCompleted =
        (status == OrderStatus.delivered || status == OrderStatus.cancelled);
    final isDelivered = status == OrderStatus.delivered;

    return Row(
      children: [
        Icon(
          isDelivered
              ? Symbols.check_circle
              : (isCompleted ? Symbols.cancel : Symbols.pending),
          color: isDelivered
              ? Colors.green
              : (isCompleted ? Colors.red : highlightColor),
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          isDelivered
              ? 'Entrega concluída'
              : (isCompleted ? 'Entrega cancelada' : 'Em andamento'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
