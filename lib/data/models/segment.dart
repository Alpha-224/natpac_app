import 'package:hive/hive.dart';

part 'segment.g.dart';

@HiveType(typeId: 2)
class Segment extends HiveObject {
@HiveField(0)
final String id;

@HiveField(1)
final String tripId;

@HiveField(2)
final DateTime startTime;

@HiveField(3)
DateTime? endTime;

@HiveField(4)
String transportMode;

@HiveField(5)
final List<String> pointCacheIds;

@HiveField(6)
double totalDistance;

@HiveField(7)
double averageSpeed;

@HiveField(8)
double maxSpeed;

@HiveField(9)
int pointCount;

Segment({
required this.id,
required this.tripId,
required this.startTime,
this.endTime,
required this.transportMode,
List<String>? pointCacheIds,
this.totalDistance = 0,
this.averageSpeed = 0,
this.maxSpeed = 0,
this.pointCount = 0,
}) : pointCacheIds = pointCacheIds ?? [];

bool get isActive => endTime == null;

Duration get duration {
final end = endTime ?? DateTime.now();
return end.difference(startTime);
}

void addPointCacheId(String cacheId) {
pointCacheIds.add(cacheId);
}

void updateStatistics({
double? additionalDistance,
double? newSpeed,
int? additionalPoints,
}) {
if (additionalDistance != null) {
totalDistance += additionalDistance;
}

if (newSpeed != null && newSpeed > maxSpeed) {
maxSpeed = newSpeed;
}

if (additionalPoints != null) {
pointCount += additionalPoints;
}

// Recalculate average speed
final durationSeconds = duration.inSeconds;
if (durationSeconds > 0) {
averageSpeed = totalDistance / durationSeconds;
}
}

void finish() {
endTime = DateTime.now();
}

Map<String, dynamic> toMap() {
return {
'id': id,
'tripId': tripId,
'startTime': startTime.toIso8601String(),
'endTime': endTime?.toIso8601String(),
'transportMode': transportMode,
'pointCacheIds': pointCacheIds,
'totalDistance': totalDistance,
'averageSpeed': averageSpeed,
'maxSpeed': maxSpeed,
'pointCount': pointCount,
};
}

factory Segment.fromMap(Map<String, dynamic> map) {
return Segment(
id: map['id'],
tripId: map['tripId'],
startTime: DateTime.parse(map['startTime']),
endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
transportMode: map['transportMode'],
pointCacheIds: List<String>.from(map['pointCacheIds'] ?? []),
totalDistance: map['totalDistance'] ?? 0.0,
averageSpeed: map['averageSpeed'] ?? 0.0,
maxSpeed: map['maxSpeed'] ?? 0.0,
pointCount: map['pointCount'] ?? 0,
);
}
}
