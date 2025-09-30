import 'dart:math' as math;
import 'package:hive/hive.dart';
import 'location_point.dart';

part 'point_cache.g.dart';

@HiveType(typeId: 1)
class PointCache extends HiveObject {
static const int maxPointsPerCache = 500;

@HiveField(0)
final String id;

@HiveField(1)
final String segmentId;

@HiveField(2)
final List<LocationPoint> points;

@HiveField(3)
final int sequenceNumber;

@HiveField(4)
final DateTime createdAt;

PointCache({
required this.id,
required this.segmentId,
List<LocationPoint>? points,
required this.sequenceNumber,
DateTime? createdAt,
}) : points = points ?? [],
createdAt = createdAt ?? DateTime.now();

bool get isFull => points.length >= maxPointsPerCache;

void addPoint(LocationPoint point) {
if (!isFull) {
points.add(point);
} else {
throw Exception('PointCache is full. Maximum $maxPointsPerCache points allowed.');
}
}

double? getDistanceCovered() {
if (points.length < 2) return 0;

double totalDistance = 0;
for (int i = 1; i < points.length; i++) {
totalDistance += _calculateDistance(points[i-1], points[i]);
}
return totalDistance;
}

double _calculateDistance(LocationPoint point1, LocationPoint point2) {
const double earthRadius = 6371000; // meters

final double lat1Rad = point1.latitude * math.pi / 180;
final double lat2Rad = point2.latitude * math.pi / 180;
final double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
final double deltaLonRad = (point2.longitude - point1.longitude) * math.pi / 180;

final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
math.cos(lat1Rad) * math.cos(lat2Rad) *
math.sin(deltaLonRad / 2) * math.sin(deltaLonRad / 2);
final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

return earthRadius * c;
}

Duration? getDuration() {
if (points.length < 2) return Duration.zero;
return points.last.timestamp.difference(points.first.timestamp);
}

double? getAverageSpeed() {
final distance = getDistanceCovered();
final duration = getDuration();

if (distance == null || duration == null || duration.inSeconds == 0) {
return 0;
}

return distance / duration.inSeconds; // m/s
}
}
