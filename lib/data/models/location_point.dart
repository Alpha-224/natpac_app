import 'package:hive/hive.dart';

part 'location_point.g.dart';

@HiveType(typeId: 0)
class LocationPoint extends HiveObject {
@HiveField(0)
final double latitude;

@HiveField(1)
final double longitude;

@HiveField(2)
final DateTime timestamp;

@HiveField(3)
final double speed;

@HiveField(4)
final double heading;

@HiveField(5)
final double altitude;

@HiveField(6)
final double accuracy;

@HiveField(7)
final String? activityType;

@HiveField(8)
final String? transportMode;

LocationPoint({
required this.latitude,
required this.longitude,
required this.timestamp,
required this.speed,
required this.heading,
required this.altitude,
required this.accuracy,
this.activityType,
this.transportMode,
});

Map<String, dynamic> toMap() {
return {
'latitude': latitude,
'longitude': longitude,
'timestamp': timestamp.toIso8601String(),
'speed': speed,
'heading': heading,
'altitude': altitude,
'accuracy': accuracy,
'activityType': activityType,
'transportMode': transportMode,
};
}

factory LocationPoint.fromMap(Map<String, dynamic> map) {
return LocationPoint(
latitude: map['latitude'],
longitude: map['longitude'],
timestamp: DateTime.parse(map['timestamp']),
speed: map['speed'],
heading: map['heading'],
altitude: map['altitude'],
accuracy: map['accuracy'],
activityType: map['activityType'],
transportMode: map['transportMode'],
);
}
}
