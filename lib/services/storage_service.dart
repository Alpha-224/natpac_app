import 'dart:math' as math;
import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/trip_new.dart';
import '../data/models/segment.dart';
import '../data/models/point_cache.dart';
import '../data/models/location_point.dart';
import '../data/models/place_cluster.dart';

class StorageService {
  static const String tripBoxName = 'trips';
  static const String segmentBoxName = 'segments';
  static const String pointCacheBoxName = 'pointCaches';
  static const String clusterBoxName = 'clusters';

  static StorageService? _instance;
  StorageService._();
  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  late Box _tripBox;
  late Box _segmentBox;
  late Box _pointCacheBox;
  late Box _clusterBox;

  Box get tripBox => _tripBox;
  Box get segmentBox => _segmentBox;
  Box get pointCacheBox => _pointCacheBox;
  Box get clusterBox => _clusterBox;

  Future<void> initialize() async {
    await Hive.initFlutter();

// Register adapters
    Hive.registerAdapter(LocationPointAdapter());
    Hive.registerAdapter(PointCacheAdapter());
    Hive.registerAdapter(SegmentAdapter());
    Hive.registerAdapter(TripAdapter());
    Hive.registerAdapter(PlaceClusterAdapter());

// Open boxes
    _tripBox = await Hive.openBox(tripBoxName);
    _segmentBox = await Hive.openBox(segmentBoxName);
    _pointCacheBox = await Hive.openBox(pointCacheBoxName);
    _clusterBox = await Hive.openBox(clusterBoxName);
  }

// Trip operations
  Future<void> saveTrip(Trip trip) async {
    await _tripBox.put(trip.id, trip);
  }

  Trip? getTrip(String id) {
    return _tripBox.get(id);
  }

  List<Trip> getAllTrips() {
    return _tripBox.values.cast<Trip>().toList();
  }

  Trip? getActiveTrip() {
    return _tripBox.values
        .cast<Trip>()
        .where((trip) => trip.isActive)
        .firstOrNull;
  }

  Future<void> deleteTrip(String id) async {
    await _tripBox.delete(id);
  }

// Segment operations
  Future<void> saveSegment(Segment segment) async {
    await _segmentBox.put(segment.id, segment);
  }

  Segment? getSegment(String id) {
    return _segmentBox.get(id);
  }

  List<Segment> getSegmentsForTrip(String tripId) {
    return _segmentBox.values
        .cast<Segment>()
        .where((segment) => segment.tripId == tripId)
        .toList();
  }

  Segment? getActiveSegment() {
    return _segmentBox.values
        .cast<Segment>()
        .where((segment) => segment.isActive)
        .firstOrNull;
  }

  Future<void> deleteSegment(String id) async {
    await _segmentBox.delete(id);
  }

// PointCache operations
  Future<void> savePointCache(PointCache cache) async {
    await _pointCacheBox.put(cache.id, cache);
  }

  PointCache? getPointCache(String id) {
    return _pointCacheBox.get(id);
  }

  List<PointCache> getPointCachesForSegment(String segmentId) {
    return _pointCacheBox.values
        .cast<PointCache>()
        .where((cache) => cache.segmentId == segmentId)
        .toList();
  }

  Future<void> deletePointCache(String id) async {
    await _pointCacheBox.delete(id);
  }

// PlaceCluster operations
  Future<void> savePlaceCluster(PlaceCluster cluster) async {
    await _clusterBox.put(cluster.id, cluster);
  }

  PlaceCluster? getPlaceCluster(String id) {
    return _clusterBox.get(id);
  }

  List<PlaceCluster> getAllPlaceClusters() {
    return _clusterBox.values.cast<PlaceCluster>().toList();
  }

  List<PlaceCluster> getActivePlaceClusters() {
    return _clusterBox.values
        .cast<PlaceCluster>()
        .where((cluster) => cluster.isActive)
        .toList();
  }

  Future<void> deletePlaceCluster(String id) async {
    await _clusterBox.delete(id);
  }

// Utility operations
  Future<void> clearAllData() async {
    await _tripBox.clear();
    await _segmentBox.clear();
    await _pointCacheBox.clear();
    await _clusterBox.clear();
  }

  Future<void> deleteTripsOlderThan(Duration duration) async {
    final cutoffTime = DateTime.now().subtract(duration);
    final tripsToDelete = _tripBox.values
        .cast<Trip>()
        .where((trip) =>
            !trip.isActive && trip.endTime?.isBefore(cutoffTime) == true)
        .map((trip) => trip.id)
        .toList();

    for (final tripId in tripsToDelete) {
      await deleteTrip(tripId);
    }
  }

// Statistics
  int get totalTrips => _tripBox.length;
  int get totalSegments => _segmentBox.length;
  int get totalPointCaches => _pointCacheBox.length;
  int get totalPlaceClusters => _clusterBox.length;

  double getTotalDistanceKm() {
    return _tripBox.values
        .cast<Trip>()
        .fold(0.0, (sum, trip) => sum + trip.distanceInKm);
  }

  Duration getTotalTravelTime() {
    return _tripBox.values
        .cast<Trip>()
        .where((trip) => !trip.isActive)
        .fold(Duration.zero, (sum, trip) => sum + trip.duration);
  }
}
