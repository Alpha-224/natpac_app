import 'package:hive/hive.dart';

part 'place_cluster.g.dart';

@HiveType(typeId: 5)
class PlaceCluster extends HiveObject {
@HiveField(0)
String id;

@HiveField(1)
double centerLatitude;

@HiveField(2)
double centerLongitude;

@HiveField(3)
DateTime firstSeen;

@HiveField(4)
DateTime lastUpdated;

@HiveField(5)
int pointCount;

@HiveField(6)
String tripId;

@HiveField(7)
List<String> segmentIds;

@HiveField(8)
double averageAccuracy;

@HiveField(9)
bool isActive;

@HiveField(10)
String? label; // User-defined name (Home, Work, etc)

PlaceCluster({
required this.id,
required this.centerLatitude,
required this.centerLongitude,
required this.firstSeen,
required this.lastUpdated,
required this.pointCount,
required this.tripId,
required this.segmentIds,
required this.averageAccuracy,
this.isActive = true,
this.label,
});

Duration get duration => lastUpdated.difference(firstSeen);

void updateCenter(double newLat, double newLon, int newPointCount) {
// Weighted average for better center calculation
final totalPoints = pointCount + newPointCount;

centerLatitude = (centerLatitude * pointCount + newLat * newPointCount) / totalPoints;
centerLongitude = (centerLongitude * pointCount + newLon * newPointCount) / totalPoints;

pointCount = totalPoints;
lastUpdated = DateTime.now();
}

void addSegmentId(String segmentId) {
if (!segmentIds.contains(segmentId)) {
segmentIds.add(segmentId);
}
}

void updateAccuracy(double newAccuracy) {
// Running average of accuracy
averageAccuracy = (averageAccuracy + newAccuracy) / 2;
}

void setLabel(String newLabel) {
label = newLabel;
}

void deactivate() {
isActive = false;
}

Map<String, dynamic> toMap() {
return {
'id': id,
'centerLatitude': centerLatitude,
'centerLongitude': centerLongitude,
'firstSeen': firstSeen.toIso8601String(),
'lastUpdated': lastUpdated.toIso8601String(),
'pointCount': pointCount,
'tripId': tripId,
'segmentIds': segmentIds,
'averageAccuracy': averageAccuracy,
'isActive': isActive,
'label': label,
};
}

factory PlaceCluster.fromMap(Map<String, dynamic> map) {
return PlaceCluster(
id: map['id'],
centerLatitude: map['centerLatitude'],
centerLongitude: map['centerLongitude'],
firstSeen: DateTime.parse(map['firstSeen']),
lastUpdated: DateTime.parse(map['lastUpdated']),
pointCount: map['pointCount'],
tripId: map['tripId'],
segmentIds: List<String>.from(map['segmentIds'] ?? []),
averageAccuracy: map['averageAccuracy'],
isActive: map['isActive'] ?? true,
label: map['label'],
);
}
}
