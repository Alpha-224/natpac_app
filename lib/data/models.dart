import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

part 'models.g.dart';

@HiveType(typeId: 2)
enum TransportMode {
  @HiveField(0)
  walking,
  @HiveField(1)
  driving,
  @HiveField(2)
  cycling,
  @HiveField(3)
  bus,
  @HiveField(4)
  train,
  @HiveField(5)
  still,
}

// Custom adapter for LatLng since it's not a Hive type
class LatLngAdapter extends TypeAdapter<LatLng> {
  @override
  final int typeId = 3;

  @override
  LatLng read(BinaryReader reader) {
    final lat = reader.readDouble();
    final lng = reader.readDouble();
    return LatLng(lat, lng);
  }

  @override
  void write(BinaryWriter writer, LatLng obj) {
    writer.writeDouble(obj.latitude);
    writer.writeDouble(obj.longitude);
  }
}

@HiveType(typeId: 0)
class Trip extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String originName;

  @HiveField(2)
  final String destinationName;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final double distanceInKm;

  @HiveField(5)
  final int durationMinutes; // Store as int for Hive

  @HiveField(6)
  final TransportMode transportMode;

  @HiveField(7)
  final List<LatLng> routePoints;

  // Add this field to fix the error
  @HiveField(8)
  final Duration duration;

  Trip({
    required this.id,
    required this.originName,
    required this.destinationName,
    required this.timestamp,
    required this.distanceInKm,
    required this.duration, // Now this can be this.duration
    required this.transportMode,
    this.routePoints = const [],
  }) : durationMinutes = duration.inMinutes;

  Map<String, dynamic> toJson() => {
        "id": id,
        "originName": originName,
        "destinationName": destinationName,
        "timestamp": timestamp.toIso8601String(),
        "distanceInKm": distanceInKm,
        "duration": durationMinutes,
        "transportMode": transportMode.name,
        "routePoints": routePoints
            .map((p) => {"lat": p.latitude, "lng": p.longitude})
            .toList(),
      };

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json["id"],
      originName: json["originName"],
      destinationName: json["destinationName"],
      timestamp: DateTime.parse(json["timestamp"]),
      distanceInKm: json["distanceInKm"].toDouble(),
      duration: Duration(minutes: json["duration"]),
      transportMode: TransportMode.values.firstWhere(
        (e) => e.name == json["transportMode"],
        orElse: () => TransportMode.walking,
      ),
      routePoints: (json["routePoints"] as List<dynamic>?)
              ?.map((p) => LatLng(p["lat"].toDouble(), p["lng"].toDouble()))
              .toList() ??
          [],
    );
  }
}

// Add Duration adapter for Hive
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 4;

  @override
  Duration read(BinaryReader reader) {
    return Duration(microseconds: reader.readInt());
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMicroseconds);
  }
}

@HiveType(typeId: 1)
class PlannedTrip extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String originName;

  @HiveField(2)
  final String destinationName;

  @HiveField(3)
  final DateTime plannedDateTime;

  @HiveField(4)
  final TransportMode transportMode;

  PlannedTrip({
    required this.id,
    required this.originName,
    required this.destinationName,
    required this.plannedDateTime,
    required this.transportMode,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "originName": originName,
        "destinationName": destinationName,
        "plannedDateTime": plannedDateTime.toIso8601String(),
        "transportMode": transportMode.name,
      };

  factory PlannedTrip.fromJson(Map<String, dynamic> json) {
    return PlannedTrip(
      id: json["id"],
      originName: json["originName"],
      destinationName: json["destinationName"],
      plannedDateTime: DateTime.parse(json["plannedDateTime"]),
      transportMode: TransportMode.values.firstWhere(
        (e) => e.name == json["transportMode"],
        orElse: () => TransportMode.walking,
      ),
    );
  }
}
