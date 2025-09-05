// Crie um novo widget para envolver o Google Maps com tratamento de erros

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SafeGoogleMap extends StatelessWidget {
  final CameraPosition initialCameraPosition;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final Function(GoogleMapController)? onMapCreated;
  final bool myLocationEnabled;
  final bool zoomControlsEnabled;
  final bool mapToolbarEnabled;
  final Color loadingIndicatorColor;
  final String mapStyle;
  
  const SafeGoogleMap({
    super.key,
    required this.initialCameraPosition,
    this.markers,
    this.polylines,
    this.onMapCreated,
    this.myLocationEnabled = false,
    this.zoomControlsEnabled = false,
    this.mapToolbarEnabled = false,
    this.loadingIndicatorColor = Colors.orange,
    this.mapStyle = '',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.black26,
          width: double.infinity,
          height: double.infinity,
        ),
        
        // Envolvendo o GoogleMap em um try-catch visual
        Builder(
          builder: (context) {
            try {
              return GoogleMap(
                initialCameraPosition: initialCameraPosition,
                // onMapCreated parameter is already specified above, so this duplicate is removed.
                markers: markers ?? {},
                polylines: polylines ?? {},
                myLocationEnabled: myLocationEnabled,
                zoomControlsEnabled: zoomControlsEnabled,
                mapToolbarEnabled: mapToolbarEnabled,
                compassEnabled: false,
                tiltGesturesEnabled: false,
                onMapCreated: (controller) {
                  try {
                    if (mapStyle.isNotEmpty) {
                      controller.setMapStyle(mapStyle);
                    }
                    if (onMapCreated != null) {
                      onMapCreated!(controller);
                    }
                  } catch (e) {
                    print('Erro ao configurar mapa: $e');
                  }
                },
              );
            } catch (e) {
              print('Erro ao renderizar o mapa: $e');
              // Mostrar um fallback se o mapa não puder ser renderizado
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'Não foi possível carregar o mapa',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ],
    );
  }
}