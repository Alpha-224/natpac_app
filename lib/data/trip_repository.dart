import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'models.dart';

class TripRepository {
  static const String _tripsBoxName = 'trips';
  static const String _plannedTripsBoxName = 'planned_trips';

  Box<Trip>? _tripsBox;
  Box<PlannedTrip>? _plannedTripsBox;

  // Initialize Hive boxes
  Future<void> initialize() async {
    try {
      await Hive.initFlutter();

      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(TripAdapter());
        debugPrint('Registered TripAdapter');
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PlannedTripAdapter());
        debugPrint('Registered PlannedTripAdapter');
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(TransportModeAdapter());
        debugPrint('Registered TransportModeAdapter');
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(LatLngAdapter());
        debugPrint('Registered LatLngAdapter');
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(DurationAdapter());
        debugPrint('Registered DurationAdapter');
      }

      _tripsBox = await Hive.openBox<Trip>(_tripsBoxName);
      _plannedTripsBox = await Hive.openBox<PlannedTrip>(_plannedTripsBoxName);

      debugPrint('Hive boxes opened successfully');
      debugPrint('Trips box has ${_tripsBox?.length ?? 0} items');
      debugPrint(
          'Planned trips box has ${_plannedTripsBox?.length ?? 0} items');
    } catch (e) {
      debugPrint('Error initializing Hive: $e');
      rethrow;
    }
  }

  List<Trip> getTrips() {
    try {
      final trips = _tripsBox?.values.toList() ?? [];
      debugPrint('Loading ${trips.length} trips from Hive');
      return trips;
    } catch (e) {
      debugPrint('Error loading trips: $e');
      return [];
    }
  }

  List<PlannedTrip> getPlannedTrips() {
    try {
      final plannedTrips = _plannedTripsBox?.values.toList() ?? [];
      debugPrint('Loading ${plannedTrips.length} planned trips from Hive');
      return plannedTrips;
    } catch (e) {
      debugPrint('Error loading planned trips: $e');
      return [];
    }
  }

  Future<void> addTrip(Trip trip) async {
    try {
      await _tripsBox?.put(trip.id, trip);
      debugPrint(
          'Added trip ${trip.id} to Hive. Box now has ${_tripsBox?.length} items');
    } catch (e) {
      debugPrint('Error adding trip: $e');
    }
  }

  Future<void> addPlannedTrip(PlannedTrip trip) async {
    try {
      await _plannedTripsBox?.put(trip.id, trip);
      debugPrint(
          'Added planned trip ${trip.id} to Hive. Box now has ${_plannedTripsBox?.length} items');
    } catch (e) {
      debugPrint('Error adding planned trip: $e');
    }
  }

  Future<void> removeTrip(String id) async {
    try {
      await _tripsBox?.delete(id);
      debugPrint('Removed trip $id from Hive');
    } catch (e) {
      debugPrint('Error removing trip: $e');
    }
  }

  Future<void> removePlannedTrip(String id) async {
    try {
      await _plannedTripsBox?.delete(id);
      debugPrint('Removed planned trip $id from Hive');
    } catch (e) {
      debugPrint('Error removing planned trip: $e');
    }
  }

  Trip? getTripById(String id) {
    try {
      return _tripsBox?.get(id);
    } catch (e) {
      debugPrint('Error getting trip by id: $e');
      return null;
    }
  }

  PlannedTrip? getPlannedTripById(String id) {
    try {
      return _plannedTripsBox?.get(id);
    } catch (e) {
      debugPrint('Error getting planned trip by id: $e');
      return null;
    }
  }

  Future<void> deleteAllTrips() async {
    try {
      await _tripsBox?.clear();
      debugPrint('Cleared all trips from Hive');
    } catch (e) {
      debugPrint('Error clearing trips: $e');
    }
  }

  Future<void> savePlannedTrip(PlannedTrip plannedTrip) async {
    await addPlannedTrip(plannedTrip);
  }

  Future<void> deletePlannedTrip(String id) async {
    await removePlannedTrip(id);
  }

  Future<void> deleteTrip(String id) async {
    await removeTrip(id);
  }

  // Add this method to check Hive status
  void debugHiveStatus() {
    debugPrint('=== HIVE STATUS ===');
    debugPrint('Trips box open: ${_tripsBox?.isOpen}');
    debugPrint('Planned trips box open: ${_plannedTripsBox?.isOpen}');
    debugPrint('Trips count: ${_tripsBox?.length}');
    debugPrint('Planned trips count: ${_plannedTripsBox?.length}');
    debugPrint('==================');
  }

  Future<void> clearAllData() async {
    try {
      await _tripsBox?.clear();
      await _plannedTripsBox?.clear();
      debugPrint('Cleared all Hive data');
    } catch (e) {
      debugPrint('Error clearing Hive data: $e');
    }
  }
}
