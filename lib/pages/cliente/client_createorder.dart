import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/order_model.dart' as ds_order;
import '../../services/order_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../../services/notifications_service.dart';
import 'package:ds_delivery/wrappers/back_handler.dart';

class ClientCreateOrderPage extends StatefulWidget {
  const ClientCreateOrderPage({super.key});

  @override
  State<ClientCreateOrderPage> createState() => _ClientCreateOrderPageState();
}

class _ClientCreateOrderPageState extends State<ClientCreateOrderPage> {
  final Color highlightColor = const Color(0xFFFF6A00);
  final Set<int> _selectedTransportIndices = {};
  bool _isBottomSheetOpen = true;
  final OrderService _orderService = OrderService();

  // Marker points
  LatLng? _originPoint;
  LatLng? _destinationPoint;
  bool _isSelectingOrigin = false;
  bool _isSelectingDestination = false;

  // Dados de rota
  double? _routeDistanceKm;
  String? _routeDuration;

  // Google Maps
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Marker> _poiMarkers = {}; // POI markers
  final Set<Polyline> _polylines = {};

  // Controllers
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _observationsController = TextEditingController();
  final DraggableScrollableController _scrollController =
      DraggableScrollableController();

  // Sugestões
  List<Map<String, dynamic>> _originSuggestions = [];
  List<Map<String, dynamic>> _destinationSuggestions = [];
  bool _showOriginSuggestions = false;
  bool _showDestinationSuggestions = false;

  // Dark style para Google Maps
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
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _observationsController.dispose();
    _scrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  bool _validateOrderData() {
    // Validar origem
    if (_originPoint == null || _originController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, selecione um ponto de origem')),
      );
      return false;
    }

