class GeotaggedPhoto {
  final String id;
  final String imagePath;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? address;
  final double? altitude;
  final double? accuracy;
  final double? heading;

  GeotaggedPhoto({
    required this.id,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.address,
    this.altitude,
    this.accuracy,
    this.heading,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'address': address,
      'altitude': altitude,
      'accuracy': accuracy,
      'heading': heading,
    };
  }

  factory GeotaggedPhoto.fromJson(Map<String, dynamic> json) {
    return GeotaggedPhoto(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      address: json['address'] as String?,
      altitude: json['altitude'] as double?,
      accuracy: json['accuracy'] as double?,
      heading: json['heading'] as double?,
    );
  }

  String get formattedCoordinates {
    final latDirection = latitude >= 0 ? 'N' : 'S';
    final lonDirection = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(6)}°$latDirection, ${longitude.abs().toStringAsFixed(6)}°$lonDirection';
  }

  String get formattedTimestamp {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
