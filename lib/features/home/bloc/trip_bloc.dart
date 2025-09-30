import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/trip_repository.dart';
import '../../../data/models.dart';
import 'trip_event.dart';
import 'trip_state.dart';

class TripBloc extends Bloc<TripEvent, TripState> {
  final TripRepository tripRepository;

  TripBloc({required this.tripRepository}) : super(const TripInitial()) {
    on<LoadTrips>(_onLoadTrips);
    on<AddTrip>(_onAddTrip);
    on<ClearAllTrips>(_onClearAllTrips);
    on<CreatePlannedTrip>(_onCreatePlannedTrip);
    on<LoadPlannedTrips>(_onLoadPlannedTrips);
    on<DeletePlannedTrip>(_onDeletePlannedTrip);
    on<DeleteTrip>(_onDeleteTrip);

    // Load data when bloc starts
    add(const LoadTrips());
  }

  Future<void> _onLoadTrips(LoadTrips event, Emitter<TripState> emit) async {
    emit(const TripLoading());

    try {
      // These are synchronous, so no await needed
      final trips = tripRepository.getTrips();
      final plannedTrips = tripRepository.getPlannedTrips();

      // Calculate transport stats
      final Map<TransportMode, double> transportStats = {};
      for (final trip in trips) {
        transportStats[trip.transportMode] =
            (transportStats[trip.transportMode] ?? 0) + trip.distanceInKm;
      }

      // Calculate frequent trips
      final frequentTrips = List<Trip>.from(trips)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      emit(TripLoaded(
        allTrips: trips,
        frequentTrips: frequentTrips,
        plannedTrips: plannedTrips,
        transportStats: transportStats,
      ));
    } catch (e) {
      emit(TripError(message: 'Failed to load trips: $e'));
    }
  }

  Future<void> _onAddTrip(AddTrip event, Emitter<TripState> emit) async {
    try {
      await tripRepository.addTrip(event.trip); // ADD AWAIT BACK
      add(const LoadTrips());
    } catch (e) {
      emit(TripError(message: 'Failed to add trip: $e'));
    }
  }

  Future<void> _onClearAllTrips(
      ClearAllTrips event, Emitter<TripState> emit) async {
    try {
      await tripRepository.deleteAllTrips(); // ADD AWAIT BACK
      add(const LoadTrips());
    } catch (e) {
      emit(TripError(message: 'Failed to clear trips: $e'));
    }
  }

  Future<void> _onCreatePlannedTrip(
      CreatePlannedTrip event, Emitter<TripState> emit) async {
    try {
      await tripRepository.savePlannedTrip(event.plannedTrip); // ADD AWAIT BACK
      add(const LoadTrips());
    } catch (e) {
      emit(TripError(message: 'Failed to create planned trip: $e'));
    }
  }

  Future<void> _onLoadPlannedTrips(
      LoadPlannedTrips event, Emitter<TripState> emit) async {
    add(const LoadTrips()); // Just reload everything
  }

  Future<void> _onDeletePlannedTrip(
      DeletePlannedTrip event, Emitter<TripState> emit) async {
    try {
      await tripRepository
          .deletePlannedTrip(event.plannedTripId); // ADD AWAIT BACK
      add(const LoadTrips());
    } catch (e) {
      emit(TripError(message: 'Failed to delete planned trip: $e'));
    }
  }

  Future<void> _onDeleteTrip(DeleteTrip event, Emitter<TripState> emit) async {
    try {
      await tripRepository.deleteTrip(event.tripId); // ADD AWAIT BACK
      add(const LoadTrips());
    } catch (e) {
      emit(TripError(message: 'Failed to delete trip: $e'));
    }
  }
}
