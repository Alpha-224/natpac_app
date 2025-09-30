import 'package:equatable/equatable.dart';
import '../../../data/models.dart';

abstract class TripState extends Equatable {
  const TripState();

  @override
  List<Object> get props => [];
}

class TripInitial extends TripState {
  const TripInitial();
}

class TripLoading extends TripState {
  const TripLoading();
}

class TripLoaded extends TripState {
  final List<Trip> allTrips;
  final List<Trip> frequentTrips;
  final List<PlannedTrip> plannedTrips;
  final Map<TransportMode, double> transportStats;

  const TripLoaded({
    required this.allTrips,
    required this.frequentTrips,
    required this.plannedTrips,
    required this.transportStats,
  });

  @override
  List<Object> get props =>
      [allTrips, frequentTrips, plannedTrips, transportStats];
}

class TripError extends TripState {
  final String message;

  const TripError({required this.message});

  @override
  List<Object> get props => [message];
}
