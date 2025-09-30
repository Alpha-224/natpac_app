import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../../data/models.dart';

class TripDetailsScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailsScreen({
    super.key,
    required this.trip,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late TabController _tabController;
  int _selectedSegmentIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapToRoute();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _fitMapToRoute() {
    if (widget.trip.routePoints.isEmpty) return;

    if (widget.trip.routePoints.length == 1) {
      _mapController.move(widget.trip.routePoints.first, 15.0);
      return;
    }

    double minLat = widget.trip.routePoints.first.latitude;
    double maxLat = widget.trip.routePoints.first.latitude;
    double minLng = widget.trip.routePoints.first.longitude;
    double maxLng = widget.trip.routePoints.first.longitude;

    for (final point in widget.trip.routePoints) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  String _getTransportModeLabel(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return 'Car';
      case TransportMode.bus:
        return 'Bus';
      case TransportMode.walking:
        return 'Walking';
      case TransportMode.cycling:
        return 'Cycling';
      case TransportMode.train:
        return 'Train';
      case TransportMode.still:
        return 'Still';
    }
  }

  IconData _getTransportModeIcon(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return Icons.directions_car;
      case TransportMode.bus:
        return Icons.directions_bus;
      case TransportMode.walking:
        return Icons.directions_walk;
      case TransportMode.cycling:
        return Icons.directions_bike;
      case TransportMode.train:
        return Icons.train;
      case TransportMode.still:
        return Icons.location_disabled;
    }
  }

  Color _getTransportModeColor(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return Colors.blue;
      case TransportMode.bus:
        return Colors.green;
      case TransportMode.walking:
        return Colors.orange;
      case TransportMode.cycling:
        return Colors.purple;
      case TransportMode.train:
        return Colors.red;
      case TransportMode.still:
        return Colors.grey;
    }
  }

  double _calculateAverageSpeed() {
    if (widget.trip.duration.inSeconds == 0) return 0;
    return (widget.trip.distanceInKm * 1000) /
        widget.trip.duration.inSeconds; // m/s
  }

  List<LatLng> _getRouteSegments(int segmentIndex) {
    final segmentSize = (widget.trip.routePoints.length / 10).ceil();
    final startIndex = segmentIndex * segmentSize;
    final endIndex = ((segmentIndex + 1) * segmentSize)
        .clamp(0, widget.trip.routePoints.length);

    if (startIndex >= widget.trip.routePoints.length) return [];
    return widget.trip.routePoints.sublist(startIndex, endIndex);
  }

  Widget _buildMapView() {
    if (widget.trip.routePoints.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No route data available',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.trip.routePoints.isNotEmpty
                ? widget.trip.routePoints.first
                : const LatLng(0, 0),
            initialZoom: 15.0,
            onTap: (tapPosition, point) {
              setState(() {
                _selectedSegmentIndex = -1;
              });
            },
          ),
          children: [
            // OpenStreetMap tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'dev.natpac.trip_tracker',
            ),

            // Route polyline with gradient colors
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.trip.routePoints,
                  color: _getTransportModeColor(widget.trip.transportMode),
                  strokeWidth: 4.0,
                  pattern: const StrokePattern.solid(),
                ),
              ],
            ),

            // Start and end markers
            MarkerLayer(
              markers: [
                // Start marker
                if (widget.trip.routePoints.isNotEmpty)
                  Marker(
                    point: widget.trip.routePoints.first,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
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
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 20),
                    ),
                  ),

                // End marker
                if (widget.trip.routePoints.length > 1)
                  Marker(
                    point: widget.trip.routePoints.last,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
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
                      child:
                          const Icon(Icons.stop, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripSummary() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getTransportModeIcon(widget.trip.transportMode),
                  color: _getTransportModeColor(widget.trip.transportMode),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTransportModeLabel(widget.trip.transportMode),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy • HH:mm')
                            .format(widget.trip.timestamp),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Trip statistics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Distance',
                  '${widget.trip.distanceInKm.toStringAsFixed(2)} km',
                  Icons.straighten,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Duration',
                  _formatDuration(widget.trip.duration),
                  Icons.timer,
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Avg Speed',
                  '${(_calculateAverageSpeed() * 3.6).toStringAsFixed(1)} km/h',
                  Icons.speed,
                  Colors.orange,
                ),
                _buildStatItem(
                  'Points',
                  '${widget.trip.routePoints.length}',
                  Icons.location_on,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteDetails() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildLocationTile(
              'Start Location',
              widget.trip.originName,
              Icons.trip_origin,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildLocationTile(
              'End Location',
              widget.trip.destinationName,
              Icons.place,
              Colors.red,
            ),
            if (widget.trip.routePoints.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Route Coordinates',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'First: ${widget.trip.routePoints.first.latitude.toStringAsFixed(6)}, ${widget.trip.routePoints.first.longitude.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                'Last: ${widget.trip.routePoints.last.latitude.toStringAsFixed(6)}, ${widget.trip.routePoints.last.longitude.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTile(
      String label, String location, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
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
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Map'),
            Tab(icon: Icon(Icons.info), text: 'Summary'),
            Tab(icon: Icon(Icons.route), text: 'Route'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement trip sharing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip sharing coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              _fitMapToRoute();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Map Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildMapView(),
                const SizedBox(height: 16),
                if (widget.trip.routePoints.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tap the map to view route details. Green marker shows start, red marker shows end.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Summary Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildTripSummary(),
          ),

          // Route Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildRouteDetails(),
          ),
        ],
      ),
    );
  }
}
