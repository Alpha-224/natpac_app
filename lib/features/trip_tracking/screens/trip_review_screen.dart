import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models.dart';
import '../../home/bloc/trip_bloc.dart';
import '../../home/bloc/trip_event.dart';
import '../../authentication/screens/main_nav_screen.dart';

class TripReviewScreen extends StatefulWidget {
  final Trip trip;

  const TripReviewScreen({
    super.key,
    required this.trip,
  });

  @override
  State<TripReviewScreen> createState() => _TripReviewScreenState();
}

class _TripReviewScreenState extends State<TripReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _companionsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _costController.dispose();
    _companionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _getTransportModeLabel(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving: // FIXED: car -> driving
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
      case TransportMode.driving: // FIXED: car -> driving
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

  void _saveTrip() {
    if (_formKey.currentState!.validate()) {
// Create an updated trip with additional details
      final updatedTrip = Trip(
        id: widget.trip.id,
        originName: widget.trip.originName,
        destinationName: widget.trip.destinationName,
        distanceInKm: widget.trip.distanceInKm,
        duration: widget.trip.duration,
        transportMode: widget.trip.transportMode,
        timestamp: widget.trip.timestamp,
        routePoints: widget.trip.routePoints,
// Add additional fields if your Trip model supports them
// cost: _costController.text.isNotEmpty ? double.tryParse(_costController.text) : null,
// companions: _companionsController.text.isNotEmpty ? int.tryParse(_companionsController.text) : null,
// notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

// Dispatch to TripBloc
      context.read<TripBloc>().add(AddTrip(trip: updatedTrip));

// Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

// Navigate back to main nav screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
// REMOVED: unused bounds variable

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Trip'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
// Trip Summary Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip Summary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

// Route
                      Row(
                        children: [
                          Icon(
                            Icons.route,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.trip.originName} → ${widget.trip.destinationName}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

// Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Icon(
                                Icons.straighten,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.trip.distanceInKm.toStringAsFixed(2)} km',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'Distance',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(
                                Icons.timer,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDuration(widget.trip.duration),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'Duration',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(
                                _getTransportModeIcon(
                                    widget.trip.transportMode),
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getTransportModeLabel(
                                    widget.trip.transportMode),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                'Mode',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

// Map Card
              if (widget.trip.routePoints.isNotEmpty) ...[
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route Map',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter:
                                    widget.trip.routePoints.isNotEmpty
                                        ? widget.trip.routePoints[
                                            widget.trip.routePoints.length ~/ 2]
                                        : const LatLng(10.0261, 76.3125),
                                initialZoom: 13.0,
                                interactionOptions: const InteractionOptions(
                                  flags:
                                      InteractiveFlag.none, // Make map static
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.natpac.trip_tracker',
                                ),
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: widget.trip.routePoints,
                                      strokeWidth: 4.0,
                                      color: Colors.deepPurple,
                                    ),
                                  ],
                                ),
                                MarkerLayer(
                                  markers: [
// Start marker
                                    if (widget.trip.routePoints.isNotEmpty)
                                      Marker(
                                        point: widget.trip.routePoints.first,
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.green,
                                          size: 30,
                                        ),
                                      ),
// End marker
                                    if (widget.trip.routePoints.isNotEmpty)
                                      Marker(
                                        point: widget.trip.routePoints.last,
                                        child: const Icon(
                                          Icons.stop,
                                          color: Colors.red,
                                          size: 30,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

// Additional Details Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

// Cost field
                      TextFormField(
                        controller: _costController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Trip Cost (₹)',
                          hintText: 'Enter trip cost (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid amount';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

// Companions field
                      TextFormField(
                        controller: _companionsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Number of Companions',
                          hintText: 'How many people traveled with you?',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final companions = int.tryParse(value);
                            if (companions == null || companions < 0) {
                              return 'Please enter a valid number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

// Notes field
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Add any notes about this trip (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

// Save Trip Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveTrip,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
