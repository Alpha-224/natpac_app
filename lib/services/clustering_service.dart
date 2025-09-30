import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../data/models/location_point.dart';
import '../data/models/place_cluster.dart';
import 'storage_service.dart';

class ClusteringService extends ChangeNotifier {
static final ClusteringService _instance = ClusteringService._();
static ClusteringService get instance => _instance;
ClusteringService._();

// Clustering parameters
static const double CLUSTER_RADIUS_METERS = 35.0; // Spatial radius
static const Duration TIME_WINDOW = Duration(minutes: 3); // Temporal window
static const int MIN_POINTS_FOR_CLUSTER = 10; // Minimum density
static const double MERGE_DISTANCE_METERS = 20.0; // Merge nearby clusters

// Recent points buffer for clustering analysis
final List<_TimedPoint> _recentPoints = [];
static const int MAX_BUFFER_SIZE = 300; // ~5 minutes at 1Hz

// Active clusters
final Map<String, PlaceCluster> _activeClusters = {};
PlaceCluster? _currentCluster;

PlaceCluster? get currentCluster => _currentCluster;
Map<String, PlaceCluster> get activeClusters => Map.unmodifiable(_activeClusters);

void analyzePoint(LocationPoint point) {
_recentPoints.add(_TimedPoint(point, DateTime.now()));

// Maintain buffer size
_recentPoints.removeWhere(
(p) => DateTime.now().difference(p.timestamp) > TIME_WINDOW,
);

if (_recentPoints.length > MAX_BUFFER_SIZE) {
_recentPoints.removeAt(0);
}

// Check if we have enough points for clustering
if (_recentPoints.length >= MIN_POINTS_FOR_CLUSTER) {
_performClustering(point);
}

notifyListeners();
}

void _performClustering(LocationPoint newPoint) {
// Find nearby points within time and space window
final nearbyPoints = _findNearbyPoints(newPoint);

if (nearbyPoints.length >= MIN_POINTS_FOR_CLUSTER) {
// Check if this matches an existing cluster
PlaceCluster? matchingCluster = _findMatchingCluster(newPoint);

if (matchingCluster != null) {
// Update existing cluster
_updateCluster(matchingCluster, nearbyPoints);
_currentCluster = matchingCluster;
} else {
// Create new cluster
_createNewCluster(newPoint, nearbyPoints);
}
} else {
// Not enough points for clustering, might be moving
_currentCluster = null;
}
}

List<_TimedPoint> _findNearbyPoints(LocationPoint centerPoint) {
return _recentPoints.where((timedPoint) {
final distance = _calculateDistance(centerPoint, timedPoint.point);
return distance <= CLUSTER_RADIUS_METERS;
}).toList();
}

PlaceCluster? _findMatchingCluster(LocationPoint point) {
for (final cluster in _activeClusters.values) {
final distance = _calculateDistanceToCluster(point, cluster);
if (distance <= CLUSTER_RADIUS_METERS) {
return cluster;
}
}
return null;
}

void _updateCluster(PlaceCluster cluster, List<_TimedPoint> points) {
// Calculate weighted center
double totalLat = cluster.centerLatitude * cluster.pointCount;
double totalLon = cluster.centerLongitude * cluster.pointCount;
int newPointCount = points.length;

for (final timedPoint in points) {
totalLat += timedPoint.point.latitude;
totalLon += timedPoint.point.longitude;
}

final totalPoints = cluster.pointCount + newPointCount;
cluster.updateCenter(
totalLat / totalPoints,
totalLon / totalPoints,
newPointCount,
);

// Update accuracy
final avgAccuracy = points.fold(
0.0,
(sum, p) => sum + p.point.accuracy,
) /
points.length;
cluster.updateAccuracy(avgAccuracy);

// Save to storage
StorageService.instance.savePlaceCluster(cluster);
debugPrint('Updated cluster ${cluster.id} with ${newPointCount} new points');
}

void _createNewCluster(LocationPoint centerPoint, List<_TimedPoint> points) {
// Calculate cluster center
double centerLat = points.fold(0.0, (sum, p) => sum + p.point.latitude) / points.length;
double centerLon = points.fold(0.0, (sum, p) => sum + p.point.longitude) / points.length;

final cluster = PlaceCluster(
id: _generateClusterId(),
centerLatitude: centerLat,
centerLongitude: centerLon,
firstSeen: points.map((p) => p.timestamp).reduce((a, b) => a.isBefore(b) ? a : b),
lastUpdated: DateTime.now(),
pointCount: points.length,
tripId: 'unknown', // Will be updated when associated with trip
segmentIds: [],
averageAccuracy: points.fold(0.0, (sum, p) => sum + p.point.accuracy) / points.length,
);

_activeClusters[cluster.id] = cluster;
_currentCluster = cluster;

// Check for clusters that should be merged
_checkForMergeablesClusters(cluster);

// Save to storage
StorageService.instance.savePlaceCluster(cluster);
debugPrint('Created new cluster ${cluster.id} at (${centerLat.toStringAsFixed(6)}, ${centerLon.toStringAsFixed(6)})');
}

void _checkForMergeablesClusters(PlaceCluster newCluster) {
final clustersToMerge = <PlaceCluster>[];

for (final existingCluster in _activeClusters.values) {
if (existingCluster.id != newCluster.id) {
final distance = _calculateDistance(
LocationPoint(
latitude: newCluster.centerLatitude,
longitude: newCluster.centerLongitude,
timestamp: DateTime.now(),
speed: 0,
heading: 0,
altitude: 0,
accuracy: 0,
),
LocationPoint(
latitude: existingCluster.centerLatitude,
longitude: existingCluster.centerLongitude,
timestamp: DateTime.now(),
speed: 0,
heading: 0,
altitude: 0,
accuracy: 0,
),
);

if (distance <= MERGE_DISTANCE_METERS) {
clustersToMerge.add(existingCluster);
}
}
}

// Merge clusters
for (final clusterToMerge in clustersToMerge) {
_mergeClusters(newCluster, clusterToMerge);
}
}

void _mergeClusters(PlaceCluster cluster1, PlaceCluster cluster2) {
// Merge into cluster1
final totalPoints = cluster1.pointCount + cluster2.pointCount;
final newLat = (cluster1.centerLatitude * cluster1.pointCount + 
cluster2.centerLatitude * cluster2.pointCount) / totalPoints;
final newLon = (cluster1.centerLongitude * cluster1.pointCount + 
cluster2.centerLongitude * cluster2.pointCount) / totalPoints;

cluster1.updateCenter(newLat, newLon, cluster2.pointCount);

// Merge segment IDs
for (final segmentId in cluster2.segmentIds) {
cluster1.addSegmentId(segmentId);
}

// Use earlier first seen date
if (cluster2.firstSeen.isBefore(cluster1.firstSeen)) {
cluster1.firstSeen = cluster2.firstSeen;
}

// Remove merged cluster
_activeClusters.remove(cluster2.id);
StorageService.instance.deletePlaceCluster(cluster2.id);

// Update merged cluster
StorageService.instance.savePlaceCluster(cluster1);

debugPrint('Merged clusters ${cluster1.id} and ${cluster2.id}');
}

double _calculateDistance(LocationPoint point1, LocationPoint point2) {
const double earthRadius = 6371000; // Earth radius in meters
final double lat1Rad = point1.latitude * math.pi / 180;
final double lat2Rad = point2.latitude * math.pi / 180;
final double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
final double deltaLonRad = (point2.longitude - point1.longitude) * math.pi / 180;

final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
math.cos(lat1Rad) *
math.cos(lat2Rad) *
math.sin(deltaLonRad / 2) *
math.sin(deltaLonRad / 2);

final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
return earthRadius * c;
}

double _calculateDistanceToCluster(LocationPoint point, PlaceCluster cluster) {
return _calculateDistance(
point,
LocationPoint(
latitude: cluster.centerLatitude,
longitude: cluster.centerLongitude,
timestamp: DateTime.now(),
speed: 0,
heading: 0,
altitude: 0,
accuracy: 0,
),
);
}

String _generateClusterId() {
return 'cluster_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';
}

// Load clusters from storage
void loadClustersFromStorage() {
final clusters = StorageService.instance.getAllPlaceClusters();
_activeClusters.clear();

for (final cluster in clusters) {
if (cluster.isActive) {
_activeClusters[cluster.id] = cluster;
}
}

debugPrint('Loaded ${_activeClusters.length} active clusters from storage');
notifyListeners();
}

// Get clusters near a location
List<PlaceCluster> getClustersNear(double latitude, double longitude, double radiusMeters) {
final targetPoint = LocationPoint(
latitude: latitude,
longitude: longitude,
timestamp: DateTime.now(),
speed: 0,
heading: 0,
altitude: 0,
accuracy: 0,
);

return _activeClusters.values.where((cluster) {
final distance = _calculateDistanceToCluster(targetPoint, cluster);
return distance <= radiusMeters;
}).toList();
}

// Label a cluster
void labelCluster(String clusterId, String label) {
final cluster = _activeClusters[clusterId];
if (cluster != null) {
cluster.setLabel(label);
StorageService.instance.savePlaceCluster(cluster);
debugPrint('Labeled cluster $clusterId as "$label"');
notifyListeners();
}
}
}

class _TimedPoint {
final LocationPoint point;
final DateTime timestamp;

_TimedPoint(this.point, this.timestamp);
}
