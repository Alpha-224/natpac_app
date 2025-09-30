import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../data/models.dart';
import '../../../data/trip_repository.dart'; // ADD THIS IMPORT
import '../../home/bloc/trip_bloc.dart'; // ADD THIS IMPORT
import '../../home/bloc/trip_event.dart'; // ADD THIS IMPORT
import '../../../services/location_service_new.dart' show LocationService;
import 'advanced/analytics_screen.dart';
import 'trip_review_screen.dart';

class TripTrackingScreenNew extends StatefulWidget {
  const TripTrackingScreenNew({super.key});

  @override
  State<TripTrackingScreenNew> createState() => _TripTrackingScreenNewState();
}

class _TripTrackingScreenNewState extends State<TripTrackingScreenNew>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  bool _isTracking = false;
  Position? _currentLocation;
  final List<Position> _routePoints = [];
  DateTime? _tripStartTime;

  // Map controller and location streams
  final MapController _mapController = MapController();
  late final Stream<Position> _positionStream;
  StreamSubscription<Position>? _positionSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _initializeLocationStream();
    _startTimer();
    _getCurrentLocation();
  }

  void _initializeLocationStream() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isTracking) {
        setState(() {
          _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
        });
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );
      if (mounted) {
        setState(() {
          _currentLocation = position;
        });
        _mapController.move(
            LatLng(position.latitude, position.longitude), 16.0);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _calculateDistance() {
    if (_routePoints.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        _routePoints[i].latitude,
        _routePoints[i].longitude,
        _routePoints[i + 1].latitude,
        _routePoints[i + 1].longitude,
      );
    }
    return totalDistance;
  }

  Future<void> _startTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are required for tracking'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isTracking = true;
      _routePoints.clear();
      _elapsedTime = Duration.zero;
      _tripStartTime = DateTime.now();
      if (_currentLocation != null) {
        _routePoints.add(_currentLocation!);
      }
    });

    _pulseController.repeat(reverse: true);

    _positionSubscription = _positionStream.listen((position) {
      if (mounted && _isTracking) {
        setState(() {
          _currentLocation = position;
          _routePoints.add(position);
        });
        _mapController.move(LatLng(position.latitude, position.longitude),
            _mapController.camera.zoom);
      }
    });

    try {
      if (mounted) {
        final locationService =
            Provider.of<LocationService>(context, listen: false);
        await locationService.startTracking();
      }
    } catch (e) {
      debugPrint('LocationService not available: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.play_arrow, color: Colors.white),
              SizedBox(width: 8),
              Text('Trip started! Tracking your journey...'),
            ],
          ),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopTracking() async {
    setState(() {
      _isTracking = false;
    });
    _pulseController.stop();
    _positionSubscription?.cancel();

    try {
      if (mounted) {
        final locationService =
            Provider.of<LocationService>(context, listen: false);
        await locationService.stopTracking();
      }
    } catch (e) {
      debugPrint('LocationService not available: $e');
    }

    // Convert Position list to LatLng list for the Trip model
    final routeLatLngs =
        _routePoints.map((pos) => LatLng(pos.latitude, pos.longitude)).toList();

    // Create Trip using models.dart Trip class
    final completedTrip = Trip(
      id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
      originName: _routePoints.isNotEmpty
          ? '${_routePoints.first.latitude.toStringAsFixed(4)}, ${_routePoints.first.longitude.toStringAsFixed(4)}'
          : 'Unknown',
      destinationName: _routePoints.isNotEmpty
          ? '${_routePoints.last.latitude.toStringAsFixed(4)}, ${_routePoints.last.longitude.toStringAsFixed(4)}'
          : 'Unknown',
      timestamp: _tripStartTime ?? DateTime.now(),
      distanceInKm: _calculateDistance() / 1000,
      duration: _elapsedTime,
      transportMode: TransportMode.walking,
      routePoints: routeLatLngs,
    );

    // SAVE TO REPOSITORY VIA BLOC - THIS IS THE KEY FIX
    if (mounted) {
      try {
        context.read<TripBloc>().add(AddTrip(trip: completedTrip));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Trip saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        debugPrint('Error saving trip: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save trip: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Still navigate to review screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripReviewScreen(trip: completedTrip),
        ),
      );
    }
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMap() {
    if (_currentLocation == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              SizedBox(height: 8),
              Text('Getting location...'),
            ],
          ),
        ),
      );
    }

    final pathPoints =
        _routePoints.map((pos) => LatLng(pos.latitude, pos.longitude)).toList();

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
            initialZoom: 16.0,
            onTap: (tapPosition, point) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _buildFullScreenMap(),
                ),
              );
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'dev.natpac.trip_tracker',
            ),
            if (pathPoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: pathPoints,
                    color: Colors.deepPurple,
                    strokeWidth: 4.0,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(
                      _currentLocation!.latitude, _currentLocation!.longitude),
                  width: 40,
                  height: 40,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isTracking ? _pulseAnimation.value : 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isTracking ? Colors.red : Colors.deepPurple,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenMap() {
    final pathPoints =
        _routePoints.map((pos) => LatLng(pos.latitude, pos.longitude)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Map'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentLocation != null) {
                _mapController.move(
                  LatLng(
                      _currentLocation!.latitude, _currentLocation!.longitude),
                  16.0,
                );
              }
            },
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLocation != null
              ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
              : const LatLng(0, 0),
          initialZoom: 16.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dev.natpac.trip_tracker',
          ),
          if (pathPoints.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: pathPoints,
                  color: Colors.deepPurple,
                  strokeWidth: 6.0,
                ),
              ],
            ),
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(
                      _currentLocation!.latitude, _currentLocation!.longitude),
                  width: 50,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isTracking ? Colors.red : Colors.deepPurple,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double distance = _calculateDistance();
    final int points = _routePoints.length;
    const String activity = 'Walking';
    const String confidence = '85';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Live Trip Tracking'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isTracking)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const ListTile(
                    leading: Icon(Icons.analytics),
                    title: Text('View Analytics'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onTap: () {
                    final routeLatLngs = _routePoints
                        .map((pos) => LatLng(pos.latitude, pos.longitude))
                        .toList();

                    final currentTrip = Trip(
                      id: 'current-trip-${DateTime.now().millisecondsSinceEpoch}',
                      originName: _routePoints.isNotEmpty
                          ? '${_routePoints.first.latitude.toStringAsFixed(4)}, ${_routePoints.first.longitude.toStringAsFixed(4)}'
                          : 'Current Location',
                      destinationName: 'In Progress',
                      timestamp: _tripStartTime ?? DateTime.now(),
                      distanceInKm: distance / 1000,
                      duration: _elapsedTime,
                      transportMode: TransportMode.walking,
                      routePoints: routeLatLngs,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnalyticsScreen(trip: currentTrip),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isTracking
                        ? [Colors.deepPurple, Colors.purple]
                        : [Colors.grey[400]!, Colors.grey[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_isTracking ? Colors.deepPurple : Colors.grey)
                          .withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isTracking ? _pulseAnimation.value : 1.0,
                          child: Icon(
                            _isTracking
                                ? Icons.location_on
                                : Icons.location_off,
                            size: 48,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isTracking ? 'TRACKING ACTIVE' : 'READY TO START',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (_isTracking) ...[
                      const SizedBox(height: 8),
                      Text(
                        '$activity ($confidence% confidence)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Live Map
              _buildLiveMap(),

              const SizedBox(height: 24),

              // Statistics Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard(
                    'Time',
                    _formatDuration(_elapsedTime),
                    Icons.timer,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Distance',
                    '${(distance / 1000).toStringAsFixed(2)} km',
                    Icons.route,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'GPS Points',
                    points.toString(),
                    Icons.place,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Speed',
                    distance > 0 && _elapsedTime.inSeconds > 0
                        ? '${((distance / _elapsedTime.inSeconds) * 3.6).toStringAsFixed(1)} km/h'
                        : '0.0 km/h',
                    Icons.speed,
                    Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Control Button
              Container(
                width: double.infinity,
                height: 60,
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                  onPressed: _isTracking ? _stopTracking : _startTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isTracking ? Colors.red : Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isTracking ? Icons.stop : Icons.play_arrow,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isTracking ? 'END TRIP' : 'START TRIP',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
