import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/models/trip_new.dart';
import '../data/models/segment.dart';
import '../data/models/point_cache.dart';
import '../data/models/location_point.dart';
import '../data/models/place_cluster.dart';
import 'storage_service.dart';
import 'activity_recognition_service_new.dart';
import 'filters/location_filter.dart';
import 'filters/kalman_filter.dart';
import 'background_service.dart';
import 'clustering_service.dart';

// MOVED: Define LatLng class first, before LocationService
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

class LocationService extends ChangeNotifier {
  static LocationService? _instance;
  LocationService._();
  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }

  final StorageService _storage = StorageService.instance;
  final ActivityRecognitionService _activityService =
      ActivityRecognitionService.instance;
  final LocationFilter _locationFilter = LocationFilter();
  final KalmanLocationFilter _kalmanFilter = KalmanLocationFilter();

  Position? _currentPosition;
  Position? _lastRecordedPosition;
  bool _isTracking = false;
  bool _isBackgroundMode = false;

  // Current tracking state
  Trip? _currentTrip;
  Segment? _currentSegment;
  PointCache? _currentPointCache;

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _backgroundTimer;

  // Tracking statistics
  double _totalDistance = 0.0;
  int _totalPoints = 0;
  // REMOVED: unused _lastActivityChange field

  // Getters
  bool get isTracking => _isTracking;
  bool get isBackgroundMode => _isBackgroundMode;
  Position? get currentPosition => _currentPosition;
  Trip? get currentTrip => _currentTrip;
  Segment? get currentSegment => _currentSegment;
  double get totalDistance => _totalDistance;
  int get totalPoints => _totalPoints;
  Duration get elapsedTime => _currentTrip?.duration ?? Duration.zero;
  List<LatLng> get routePoints => _getRoutePoints();

  List<LatLng> _getRoutePoints() {
    if (_currentTrip == null) return [];

    final points = <LatLng>[];
    final segments = _storage.getSegmentsForTrip(_currentTrip!.id);

    for (final segment in segments) {
      final caches = _storage.getPointCachesForSegment(segment.id);
      for (final cache in caches) {
        for (final point in cache.points) {
          points.add(LatLng(point.latitude, point.longitude));
        }
      }
    }

    return points;
  }

  Future<bool> checkPermissions() async {
    final location = await Permission.location.status;
    final locationAlways = await Permission.locationAlways.status;

    return location.isGranted && locationAlways.isGranted;
  }

  Future<bool> requestPermissions() async {
    final location = await Permission.location.request();
    final locationAlways = await Permission.locationAlways.request();

    return location.isGranted && locationAlways.isGranted;
  }

  Future<void> startTracking({
    String? originName,
    String? destinationName,
    TransportMode? transportMode,
  }) async {
    if (_isTracking) return;

    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      throw Exception('Location permissions not granted');
    }

    try {
      // Start activity recognition
      await _activityService.startTracking();

      // Initialize tracking components
      _locationFilter.reset();
      _kalmanFilter.reset();
      _totalDistance = 0.0;
      _totalPoints = 0;

      // Create new trip
      await _createNewTrip(originName, destinationName);

      // Start location streaming
      await _startLocationStreaming();

      // Initialize background service
      await BackgroundService.instance.initialize();

      _isTracking = true;
      notifyListeners();

      debugPrint('Location tracking started');
    } catch (e) {
      debugPrint('Error starting tracking: $e');
      rethrow;
    }
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    try {
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;

      await _activityService.stopTracking();
      _backgroundTimer?.cancel();

      // Finish current segment and trip
      if (_currentSegment != null) {
        _currentSegment!.finish();
        await _storage.saveSegment(_currentSegment!);
      }

      if (_currentTrip != null) {
        _currentTrip!.finish();
        await _storage.saveTrip(_currentTrip!);
      }

      _isTracking = false;
      _isBackgroundMode = false;
      _currentTrip = null;
      _currentSegment = null;
      _currentPointCache = null;

      notifyListeners();
      debugPrint('Location tracking stopped');
    } catch (e) {
      debugPrint('Error stopping tracking: $e');
      rethrow;
    }
  }

  Future<void> pauseTracking() async {
    if (!_isTracking) return;

    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    notifyListeners();
  }

  Future<void> resumeTracking() async {
    if (!_isTracking) return;

    await _startLocationStreaming();
    notifyListeners();
  }

  void switchToBackgroundMode() {
    if (!_isTracking || _isBackgroundMode) return;

    _isBackgroundMode = true;

    // Switch to timer-based location updates for battery optimization
    _positionStreamSubscription?.cancel();
    _startBackgroundLocationUpdates();

    notifyListeners();
    debugPrint('Switched to background mode');
  }

  void switchToForegroundMode() {
    if (!_isBackgroundMode) return;

    _isBackgroundMode = false;
    _backgroundTimer?.cancel();

    // Resume real-time location streaming
    _startLocationStreaming();

    notifyListeners();
    debugPrint('Switched to foreground mode');
  }

  Future<void> _createNewTrip(
      String? originName, String? destinationName) async {
    _currentTrip = Trip(
      id: _generateId(),
      startTime: DateTime.now(),
      name: originName != null && destinationName != null
          ? '$originName to $destinationName'
          : null,
    );

    await _storage.saveTrip(_currentTrip!);
    await _createNewSegment(_activityService.currentTransportMode);
  }

  Future<void> _createNewSegment(String transportMode) async {
    // Finish current segment if exists
    if (_currentSegment != null) {
      _currentSegment!.finish();
      await _storage.saveSegment(_currentSegment!);
    }

    _currentSegment = Segment(
      id: _generateId(),
      tripId: _currentTrip!.id,
      startTime: DateTime.now(),
      transportMode: transportMode,
    );

    _currentTrip!.addSegmentId(_currentSegment!.id);
    await _storage.saveSegment(_currentSegment!);
    await _storage.saveTrip(_currentTrip!);

    // Reset point cache for new segment
    _currentPointCache = null;

    debugPrint('Created new segment with mode: $transportMode');
  }

  Future<void> _startLocationStreaming() async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onLocationUpdate,
      onError: _onLocationError,
    );
  }

  void _startBackgroundLocationUpdates() {
    _backgroundTimer = Timer.periodic(
      const Duration(seconds: 30), // Less frequent for battery savings
      (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition();
          _onLocationUpdate(position);
        } catch (e) {
          debugPrint('Background location error: $e');
        }
      },
    );
  }

  Future<void> _onLocationUpdate(Position position) async {
    if (!_isTracking) return;

    _currentPosition = position;

    // Check for transport mode changes
    final currentMode = _activityService.currentTransportMode;
    if (_currentSegment != null &&
        _currentSegment!.transportMode != currentMode) {
      await _createNewSegment(currentMode);
    }

    // Apply location filtering
    final activityType = _activityService.currentTransportMode;
    if (!_locationFilter.shouldAcceptLocation(position, activityType)) {
      return;
    }

    // Apply Kalman filtering for smoothing
    final filteredPosition =
        _kalmanFilter.processLocation(position, activityType);
    if (filteredPosition == null) return;

    // Process the location point
    await _processLocationPoint(filteredPosition);
  }

  Future<void> _processLocationPoint(Position position) async {
    final locationPoint = LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp ?? DateTime.now(),
      speed: position.speed,
      heading: position.heading,
      altitude: position.altitude, // FIXED: Remove ?? 0.0
      accuracy: position.accuracy,
      activityType: _activityService.getActivityDisplayString(),
      transportMode: _activityService.currentTransportMode,
    );

    // Ensure we have a point cache
    if (_currentPointCache == null || _currentPointCache!.isFull) {
      await _createNewPointCache();
    }

    // Add point to cache
    _currentPointCache!.addPoint(locationPoint);
    await _storage.savePointCache(_currentPointCache!);

    // Update statistics
    if (_lastRecordedPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastRecordedPosition!.latitude,
        _lastRecordedPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      _totalDistance += distance;
      _currentTrip!
          .updateStatistics(additionalDistance: distance, additionalPoints: 1);
      _currentSegment!
          .updateStatistics(additionalDistance: distance, additionalPoints: 1);

      await _storage.saveTrip(_currentTrip!);
      await _storage.saveSegment(_currentSegment!);
    }

    _lastRecordedPosition = position;
    _totalPoints++;

    // Update clustering
    ClusteringService.instance.analyzePoint(locationPoint);

    notifyListeners();
  }

  Future<void> _createNewPointCache() async {
    _currentPointCache = PointCache(
      id: _generateId(),
      segmentId: _currentSegment!.id,
      sequenceNumber: _currentSegment!.pointCacheIds.length,
    );

    _currentSegment!.addPointCacheId(_currentPointCache!.id);
    await _storage.savePointCache(_currentPointCache!);
    await _storage.saveSegment(_currentSegment!);
  }

  void _onLocationError(dynamic error) {
    debugPrint('Location stream error: $error');
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

// MOVED: TransportMode enum - but this might conflict with existing models
// Consider using the one from your models.dart instead
enum TransportMode { driving, bus, walking, cycling, train, still }

// FIXED: Extension definition
extension LocationPointExtension on LocationPoint {
  LatLng toLatLng() => LatLng(latitude, longitude);
}
