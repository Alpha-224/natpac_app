import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/trip_new.dart';
import '../data/models/segment.dart';
import '../data/models/point_cache.dart';
import '../data/models/location_point.dart';
import '../data/models/place_cluster.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._();
  BackgroundService._();
  static BackgroundService get instance => _instance;

  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'travel_tracker_channel',
        initialNotificationTitle: 'Travel Tracker',
        initialNotificationContent: 'Tracking your journey',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> start() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      _service.startService();
    }
  }

  Future<void> stop() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
    }
  }

  void updateNotification({
    required String title,
    required String content,
  }) {
    _service.invoke('updateNotification', {
      'title': title,
      'content': content,
    });
  }

  void sendData(Map<String, dynamic> data) {
    _service.invoke('sendData', data);
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize Hive for background storage
  await Hive.initFlutter();

  // Register adapters
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(LocationPointAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(PointCacheAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(SegmentAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(TripAdapter());
  }

  late Box tripBox;
  late Box segmentBox;
  late Box pointCacheBox;

  try {
    tripBox = await Hive.openBox('trips');
    segmentBox = await Hive.openBox('segments');
    pointCacheBox = await Hive.openBox('pointCaches');
  } catch (e) {
    debugPrint('Error opening Hive boxes: $e');
    return;
  }

  Timer? locationTimer;
  Position? lastPosition;
  double totalDistance = 0.0;
  int pointCount = 0;

  // Get active trip
  Trip? activeTrip;
  try {
    activeTrip =
        tripBox.values.cast<Trip>().where((trip) => trip.isActive).firstOrNull;
  } catch (e) {
    debugPrint('Error getting active trip: $e');
  }

  if (activeTrip == null) {
    debugPrint('No active trip found, stopping background service');
    service.stopSelf();
    return;
  }

  // Start location tracking
  locationTimer = Timer.periodic(
    const Duration(seconds: 60), // Every minute in background
    (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 10,
          ),
        );

        if (lastPosition != null) {
          final distance = Geolocator.distanceBetween(
            lastPosition!.latitude,
            lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          if (distance > 10) {
            // Only save if moved more than 10 meters
            totalDistance += distance;
            pointCount++;

            // Create location point
            final locationPoint = LocationPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: DateTime.now(),
              speed: position.speed,
              heading: position.heading,
              altitude: position.altitude,
              accuracy: position.accuracy,
              activityType: 'Background',
              transportMode: 'UNKNOWN',
            );

            // Get or create point cache
            final activeSegment = segmentBox.values
                .cast<Segment>()
                .where((segment) => segment.isActive)
                .firstOrNull;

            if (activeSegment != null) {
              // Find or create current point cache
              PointCache? currentCache;

              if (activeSegment.pointCacheIds.isNotEmpty) {
                final lastCacheId = activeSegment.pointCacheIds.last;
                currentCache = pointCacheBox.get(lastCacheId);
              }

              if (currentCache == null || currentCache.isFull) {
                // Create new point cache
                currentCache = PointCache(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  segmentId: activeSegment.id,
                  sequenceNumber: activeSegment.pointCacheIds.length,
                );

                activeSegment.addPointCacheId(currentCache.id);
                await pointCacheBox.put(currentCache.id, currentCache);
                await segmentBox.put(activeSegment.id, activeSegment);
              }

              // Add point to cache
              currentCache.addPoint(locationPoint);
              await pointCacheBox.put(currentCache.id, currentCache);

              // FIXED: Add null checks for activeTrip
              if (activeTrip != null) {
                activeTrip.updateStatistics(
                  additionalDistance: distance,
                  additionalPoints: 1,
                );
                activeSegment.updateStatistics(
                  additionalDistance: distance,
                  additionalPoints: 1,
                );

                await tripBox.put(activeTrip.id, activeTrip);
                await segmentBox.put(activeSegment.id, activeSegment);
              }
            }

            lastPosition = position;

            // Update notification
            service.invoke('updateNotification', {
              'title': 'Trip Tracking',
              'content':
                  'Distance: ${(totalDistance / 1000).toStringAsFixed(1)} km • Points: $pointCount',
            });
          }
        } else {
          lastPosition = position;
        }
      } catch (e) {
        debugPrint('Background location error: $e');
      }
    },
  );

  // Listen for stop service
  service.on('stopService').listen((event) {
    locationTimer?.cancel();
    service.stopSelf();
  });

  // Listen for notification updates
  service.on('updateNotification').listen((event) {
    if (event != null) {
      debugPrint('Notification update received');
    }
  });

  // Listen for data requests
  service.on('sendData').listen((event) {
    debugPrint('Data request received');
  });

  debugPrint('Background service started successfully');
}
