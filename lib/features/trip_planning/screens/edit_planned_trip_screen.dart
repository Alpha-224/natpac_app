import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../../data/models.dart';
import '../../home/bloc/trip_bloc.dart';
import '../../home/bloc/trip_event.dart';

class EditPlannedTripScreen extends StatefulWidget {
  final PlannedTrip plannedTrip;

  const EditPlannedTripScreen({
    super.key,
    required this.plannedTrip,
  });

  @override
  State<EditPlannedTripScreen> createState() => _EditPlannedTripScreenState();
}

class _EditPlannedTripScreenState extends State<EditPlannedTripScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  LatLng _initialCenter = const LatLng(10.0261, 76.3125);
  LatLng? _originLocation;
  LatLng? _destinationLocation;

  List<dynamic> _searchResults = [];
  bool _isSearchingOrigin = true;
  bool _isLoading = false;
  List<LatLng> _routePoints = [];
  Timer? _searchTimer;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late TransportMode _selectedTransportMode;

  bool _hasChanges = false;
  bool _showRoutePreview = false;
  final ScrollController _scrollController = ScrollController();

  double _routeDistance = 0.0;
  int _routeDuration = 0;

  @override
  void initState() {
    super.initState();
    _initializeFromPlannedTrip();
    _setupSearchListeners();
  }

  void _initializeFromPlannedTrip() {
    _originController.text = widget.plannedTrip.originName;
    _destinationController.text = widget.plannedTrip.destinationName;
    _selectedDate = DateTime(
      widget.plannedTrip.plannedDateTime.year,
      widget.plannedTrip.plannedDateTime.month,
      widget.plannedTrip.plannedDateTime.day,
    );
    _selectedTime = TimeOfDay(
      hour: widget.plannedTrip.plannedDateTime.hour,
      minute: widget.plannedTrip.plannedDateTime.minute,
    );
    _selectedTransportMode = widget.plannedTrip.transportMode;

    // Try to geocode the existing locations
    _geocodeExistingLocations();
  }

  Future<void> _geocodeExistingLocations() async {
    try {
      // Geocode origin
      final originResponse = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(widget.plannedTrip.originName)}&limit=1&countrycodes=IN',
        ),
        headers: {'User-Agent': 'NATPAC-Trip-Tracker/1.0'},
      );

      if (originResponse.statusCode == 200) {
        final originResults = json.decode(originResponse.body) as List;
        if (originResults.isNotEmpty) {
          _originLocation = LatLng(
            double.parse(originResults[0]['lat']),
            double.parse(originResults[0]['lon']),
          );
        }
      }

      // Geocode destination
      final destResponse = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(widget.plannedTrip.destinationName)}&limit=1&countrycodes=IN',
        ),
        headers: {'User-Agent': 'NATPAC-Trip-Tracker/1.0'},
      );

      if (destResponse.statusCode == 200) {
        final destResults = json.decode(destResponse.body) as List;
        if (destResults.isNotEmpty) {
          _destinationLocation = LatLng(
            double.parse(destResults[0]['lat']),
            double.parse(destResults[0]['lon']),
          );
        }
      }

      // If both locations found, get route
      if (_originLocation != null && _destinationLocation != null) {
        await _getRoute();
        setState(() {
          _showRoutePreview = true;
        });
      }
    } catch (e) {
      debugPrint('Error geocoding existing locations: $e');
    }
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

  void _setupSearchListeners() {
    _originController.addListener(() => _onSearchChanged(true));
    _destinationController.addListener(() => _onSearchChanged(false));

    _originFocusNode.addListener(() {
      if (_originFocusNode.hasFocus) {
        setState(() {
          _isSearchingOrigin = true;
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
      _showRoutePreview = false;
      _hasChanges = true;
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
        headers: {'User-Agent': 'NATPAC-Trip-Tracker/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        setState(() {
          _searchResults = results;
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
      _hasChanges = true;
    });

    if (_originLocation != null && _destinationLocation != null) {
      _getRoute();
    }

    _mapController.move(location, 14.0);
  }

  Future<void> _getRoute() async {
    if (_originLocation == null || _destinationLocation == null) return;

    setState(() {
      _isLoading = true;
      _showRoutePreview = false;
    });

    try {
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

      final url =
          'https://router.project-osrm.org/route/v1/$profile/${_originLocation!.longitude},${_originLocation!.latitude};${_destinationLocation!.longitude},${_destinationLocation!.latitude}?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;

          final List<LatLng> routePoints = coordinates.map<LatLng>((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          final distance = (route['distance'] as num).toDouble() / 1000;
          final duration = (route['duration'] as num).toDouble() / 60;

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
          _handleFallbackRoute();
        }
      } else {
        _handleFallbackRoute();
      }
    } catch (e) {
      debugPrint('Route error: $e');
      _handleFallbackRoute();
    }
  }

  void _handleFallbackRoute() {
    final distance = Geolocator.distanceBetween(
          _originLocation!.latitude,
          _originLocation!.longitude,
          _destinationLocation!.latitude,
          _destinationLocation!.longitude,
        ) /
        1000;

    double avgSpeed = 40.0;
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

    final duration = (distance / avgSpeed * 60).round();

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

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    if (_originLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select valid origin and destination'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final plannedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final updatedTrip = PlannedTrip(
      id: widget.plannedTrip.id,
      originName: _originController.text,
      destinationName: _destinationController.text,
      plannedDateTime: plannedDateTime,
      transportMode: _selectedTransportMode,
    );

    try {
      if (mounted) {
        context
            .read<TripBloc>()
            .add(DeletePlannedTrip(plannedTripId: widget.plannedTrip.id));
        context
            .read<TripBloc>()
            .add(CreatePlannedTrip(plannedTrip: updatedTrip));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content:
            const Text('Are you sure you want to delete this planned trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (mounted) {
                  context.read<TripBloc>().add(
                        DeletePlannedTrip(plannedTripId: widget.plannedTrip.id),
                      );
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Trip deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                await Future.delayed(const Duration(milliseconds: 300));

                if (mounted) {
                  Navigator.pop(context, true);
                }
              } catch (e) {
                debugPrint('Error deleting trip: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting trip: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
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

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
  }

  bool get _shouldShowSearchResults =>
      _searchResults.isNotEmpty &&
      (_originFocusNode.hasFocus || _destinationFocusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Trip'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveChanges,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deleteTrip();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Trip', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
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

                    // Route polyline
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
                                  'Updating route...',
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

                // Route preview card
                if (_showRoutePreview)
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
                              'Route Preview',
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
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Trip details section
          Container(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                                _hasChanges = true;
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.w600,
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedTime.format(context),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.w600,
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

                  // Save changes button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _hasChanges ? _saveChanges : null,
                      icon: const Icon(Icons.save),
                      label: Text(
                        _hasChanges ? 'Save Changes' : 'No Changes',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
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
                  const SizedBox(height: 12),

                  // Delete button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _deleteTrip,
                      icon: const Icon(Icons.delete),
                      label: const Text(
                        'Delete Trip',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
