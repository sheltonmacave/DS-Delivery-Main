import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import '../../services/order_service.dart';
import '../../models/order_model.dart' as ds_order;

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  late VideoPlayerController _videoController;
  late Timer _timer;
  bool _showGreeting = true;
  bool _showUI = true;
  int _currentIndex = 1;
  GoogleMapController? _mapController;
  final OrderService _orderService = OrderService();
  ds_order.Order? _activeOrder;
  bool _isLoadingOrder = true;

  final Color highlightColor = const Color(0xFFFF6A00);

  static const String _darkMapStyle = '''
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
    _videoController = VideoPlayerController.asset('assets/videos/sondella.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.setLooping(true);
        _videoController.setVolume(0.0);
        _videoController.play();
      }).catchError((e) {
        debugPrint("Erro ao carregar vídeo: $e");
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted) {
          setState(() {
            _showGreeting = !_showGreeting;
          });
        }
      });
      
      _checkActiveOrder();
    });
  }
  
  // Verificar se o cliente tem um pedido ativo
  Future<void> _checkActiveOrder() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoadingOrder = false;
      });
      return;
    }
    
    try {
      final activeOrders = await _orderService.getClientActiveOrdersOnce(currentUser.uid);
      
      // Verificar se o widget ainda está montado antes de atualizar o estado
      if (!mounted) return;
      
      setState(() {
        _activeOrder = activeOrders.isNotEmpty ? activeOrders.first : null;
        _isLoadingOrder = false;
      });
    } catch (e) {
      print('Erro ao verificar pedidos ativos: $e');
      
      if (!mounted) return;
      
      setState(() {
        _activeOrder = null;
        _isLoadingOrder = false;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _videoController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'Bom dia';
    if (hour >= 12 && hour < 18) return 'Boa tarde';
    if (hour >= 18 && hour <= 23) return 'Boa noite';
    return 'Boa madrugada';
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go('/cliente/client_history');
        break;
      case 1:
        context.go('/cliente/client_home');
        break;
      case 2:
        context.go('/cliente/client_profile');
        break;
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
  
  // Widget para o card de pedido ativo
  Widget _buildActiveOrderCard() {
    if (_activeOrder == null) return const SizedBox.shrink();
    
    // Verifica o ID
    final String orderId = _activeOrder!.id ?? 'N/A';
    final String displayId = orderId != 'N/A' ? orderId.substring(0, min(4, orderId.length)) : 'N/A';
    
    // Verifica os endereços
    final String originAddress = _activeOrder!.originAddress.isNotEmpty 
        ? _activeOrder!.originAddress 
        : 'Endereço de origem indisponível';
        
    final String destinationAddress = _activeOrder!.destinationAddress.isNotEmpty 
        ? _activeOrder!.destinationAddress 
        : 'Endereço de destino indisponível';
    
    String statusText;
    IconData statusIcon;
    
    switch (_activeOrder!.status) {
      case ds_order.OrderStatus.pending:
        statusText = 'Aguardando entregador';
        statusIcon = Symbols.hourglass_empty;
        break;
      case ds_order.OrderStatus.driverAssigned:
        statusText = 'Entregador a caminho';
        statusIcon = Symbols.person;
        break;
      case ds_order.OrderStatus.pickedUp:
        statusText = 'Pedido coletado';
        statusIcon = Symbols.inventory;
        break;
      case ds_order.OrderStatus.inTransit:
        statusText = 'Pedido em trânsito';
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
        border: Border.all(color: highlightColor),
        boxShadow: [
          BoxShadow(
            color: highlightColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        'Pedido em Andamento',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: highlightColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ID #${_activeOrder!.id!.substring(0, 4)}',
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
          
          // Informações do pedido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Endereços
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Symbols.location_on, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Origem:',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(_activeOrder!.originAddress,
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
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(_activeOrder!.destinationAddress,
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
                      context.go('/cliente/client_orderstate', extra: {'orderId': _activeOrder!.id});
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: highlightColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Symbols.map, size: 18),
                    label: const Text('Acompanhar Pedido'),
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
    final double horizontalMargin = MediaQuery.of(context).size.width * 0.05;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: Text(
          _showGreeting ? _getGreeting() : 'DS Delivery',
          style: TextStyle(
            color: highlightColor,
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showUI ? Symbols.visibility_off : Symbols.visibility, color: highlightColor),
            onPressed: () => setState(() => _showUI = !_showUI),
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _mapController!.setMapStyle(_darkMapStyle);
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(-25.9692, 32.5732), // Maputo, Mozambique
              zoom: 13.0,
            ),
            mapType: MapType.normal,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          IgnorePointer(
            ignoring: !_showUI,
            child: AnimatedOpacity(
              opacity: _showUI ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Chame Um Motorista Onde Estiveres!',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    FilledButton(
                      onPressed: _activeOrder != null 
                        ? null // Desabilita se houver pedido ativo
                        : () {
                            context.go('/cliente/client_createorder');
                          },
                      style: FilledButton.styleFrom(
                        backgroundColor: _activeOrder != null
                          ? Colors.grey.shade800
                          : highlightColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Symbols.add_circle, 
                            color: _activeOrder != null
                              ? Colors.grey
                              : Colors.white,
                            size: 26),
                          const SizedBox(width: 8),
                          Text(
                            'Criar Pedido',
                            style: TextStyle(
                              color: _activeOrder != null
                                ? Colors.grey
                                : Colors.white,
                              fontSize: 16
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Mostrar card de pedido ativo se existir
                    if (_isLoadingOrder)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(color: highlightColor),
                        ),
                      )
                    else if (_activeOrder != null)
                      _buildActiveOrderCard(),

                    const SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _videoController.value.isInitialized
                            ? VideoPlayer(_videoController)
                            : Container(
                                color: Colors.white10,
                                child: Center(
                                  child: CircularProgressIndicator(color: highlightColor),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 20,
            left: horizontalMargin,
            right: horizontalMargin,
            child: AnimatedOpacity(
              opacity: _showUI ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
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
          ),
        ],
      ),
    );
  }
}