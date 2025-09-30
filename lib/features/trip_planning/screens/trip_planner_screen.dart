import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../../data/models.dart';
import '../../home/bloc/trip_bloc.dart';
import '../../home/bloc/trip_event.dart';

class TripPlannerScreen extends StatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  State<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends State<TripPlannerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  LatLng _initialCenter = const LatLng(10.0261, 76.3125); // Kochi, Kerala
  LatLng? _originLocation;
  LatLng? _destinationLocation;

  List<dynamic> _searchResults = [];
  bool _isSearchingOrigin = true;
  bool _isLoading = false;
  List<LatLng> _routePoints = [];
  Timer? _searchTimer;

  // Trip planning variables
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  TransportMode _selectedTransportMode = TransportMode.driving;

  // UI state variables
  bool _showTripDetails = false;
  bool _showRoutePreview = false;
  final ScrollController _scrollController = ScrollController();

  // Route info for display
  double _routeDistance = 0.0; // in kilometers
  int _routeDuration = 0; // in minutes

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _setupSearchListeners();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _searchTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final location = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _initialCenter = location;
        });
        _mapController.move(location, 15.0);
      }

      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }

      final Position position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _initialCenter = location;
      });
      _mapController.move(location, 15.0);
    } catch (e) {
      debugPrint('Failed to get current location: $e');
    }
  }

  void _setupSearchListeners() {
    _originController.addListener(() => _onSearchChanged(true));
    _destinationController.addListener(() => _onSearchChanged(false));

    _originFocusNode.addListener(() {
      if (_originFocusNode.hasFocus) {
        setState(() {
          _isSearchingOrigin = true;
          _showTripDetails = false;
          _showRoutePreview = false;
          if (_originController.text.isNotEmpty) {
            _onSearchChanged(true);
          }
        });
      }
    });

    _destinationFocusNode.addListener(() {
      if (_destinationFocusNode.hasFocus) {
        setState(() {
          _isSearchingOrigin = false;
          _showTripDetails = false;
          _showRoutePreview = false;
          if (_destinationController.text.isNotEmpty) {
            _onSearchChanged(false);
          }
        });
      }
    });
  }

  void _onSearchChanged(bool isOrigin) {
    setState(() {
      _isSearchingOrigin = isOrigin;
      _showTripDetails = false;
      _showRoutePreview = false;
    });

    final query =
        isOrigin ? _originController.text : _destinationController.text;
    _searchTimer?.cancel();

    if (query.isNotEmpty) {
      _searchTimer = Timer(const Duration(milliseconds: 500), () {
        _searchPlaces(query);
      });
    } else {
      setState(() {
        _searchResults = [];
        if (isOrigin) {
          _originLocation = null;
        } else {
          _destinationLocation = null;
        }
        _routePoints = [];
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=5&addressdetails=1&countrycodes=IN',
        ),
        headers: {
          'User-Agent': 'NATPAC-Trip-Tracker/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        setState(() {
          _searchResults = results;
        });
      } else {
        debugPrint('Search request failed: ${response.statusCode}');
        setState(() {
          _searchResults = [];
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _searchResults = [];
      });
    }
  }

  void _selectPlace(dynamic place) {
    final lat = double.parse(place['lat']);
    final lon = double.parse(place['lon']);
    final placeName = place['display_name'] as String;
    final location = LatLng(lat, lon);

    setState(() {
      if (_isSearchingOrigin) {
        _originLocation = location;
        _originController.text = placeName;
        _originFocusNode.unfocus();
      } else {
        _destinationLocation = location;
        _destinationController.text = placeName;
        _destinationFocusNode.unfocus();
      }
      _searchResults = [];
    });

    if (_originLocation != null && _destinationLocation != null) {
      _getRoute();
    }

    _mapController.move(location, 14.0);
  }

  // FIXED: Use OSRM for free, reliable routing with actual roads
  Future<void> _getRoute() async {
    if (_originLocation == null || _destinationLocation == null) return;

    setState(() {
      _isLoading = true;
      _showTripDetails = false;
      _showRoutePreview = false;
    });

    try {
      // OSRM endpoints based on transport mode
      String profile = 'car';
      switch (_selectedTransportMode) {
        case TransportMode.walking:
          profile = 'foot';
          break;
        case TransportMode.cycling:
          profile = 'bike';
          break;
        case TransportMode.driving:
        case TransportMode.bus:
        case TransportMode.train:
        default:
          profile = 'car';
          break;
      }

      // Use OSRM public API - FREE, no API key needed
      final url =
          'https://router.project-osrm.org/route/v1/$profile/${_originLocation!.longitude},${_originLocation!.latitude};${_destinationLocation!.longitude},${_destinationLocation!.latitude}?overview=full&geometries=geojson';

      debugPrint('🗺️ Requesting route from OSRM: $url');

      final response = await http.get(Uri.parse(url));

      debugPrint('📡 OSRM Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;

          // Convert coordinates to LatLng
          final List<LatLng> routePoints = coordinates.map<LatLng>((coord) {
            return LatLng(
              coord[1].toDouble(), // latitude
              coord[0].toDouble(), // longitude
            );
          }).toList();

          // Extract distance (in meters) and duration (in seconds)
          final distance =
              (route['distance'] as num).toDouble() / 1000; // Convert to km
          final duration =
              (route['duration'] as num).toDouble() / 60; // Convert to minutes

          debugPrint(
              '✅ Route found: ${routePoints.length} points, ${distance.toStringAsFixed(2)} km, ${duration.round()} min');

          setState(() {
            _routePoints = routePoints;
            _routeDistance = distance;
            _routeDuration = duration.round();
            _isLoading = false;
            _showRoutePreview = true;
          });

          if (_routePoints.isNotEmpty) {
            _fitMapToRoute();
          }
        } else {
          debugPrint('❌ OSRM returned error: ${data['code']}');
          _handleFallbackRoute();
        }
      } else {
        debugPrint('❌ OSRM HTTP error: ${response.statusCode}');
        _handleFallbackRoute();
      }
    } catch (e) {
      debugPrint('❌ Route error: $e');
      _handleFallbackRoute();
    }
  }

  void _handleFallbackRoute() {
    debugPrint('⚠️ Using straight line fallback');
    // Calculate straight-line distance using Haversine formula
    final distance = Geolocator.distanceBetween(
          _originLocation!.latitude,
          _originLocation!.longitude,
          _destinationLocation!.latitude,
          _destinationLocation!.longitude,
        ) /
        1000; // Convert to km

    // Estimate duration based on transport mode
    double avgSpeed = 40.0; // km/h for driving
    switch (_selectedTransportMode) {
      case TransportMode.walking:
        avgSpeed = 5.0;
        break;
      case TransportMode.cycling:
        avgSpeed = 15.0;
        break;
      case TransportMode.driving:
      case TransportMode.bus:
      case TransportMode.train:
      default:
        avgSpeed = 40.0;
        break;
    }

    final duration = (distance / avgSpeed * 60).round(); // Convert to minutes

    setState(() {
      _routePoints = [_originLocation!, _destinationLocation!];
      _routeDistance = distance;
      _routeDuration = duration;
      _isLoading = false;
      _showRoutePreview = true;
    });
    _fitMapToRoute();
  }

  void _fitMapToRoute() {
    if (_routePoints.isEmpty) return;

    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;

    for (final point in _routePoints) {
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
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
    );
  }

  void _clearRoute() {
    setState(() {
      _originLocation = null;
      _destinationLocation = null;
      _originController.clear();
      _destinationController.clear();
      _routePoints = [];
      _searchResults = [];
      _selectedDate = null;
      _selectedTime = null;
      _selectedTransportMode = TransportMode.driving;
      _showTripDetails = false;
      _showRoutePreview = false;
      _routeDistance = 0.0;
      _routeDuration = 0;
    });
  }

  void _continueToTripDetails() {
    setState(() {
      _showRoutePreview = false;
      _showTripDetails = true;
    });
    _scrollToTripDetails();
  }

  void _scrollToTripDetails() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  // FIXED: Properly save trip and navigate back
  void _confirmTrip() async {
    if (_originLocation == null ||
        _destinationLocation == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all trip details'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final plannedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final plannedTrip = PlannedTrip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      originName: _originController.text,
      destinationName: _destinationController.text,
      plannedDateTime: plannedDateTime,
      transportMode: _selectedTransportMode,
    );

    try {
      debugPrint(
          '💾 Creating planned trip: ${plannedTrip.originName} -> ${plannedTrip.destinationName}');
      debugPrint('   ID: ${plannedTrip.id}');
      debugPrint('   DateTime: $plannedDateTime');
      debugPrint('   Transport: ${plannedTrip.transportMode}');

      // Add the trip to BLoC
      if (mounted) {
        context
            .read<TripBloc>()
            .add(CreatePlannedTrip(plannedTrip: plannedTrip));
        debugPrint('✅ Trip event added to BLoC');
      }

      // Wait a bit for the event to be processed
      await Future.delayed(const Duration(milliseconds: 500));

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trip planned for ${plannedDateTime.day}/${plannedDateTime.month}/${plannedDateTime.year} '
              'at ${_selectedTime!.format(context)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Small delay to ensure the snackbar is visible before navigating
      await Future.delayed(const Duration(milliseconds: 300));

      // Navigate back with result
      if (mounted) {
        debugPrint('🔙 Navigating back to home screen');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('❌ Error confirming trip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
  }

  bool get _canConfirmTrip =>
      _originLocation != null &&
      _destinationLocation != null &&
      _routePoints.isNotEmpty &&
      _selectedDate != null &&
      _selectedTime != null;

  bool get _shouldShowSearchResults =>
      _searchResults.isNotEmpty &&
      (_originFocusNode.hasFocus || _destinationFocusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Trip'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          if (_routePoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearRoute,
              tooltip: 'Clear Route',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: _showTripDetails ? 6 : 10,
            child: Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.natpac.trip_tracker',
                    ),

                    // Route polyline - shows actual road path from OSRM
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),

                    // Markers
                    MarkerLayer(
                      markers: [
                        if (_originLocation != null)
                          Marker(
                            point: _originLocation!,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        if (_destinationLocation != null)
                          Marker(
                            point: _destinationLocation!,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Search overlay
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _originController,
                            focusNode: _originFocusNode,
                            decoration: const InputDecoration(
                              labelText: 'From',
                              hintText: 'Search for starting location',
                              prefixIcon:
                                  Icon(Icons.trip_origin, color: Colors.green),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _destinationController,
                            focusNode: _destinationFocusNode,
                            decoration: const InputDecoration(
                              labelText: 'To',
                              hintText: 'Search for destination',
                              prefixIcon:
                                  Icon(Icons.location_on, color: Colors.red),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          ),
                          if (_isLoading) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Finding shortest route...',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Search results overlay
                if (_shouldShowSearchResults)
                  Positioned(
                    top: 200,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 8,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final place = _searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on, size: 20),
                              title: Text(
                                place['display_name'] ?? 'Unknown',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              onTap: () => _selectPlace(place),
                              dense: true,
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // Route preview info card
                if (_showRoutePreview && !_showTripDetails)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shortest Route',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.straighten,
                                  size: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_routeDistance.toStringAsFixed(1)} km',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(width: 24),
                                Icon(
                                  Icons.access_time,
                                  size: 20,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDuration(_routeDuration),
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _continueToTripDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom section for trip details
          if (_showTripDetails)
            Expanded(
              flex: 4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Trip Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 20),

                      // Transport mode selection
                      Text(
                        'Transport Mode',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 70,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: TransportMode.values
                              .where((mode) => mode != TransportMode.still)
                              .map((mode) {
                            final isSelected = _selectedTransportMode == mode;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getTransportModeIcon(mode),
                                      size: 24,
                                      color: isSelected ? Colors.white : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getTransportModeLabel(mode),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedTransportMode = mode;
                                  });
                                  if (_originLocation != null &&
                                      _destinationLocation != null) {
                                    _getRoute();
                                  }
                                },
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Date and time selection
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              elevation: 2,
                              child: InkWell(
                                onTap: _selectDate,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: _selectedDate != null
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _selectedDate != null
                                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                            : 'Select Date',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: _selectedDate != null
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                              fontWeight: _selectedDate != null
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              elevation: 2,
                              child: InkWell(
                                onTap: _selectTime,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: _selectedTime != null
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _selectedTime != null
                                            ? _selectedTime!.format(context)
                                            : 'Select Time',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: _selectedTime != null
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                              fontWeight: _selectedTime != null
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Confirm button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _canConfirmTrip ? _confirmTrip : null,
                          icon: const Icon(Icons.check_circle),
                          label: const Text(
                            'Confirm Trip',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            disabledBackgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            disabledForegroundColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