    // Validar destino
    if (_destinationPoint == null || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, selecione um ponto de destino')),
      );
      return false;
    }

    // Validar tipo de transporte
    if (_selectedTransportIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, selecione um tipo de transporte')),
      );
      return false;
    }

    // Validar se a rota foi calculada
    if (_routeDistanceKm == null || _routeDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Por favor, aguarde o cálculo da rota ou tente novamente')),
      );
      return false;
    }

    return true;
  }

  // Método para obter localização atual
  Future<LatLng?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Os serviços de localização estão desativados. Por favor, ative-os.')),
        );
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('As permissões de localização foram negadas.')),
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'As permissões de localização foram permanentemente negadas. Abra as configurações para ativar.')),
        );
        return null;
      }

      final position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print("Erro ao obter localização atual: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao obter localização: $e')),
      );
      return null;
    }
  }

  // Definir localização atual como origem ou destino
  Future<void> _setCurrentLocation(bool isOrigin) async {
    final currentLocation = await _getCurrentLocation();
    if (currentLocation != null) {
      try {
        // Obter o nome do local usando Geocoding API
        const apiKey = 'AIzaSyCNlTXTSlKc2cCyGbWKqKCIkRN4JMiY1tQ';
        final url = Uri.https(
          'maps.googleapis.com',
          '/maps/api/geocode/json',
          {
            'latlng':
                '${currentLocation.latitude},${currentLocation.longitude}',
            'key': apiKey,
          },
        );

        final response = await http.get(url);
        String locationName = "Localização Atual";

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && data['results'].isNotEmpty) {
            locationName = data['results'][0]['formatted_address'];
          }
        }

        setState(() {
          if (isOrigin) {
            _originPoint = currentLocation;
            _originController.text = locationName;
          } else {
            _destinationPoint = currentLocation;
            _destinationController.text = locationName;
          }
        });

        _updateMarkers();
        if (_originPoint != null && _destinationPoint != null) {
          _updateRoutePolyline();
        }

        _moveCamera(currentLocation);
      } catch (e) {
        print("Erro ao definir localização atual: $e");
      }
    }
  }

  Future<void> _searchPlaces(String query, bool isOrigin) async {
    if (query.length < 2) {
      setState(() {
        if (isOrigin) {
          _showOriginSuggestions = false;
        } else {
          _showDestinationSuggestions = false;
        }
      });
      return;
    }

    // IMPORTANT: Use a backend proxy or environment variables in production
    const apiKey = 'AIzaSyCNlTXTSlKc2cCyGbWKqKCIkRN4JMiY1tQ';
    final sessionToken = const Uuid().v4();

    try {
      final url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'key': apiKey,
          'sessiontoken': sessionToken,
          'components': 'country:mz', // Limit to Mozambique
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = List<Map<String, dynamic>>.from(
            data['predictions'].map((x) => x as Map<String, dynamic>));

        setState(() {
          if (isOrigin) {
            _originSuggestions = predictions;
            _showOriginSuggestions = predictions.isNotEmpty;
          } else {
            _destinationSuggestions = predictions;
            _showDestinationSuggestions = predictions.isNotEmpty;
          }
        });
      }
    } catch (e) {
      print('Error fetching place suggestions: $e');
    }
  }

  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    const apiKey = 'AIzaSyCNlTXTSlKc2cCyGbWKqKCIkRN4JMiY1tQ';

    try {
      final url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'key': apiKey,
          'fields': 'name,geometry,formatted_address',
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return data['result'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching place details: $e');
      return null;
    }
  }

  Future<void> _selectPlace(
      Map<String, dynamic> prediction, bool isOrigin) async {
    final placeId = prediction['place_id'];
    final placeDetails = await _getPlaceDetails(placeId);

    if (placeDetails != null) {
      final lat = placeDetails['geometry']['location']['lat'];
      final lng = placeDetails['geometry']['location']['lng'];
      final name = prediction['description'];

      setState(() {
        if (isOrigin) {
          _originPoint = LatLng(lat, lng);
          _originController.text = name;
          _showOriginSuggestions = false;
        } else {
          _destinationPoint = LatLng(lat, lng);
          _destinationController.text = name;
          _showDestinationSuggestions = false;
        }
      });

      _updateMarkers();
      if (_originPoint != null && _destinationPoint != null) {
        _updateRoutePolyline();
      }

      _moveCamera(LatLng(lat, lng));
    }
  }

  // Reimplementado para buscar POIs no mapa
  Future<void> _searchNearbyPlaces(LatLng location) async {
    // Esta função está vazia para evitar adicionar marcadores roxos indesejados
  }

  Future<void> _handlePoiClick(Map<String, dynamic> poi) async {
    if (_isSelectingOrigin) {
      setState(() {
        _originPoint = poi['latLng'];
        _originController.text = poi['name'];
        _isSelectingOrigin = false;
      });
    } else if (_isSelectingDestination) {
      setState(() {
        _destinationPoint = poi['latLng'];
        _destinationController.text = poi['name'];
        _isSelectingDestination = false;
      });
    }

    _updateMarkers();
    if (_originPoint != null && _destinationPoint != null) {
      _updateRoutePolyline();
    }
  }

  void _showPoiSelectionDialog(Map<String, dynamic> poi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(poi['name'], style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poi['vicinity'],
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            const Text('Deseja usar este local como:',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _originController.text = poi['name'];
                _originPoint = poi['position'];
              });
              _updateMarkers();
              if (_originPoint != null && _destinationPoint != null) {
                _updateRoutePolyline();
              }
            },
            child: const Text('Origem'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _destinationController.text = poi['name'];
                _destinationPoint = poi['position'];
              });
              _updateMarkers();
              if (_originPoint != null && _destinationPoint != null) {
                _updateRoutePolyline();
              }
            },
            child: const Text('Destino'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _updateMarkers() {
    _markers.removeWhere((marker) =>
        marker.markerId.value == "origin" ||
        marker.markerId.value == "destination");

    if (_originPoint != null) {
      _markers.add(
        Marker(
            markerId: const MarkerId("origin"),
            position: _originPoint!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
                title: _originController.text != "Localização selecionada"
                    ? _originController.text
                    : "Origem"),
            zIndex: 2,
            onTap: () {
              if (_isSelectingOrigin) {
                setState(() {
                  _originController.text =
                      _originController.text != "Localização selecionada"
                          ? _originController.text
                          : "Origem";
                  _isSelectingOrigin = false;
                });
              } else if (_isSelectingDestination) {
                setState(() {
                  _destinationController.text =
                      _originController.text != "Localização selecionada"
                          ? _originController.text
                          : "Origem";
                  _destinationPoint = _originPoint;
                  _isSelectingDestination = false;
                  _updateRoutePolyline();
                });
              }
            }),
      );
    }

    if (_destinationPoint != null) {
      _markers.add(
        Marker(
            markerId: const MarkerId("destination"),
            position: _destinationPoint!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
                title: _destinationController.text != "Localização selecionada"
                    ? _destinationController.text
                    : "Destino"),
            zIndex: 2,
            onTap: () {
              if (_isSelectingOrigin) {
                setState(() {
                  _originController.text =
                      _destinationController.text != "Localização selecionada"
                          ? _destinationController.text
                          : "Destino";
                  _originPoint = _destinationPoint;
                  _isSelectingOrigin = false;
                  _updateRoutePolyline();
                });
              } else if (_isSelectingDestination) {
                setState(() {
                  _destinationController.text =
                      _destinationController.text != "Localização selecionada"
                          ? _destinationController.text
                          : "Destino";
                  _isSelectingDestination = false;
                });
              }
            }),
      );
    }

    setState(() {});
  }

  void _handleMarkerTap(String markerId) {}

  void _handleMapTap(LatLng point) {
    if (_isSelectingOrigin) {
      setState(() {
        _originPoint = point;
        _originController.text = "Localização selecionada";
        _isSelectingOrigin = false;
      });
      _updateMarkers();
      if (_originPoint != null && _destinationPoint != null) {
        _updateRoutePolyline();
      }
    } else if (_isSelectingDestination) {
      setState(() {
        _destinationPoint = point;
        _destinationController.text = "Localização selecionada";
        _isSelectingDestination = false;
      });
      _updateMarkers();
      if (_originPoint != null && _destinationPoint != null) {
        _updateRoutePolyline();
      }
    }
  }

  Future<void> _addPlacesOfInterestMarkers() async {
    try {
      const apiKey = 'AIzaSyCNlTXTSlKc2cCyGbWKqKCIkRN4JMiY1tQ';

      // Pegue o centro da visualização atual do mapa
      final visibleRegion = await _mapController?.getVisibleRegion();
      if (visibleRegion == null) return;

      // Calcular o centro
      final center = LatLng(
        (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) /
            2,
        (visibleRegion.northeast.longitude +
                visibleRegion.southwest.longitude) /
            2,
      );

      final url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/nearbysearch/json',
        {
          'location': '${center.latitude},${center.longitude}',
          'radius': '1500', // 1.5km de raio
          'key': apiKey,
          'language': 'pt',
          'type': 'point_of_interest', // Pontos de interesse
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;

          // Limpar marcadores antigos de POI
          _markers.removeWhere(
              (marker) => marker.markerId.value.startsWith('poi_'));

          // Adicionar novos marcadores
          for (var place in results) {
            final placeId = place['place_id'] as String;
            final name = place['name'] as String;
            final lat = place['geometry']['location']['lat'] as double;
            final lng = place['geometry']['location']['lng'] as double;
            final position = LatLng(lat, lng);

            _markers.add(
              Marker(
                markerId: MarkerId('poi_$placeId'),
                position: position,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueViolet),
                infoWindow: InfoWindow(title: name),
                onTap: () => _handlePoiMarkerTap(name, position),
              ),
            );
          }

          setState(() {});
        }
      }
    } catch (e) {
      print('Erro ao carregar pontos de interesse: $e');
    }
  }

  void _handlePoiMarkerTap(String name, LatLng position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(name, style: const TextStyle(color: Colors.white)),
        content: const Text(
          'Deseja usar este local como origem ou destino?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _originPoint = position;
                _originController.text = name;
              });
              _updateMarkers();
              if (_originPoint != null && _destinationPoint != null) {
                _updateRoutePolyline();
              }
            },
            child: const Text('Origem'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _destinationPoint = position;
                _destinationController.text = name;
              });
              _updateMarkers();
              if (_originPoint != null && _destinationPoint != null) {
                _updateRoutePolyline();
              }
            },
            child: const Text('Destino'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _startSelectingOnMap(bool isOrigin) {
    setState(() {
      if (isOrigin) {
        _isSelectingOrigin = true;
        _isSelectingDestination = false;
      } else {
        _isSelectingOrigin = false;
        _isSelectingDestination = true;
      }

      _scrollController.animateTo(
        0.1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isOrigin
              ? 'Toque no mapa para selecionar a origem'
              : 'Toque no mapa para selecionar o destino',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: highlightColor,
      ),
    );
  }

  // Atualizado para calcular distância e duração
  Future<void> _updateRoutePolyline() async {
    if (_originPoint != null && _destinationPoint != null) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
            ),
          ),
        );

        const apiKey = 'AIzaSyCNlTXTSlKc2cCyGbWKqKCIkRN4JMiY1tQ';

        final url = Uri.https(
          'maps.googleapis.com',
          '/maps/api/directions/json',
          {
            'origin': '${_originPoint!.latitude},${_originPoint!.longitude}',
            'destination':
                '${_destinationPoint!.latitude},${_destinationPoint!.longitude}',
            'key': apiKey,
          },
        );

        final response = await http.get(url);

        // Close loading indicator
        Navigator.of(context, rootNavigator: true).pop();

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['status'] == 'OK') {
            // Decode polyline points
            final points = data['routes'][0]['overview_polyline']['points'];
            final polylinePoints = PolylinePoints().decodePolyline(points);

            final List<LatLng> polylineCoordinates = polylinePoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();

            // Extrair informações de distância e duração
            final legs = data['routes'][0]['legs'][0];
            final distanceText = legs['distance']['text'];
            final distanceValue = legs['distance']['value'] / 1000; // em km
            final durationText = legs['duration']['text'];

            setState(() {
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  color: highlightColor,
                  points: polylineCoordinates,
                  width: 5,
                ),
              );

              _routeDistanceKm = distanceValue;
              _routeDuration = durationText;
            });

            // Adjust the camera to show both origin and destination
            final LatLngBounds bounds =
                _calculateBounds([_originPoint!, _destinationPoint!]);
            _mapController
                ?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
          }
        }
      } catch (e) {
        // Close loading indicator in case of error
        Navigator.of(context, rootNavigator: true).pop();

        print('Error getting route: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calculating route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _moveCamera(LatLng target, [double zoom = 15]) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: zoom,
        ),
      ),
    );
  }

  // Método para carregar POIs quando o mapa é movido
  void _loadPoisOnCameraMoved() {
    _mapController?.addListener(() async {
      if (_mapController != null) {
        final position = await _mapController!.getVisibleRegion();
        final center = LatLng(
          (position.northeast.latitude + position.southwest.latitude) / 2,
          (position.northeast.longitude + position.southwest.longitude) / 2,
        );

        // Carregamos POIs sempre que a posição da câmera for alterada significativamente
        _searchNearbyPlaces(center);
      }
    });
  }

  final List<Map<String, dynamic>> _transports = [
    {
      'name': 'Motorizada',
      'description': 'Entregas Mais Rápidas',
      'price': '15MT/km',
      'image': 'assets/images/moto.png',
    },
    {
      'name': 'Carro',
      'description': 'Maior Capacidade de Carga',
      'price': '30MT/km',
      'image': 'assets/images/carro.png',
    },
  ];

  void _showConfirmationDialog() async {
    // Validar dados antes de mostrar o diálogo de confirmação
    if (!_validateOrderData()) {
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.signal_wifi_off, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Sem conexão com a internet. O pedido será salvo localmente e enviado quando houver conexão.'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.75),
                  border: Border.all(color: highlightColor, width: 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Symbols.info, color: highlightColor, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Tens a certeza que queres confirmar o pedido?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            backgroundColor: const Color(0xFF2A2A2A),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Não'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(dialogContext);

                            // Criar um contexto temporário para o diálogo de carregamento
                            BuildContext? loadingDialogContext;

                            // Mostrar indicador de carregamento
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) {
                                loadingDialogContext = ctx;
                                return Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        highlightColor),
                                  ),
                                );
                              },
                            );

                            try {
                              // Verificar autenticação
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;
                              if (currentUser == null) {
                                throw Exception("Usuário não autenticado");
                              }

                              // Criar objeto do pedido
                              String transportName = "Não selecionado";
                              if (_selectedTransportIndices.isNotEmpty) {
                                int selectedIndex =
                                    _selectedTransportIndices.first;
                                transportName =
                                    _transports[selectedIndex]['name'];
                              }

                              final newOrder = ds_order.Order(
                                clientId: currentUser.uid,
                                originAddress: _originController.text,
                                destinationAddress: _destinationController.text,
                                originLocation: ds_order.GeoPoint(
                                  latitude: _originPoint!.latitude,
                                  longitude: _originPoint!.longitude,
                                ),
                                destinationLocation: ds_order.GeoPoint(
                                  latitude: _destinationPoint!.latitude,
                                  longitude: _destinationPoint!.longitude,
                                ),
                                transportType: transportName,
                                distance: _routeDistanceKm ?? 0.0,
                                estimatedTime: _routeDuration ?? "20 min",
                                price: _calculateTotalPrice(),
                                observations: _observationsController.text,
                                status: ds_order.OrderStatus.pending,
                                createdAt: DateTime.now(),
                                statusUpdates: [
                                  ds_order.StatusUpdate(
                                    status: ds_order.OrderStatus.pending,
                                    timestamp: DateTime.now(),
                                    description:
                                        'Pedido criado, aguardando entregador',
                                  ),
                                ],
                              );

                              // Salvar no Firestore
                              final orderId =
                                  await _orderService.createOrder(newOrder);

                              // Fechar o indicador de carregamento de forma segura
                              if (loadingDialogContext != null &&
                                  Navigator.canPop(loadingDialogContext!)) {
                                Navigator.pop(loadingDialogContext!);
                              }

                              // Verificar se o widget ainda está montado
                              if (!mounted) return;

                              showLocalNotification(
                                title: 'Pedido Criado',
                                body:
                                    'Procurando Entregador para a sua entrega',
                              );

                              // Navegar para a tela de acompanhamento
                              context.go('/cliente/client_orderstate',
                                  extra: {'orderId': orderId});
                            } catch (e) {
                              // Fechar o indicador de carregamento de forma segura
                              if (loadingDialogContext != null &&
                                  Navigator.canPop(loadingDialogContext!)) {
                                Navigator.pop(loadingDialogContext!);
                              }

                              // Verificar se o widget ainda está montado
                              if (!mounted) return;

                              // Mostrar erro
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao criar pedido: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 10),
                                  action: SnackBarAction(
                                    label: 'OK',
                                    onPressed: () {},
                                  ),
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: highlightColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Sim'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Método para calcular o preço total
  double _calculateTotalPrice() {
    if (_routeDistanceKm != null && _selectedTransportIndices.isNotEmpty) {
      int selectedIndex = _selectedTransportIndices.first;
      int pricePerKm = int.parse(_transports[selectedIndex]['price']
          .replaceAll(RegExp(r'[^0-9]'), ''));
      return _routeDistanceKm! * pricePerKm;
    }
    return 0.0;
  }

  // Bottom sheet de resumo atualizado
  void _showOrderSummarySheet() {
    // Validar dados antes de mostrar a folha de resumo
    if (!_validateOrderData()) {
      return;
    }

    String transportName = "Não selecionado";
    String transportPrice = "0 MT/km";
    if (_selectedTransportIndices.isNotEmpty) {
      int selectedIndex = _selectedTransportIndices.first;
      transportName = _transports[selectedIndex]['name'];
      transportPrice = _transports[selectedIndex]['price'];
    }

    // Calcular valor estimado
    String valorEstimado = "Calcular rota primeiro";
    if (_routeDistanceKm != null && _selectedTransportIndices.isNotEmpty) {
      int selectedIndex = _selectedTransportIndices.first;
      int pricePerKm = int.parse(_transports[selectedIndex]['price']
          .replaceAll(RegExp(r'[^0-9]'), ''));
      int totalValue = (_routeDistanceKm! * pricePerKm).round();
      valorEstimado = "$totalValue MT";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
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
            _buildBottomSheetRow(
                Symbols.location_on,
                'Origem',
                _originController.text.isNotEmpty
                    ? _originController.text
                    : 'Não especificado'),
            _buildBottomSheetRow(
                Symbols.flag,
                'Destino',
                _destinationController.text.isNotEmpty
                    ? _destinationController.text
                    : 'Não especificado'),
            _buildBottomSheetRow(
                Symbols.local_shipping, 'Transporte', transportName),
            _buildBottomSheetRow(
                Symbols.straighten,
                'Distância',
                _routeDistanceKm != null
                    ? "${_routeDistanceKm!.toStringAsFixed(1)} km"
                    : "Calcular rota primeiro"),
            _buildBottomSheetRow(Symbols.timer, 'Tempo Estimado',
                _routeDuration ?? "Calcular rota primeiro"),
            _buildBottomSheetRow(
                Symbols.attach_money, 'Valor Estimado', valorEstimado),
            _buildBottomSheetRow(
                Symbols.notes,
                'Observações',
                _observationsController.text.isNotEmpty
                    ? _observationsController.text
                    : 'Sem observações'),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: highlightColor,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _showConfirmationDialog,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Confirmar Pedido',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Icon(
                    Symbols.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: highlightColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler(
        alternativeRoute: '/cliente/client_home',
        child: Scaffold(
          body: Stack(
            children: [
              // Google Maps
              SizedBox.expand(
                child: GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    _mapController!.setMapStyle(_darkMapStyle);
                    // Não precisamos mais buscar POIs aqui
                  },
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(-25.9692, 32.5732), // Maputo, Moçambique
                    zoom: 13.0,
                  ),
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  markers: _markers,
                  polylines: _polylines,
                  onTap: _handleMapTap,
                ),
              ),

              // App Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: AppBar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    elevation: 0,
                    title: const Text(
                      'Criar Pedido',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    leading: IconButton(
                      icon: const Icon(Symbols.arrow_back, color: Colors.white),
                      onPressed: () => context.go('/cliente/client_home'),
                    ),
                  ),
                ),
              ),

              // Mensagem de instrução quando estiver selecionando no mapa
              if (_isSelectingOrigin || _isSelectingDestination)
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isSelectingOrigin
                          ? 'Toque no mapa para marcar o ponto de origem'
                          : 'Toque no mapa para marcar o ponto de destino',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

              // Bottom sheet com limites adequados
              if (_isBottomSheetOpen)
                DraggableScrollableSheet(
                  initialChildSize: 0.5,
                  minChildSize: 0.1,
                  maxChildSize: 0.9,
                  snap: true,
                  snapSizes: const [0.1, 0.5, 0.9],
                  controller: _scrollController,
                  builder: (context, scrollController) {
                    // Monitorar posição do bottom sheet
                    _scrollController.addListener(() {
                      if (_scrollController.size <= 0.15 &&
                          _isBottomSheetOpen) {
                        setState(() {
                          _isBottomSheetOpen = false;
                        });
                      }
                    });

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                        border:
                            Border.all(color: highlightColor.withOpacity(0.2)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 2, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    margin: const EdgeInsets.only(
                                        top: 8, bottom: 24),
                                    decoration: BoxDecoration(
                                      color: highlightColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    'Dados do Pedido',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),

                                // Campo de origem com sugestões e botão de localização atual
                                _buildCustomAutocompleteField(
                                  icon: Symbols.location_on,
                                  label: 'Origem',
                                  placeholder: 'Ex: Baia mall, Maputo',
                                  controller: _originController,
                                  isOrigin: true,
                                  onTextChanged: (text) =>
                                      _searchPlaces(text, true),
                                  onMapSelect: () => _startSelectingOnMap(true),
                                  onCurrentLocation: () =>
                                      _setCurrentLocation(true),
                                  showSuggestions: _showOriginSuggestions,
                                  suggestions: _originSuggestions,
                                  onSuggestionSelected: (suggestion) =>
                                      _selectPlace(suggestion, true),
                                ),

                                const SizedBox(height: 16),

                                // Campo de destino com sugestões e botão de localização atual
                                _buildCustomAutocompleteField(
                                  icon: Symbols.flag,
                                  label: 'Destino',
                                  placeholder: 'Ex: Shoprite, Matola',
                                  controller: _destinationController,
                                  isOrigin: false,
                                  onTextChanged: (text) =>
                                      _searchPlaces(text, false),
                                  onMapSelect: () =>
                                      _startSelectingOnMap(false),
                                  onCurrentLocation: () =>
                                      _setCurrentLocation(false),
                                  showSuggestions: _showDestinationSuggestions,
                                  suggestions: _destinationSuggestions,
                                  onSuggestionSelected: (suggestion) =>
                                      _selectPlace(suggestion, false),
                                ),

                                const SizedBox(height: 16),
                                _buildLabeledInput(Symbols.notes, 'Observações',
                                    'Informações adicionais', false,
                                    multiline: true,
                                    controller: _observationsController),
                                const SizedBox(height: 24),
                                const Text(
                                  'Tipo de Transporte',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                // Dica sobre escolha de transporte
                                if (_routeDistanceKm != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.blue.withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Symbols.info,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _routeDistanceKm! <= 5.0
                                                ? 'Para esta distância curta, recomendamos Motorizada para entrega mais rápida.'
                                                : _routeDistanceKm! >= 10.0
                                                    ? 'Para esta distância longa, recomendamos Carro para maior segurança.'
                                                    : 'Para esta distância média, ambos os tipos de transporte são adequados.',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                SizedBox(
                                  height: 160,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _transports.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final transport = _transports[index];
                                      final selected = _selectedTransportIndices
                                          .contains(index);

                                      // Verificar se este transporte é recomendado para a distância
                                      bool isRecommended = false;
                                      if (_routeDistanceKm != null) {
                                        if (_routeDistanceKm! <= 5.0 &&
                                            transport['name'] == 'Motorizada') {
                                          isRecommended = true;
                                        } else if (_routeDistanceKm! >= 10.0 &&
                                            transport['name'] == 'Carro') {
                                          isRecommended = true;
                                        }
                                      }

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            // Single selection mode
                                            _selectedTransportIndices.clear();
                                            _selectedTransportIndices
                                                .add(index);
                                          });
                                        },
                                        child: Container(
                                          width: 240,
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2A2A2A),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: selected
                                                  ? highlightColor
                                                  : isRecommended
                                                      ? Colors.green
                                                      : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Image.asset(
                                                  transport['image'],
                                                  width: 120,
                                                  height: 120,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        transport['name'],
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),

                                                      // Badge de recomendado
                                                      if (_routeDistanceKm !=
                                                              null &&
                                                          ((transport['name'] ==
                                                                      'Motorizada' &&
                                                                  _routeDistanceKm! <=
                                                                      5.0) ||
                                                              (transport['name'] ==
                                                                      'Carro' &&
                                                                  _routeDistanceKm! >=
                                                                      10.0)))
                                                        Container(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 8),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.green,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          child: const Text(
                                                            'Recomendado',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.black,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    transport['description'],
                                                    style: const TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'Preço por KM:',
                                                    style: TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 12),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    transport['price'],
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: highlightColor,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: _showOrderSummarySheet,
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Criar Pedido',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Icon(
                                        Symbols.send_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Botão flutuante para reabrir o bottom sheet
              if (!_isBottomSheetOpen)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.extended(
                      onPressed: () =>
                          setState(() => _isBottomSheetOpen = true),
                      backgroundColor: highlightColor,
                      icon: const Icon(Symbols.edit_document,
                          color: Colors.white),
                      label: const Text(
                        'Criar Pedido',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                )
            ],
          ),
        ));
  }

  // Widget de campo de autocomplete personalizado com botão de localização atual
  Widget _buildCustomAutocompleteField({
    required IconData icon,
    required String label,
    required String placeholder,
    required TextEditingController controller,
    required bool isOrigin,
    required Function(String) onTextChanged,
    required VoidCallback onMapSelect,
    required VoidCallback onCurrentLocation,
    required bool showSuggestions,
    required List<Map<String, dynamic>> suggestions,
    required Function(Map<String, dynamic>) onSuggestionSelected,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onCurrentLocation,
                        icon: Icon(Symbols.my_location,
                            color: highlightColor, size: 18),
                        label: const Text('Atual',
                            style: TextStyle(color: Colors.white70)),
                        style: TextButton.styleFrom(
                            minimumSize: Size.zero, padding: EdgeInsets.zero),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: onMapSelect,
                        icon:
                            Icon(Symbols.map, color: highlightColor, size: 18),
                        label: const Text('No mapa',
                            style: TextStyle(color: Colors.white70)),
                        style: TextButton.styleFrom(
                            minimumSize: Size.zero, padding: EdgeInsets.zero),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Campo de texto com ícone de limpeza
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                onChanged: onTextChanged,
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon:
                              const Icon(Symbols.clear, color: Colors.white54),
                          onPressed: () {
                            setState(() {
                              controller.clear();
                              if (isOrigin) {
                                _showOriginSuggestions = false;
                                _originPoint = null;
                              } else {
                                _showDestinationSuggestions = false;
                                _destinationPoint = null;
                              }
                              _updateMarkers();
                              _polylines.clear();
                            });
                          },
                        )
                      : null,
                ),
              ),

              // Lista de sugestões
              if (showSuggestions)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: suggestions.length > 5 ? 5 : suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          suggestion['description'] ?? '',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        subtitle: suggestion['structured_formatting'] != null
                            ? Text(
                                suggestion['structured_formatting']
                                        ['secondary_text'] ??
                                    '',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              )
                            : null,
                        leading: Icon(icon, color: highlightColor, size: 18),
                        onTap: () {
                          onSuggestionSelected(suggestion);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledInput(
      IconData icon, String label, String placeholder, bool showMapButton,
      {bool multiline = false,
      TextEditingController? controller,
      VoidCallback? onMapSelect}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                  if (showMapButton)
                    TextButton.icon(
                      onPressed: onMapSelect,
                      icon: Icon(Symbols.map, color: highlightColor, size: 18),
                      label: const Text('Selecionar no mapa',
                          style: TextStyle(color: Colors.white70)),
                      style: TextButton.styleFrom(
                          minimumSize: Size.zero, padding: EdgeInsets.zero),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                maxLines: multiline ? 4 : 1,
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}

extension on GoogleMapController? {
  void addListener(Future<Null> Function() param0) {}
}
