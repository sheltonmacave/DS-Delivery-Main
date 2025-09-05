import 'package:cloud_firestore/cloud_firestore.dart';

// Enumeração para status do pedido
enum OrderStatus {
  pending, // Pendente
  driverAssigned, // Entregador atribuído
  pickedUp, // Encomenda recolhida
  inTransit, // Em trânsito
  delivered, // Entregue
  cancelled, // Cancelado
}

// Classe para atualizações de status
class StatusUpdate {
  final OrderStatus status;
  final DateTime timestamp;
  final String? description;

  StatusUpdate({
    required this.status,
    required this.timestamp,
    this.description,
  });

  // Método para criar a partir de JSON
  factory StatusUpdate.fromJson(Map<String, dynamic> json) {
    return StatusUpdate(
      status: OrderStatus.values[json['status'] ?? 0],
      timestamp: _parseTimestamp(json['timestamp']),
      description: json['description'],
    );
  }

  // Método para converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status.index,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
    };
  }
}

// Classe para coordenadas GPS
class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint({required this.latitude, required this.longitude});

  // Método para criar a partir de JSON ou GeoPoint do Firestore
  factory GeoPoint.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return GeoPoint(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      );
    } else if (json is GeoPoint) {
      return GeoPoint(latitude: json.latitude, longitude: json.longitude);
    } else {
      // Valor padrão para caso não seja possível converter
      return GeoPoint(latitude: 0.0, longitude: 0.0);
    }
  }

  // Método para converter para JSON
  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}

// Classe principal para o pedido
class Order {
  final String? id;
  final String clientId;
  final String? driverId;
  final String? clientName;
  final String? clientPhone;
  final String originAddress;
  final String destinationAddress;
  final GeoPoint originLocation;
  final GeoPoint destinationLocation;
  final double distance;
  final String estimatedTime;
  final double price;
  final String transportType;
  final String? observations;
  final OrderStatus status;
  final DateTime createdAt;
  final List<StatusUpdate> statusUpdates;

  Order({
    this.id,
    required this.clientId,
    this.driverId,
    this.clientName,
    this.clientPhone,
    required this.originAddress,
    required this.destinationAddress,
    required this.originLocation,
    required this.destinationLocation,
    required this.distance,
    required this.estimatedTime,
    required this.price,
    required this.transportType,
    this.observations,
    required this.status,
    required this.createdAt,
    required this.statusUpdates,
  });

  // Método para criar a partir de JSON
  factory Order.fromJson(Map<String, dynamic> json) {
    // Processar atualizações de status
    List<StatusUpdate> updates = [];
    if (json['statusUpdates'] != null) {
      if (json['statusUpdates'] is List) {
        updates = (json['statusUpdates'] as List)
            .map((update) => StatusUpdate.fromJson(update))
            .toList();
      }
    }

    return Order(
      id: json['id'],
      clientId: json['clientId'] ?? '',
      driverId: json['driverId'],
      clientName: json['clientName'],
      clientPhone: json['clientPhone'],
      originAddress: json['originAddress'] ?? '',
      destinationAddress: json['destinationAddress'] ?? '',
      originLocation: GeoPoint.fromJson(
        json['originLocation'] ?? {'latitude': 0.0, 'longitude': 0.0},
      ),
      destinationLocation: GeoPoint.fromJson(
        json['destinationLocation'] ?? {'latitude': 0.0, 'longitude': 0.0},
      ),
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      estimatedTime: json['estimatedTime'] ?? '0 min',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      transportType: json['transportType'] ?? 'Carro',
      observations: json['observations'],
      status: OrderStatus.values[json['status'] ?? 0],
      createdAt: _parseTimestamp(json['createdAt']),
      statusUpdates: updates,
    );
  }

  // Método para converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'driverId': driverId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'originAddress': originAddress,
      'destinationAddress': destinationAddress,
      'originLocation': originLocation.toJson(),
      'destinationLocation': destinationLocation.toJson(),
      'distance': distance,
      'estimatedTime': estimatedTime,
      'price': price,
      'transportType': transportType,
      'observations': observations,
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
      'statusUpdates': statusUpdates.map((update) => update.toJson()).toList(),
    };
  }

  // Helper para criar uma cópia com mudanças
  Order copyWith({
    String? id,
    String? clientId,
    String? driverId,
    String? clientName,
    String? clientPhone,
    String? originAddress,
    String? destinationAddress,
    GeoPoint? originLocation,
    GeoPoint? destinationLocation,
    double? distance,
    String? estimatedTime,
    double? price,
    String? transportType,
    String? observations,
    OrderStatus? status,
    DateTime? createdAt,
    List<StatusUpdate>? statusUpdates,
  }) {
    return Order(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      driverId: driverId ?? this.driverId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      originAddress: originAddress ?? this.originAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      originLocation: originLocation ?? this.originLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      distance: distance ?? this.distance,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      price: price ?? this.price,
      transportType: transportType ?? this.transportType,
      observations: observations ?? this.observations,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      statusUpdates: statusUpdates ?? this.statusUpdates,
    );
  }
}

// Função auxiliar para converter timestamps em diferentes formatos para DateTime
DateTime _parseTimestamp(dynamic timestamp) {
  if (timestamp == null) {
    return DateTime.now();
  }

  if (timestamp is Timestamp) {
    return timestamp.toDate();
  }

  if (timestamp is String) {
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      return DateTime.now();
    }
  }

  if (timestamp is Map &&
      timestamp.containsKey('_seconds') &&
      timestamp.containsKey('_nanoseconds')) {
    final seconds = timestamp['_seconds'] as int? ?? 0;
    final nanoseconds = timestamp['_nanoseconds'] as int? ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000) + (nanoseconds ~/ 1000000),
      isUtc: true,
    );
  }

  return DateTime.now();
}
