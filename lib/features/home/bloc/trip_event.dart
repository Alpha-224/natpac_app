import 'package:equatable/equatable.dart';
import '../../../data/models.dart';

abstract class TripEvent extends Equatable {
  const TripEvent();

  @override
  List<Object> get props => [];
}

class LoadTrips extends TripEvent {
  const LoadTrips();
}

class AddTrip extends TripEvent {
  final Trip trip;

  const AddTrip({required this.trip});

  @override
  List<Object> get props => [trip];
}

class ClearAllTrips extends TripEvent {
  const ClearAllTrips();
}

class CreatePlannedTrip extends TripEvent {
  final PlannedTrip plannedTrip;

  const CreatePlannedTrip({required this.plannedTrip});

  @override
  List<Object> get props => [plannedTrip];
}

class LoadPlannedTrips extends TripEvent {
  const LoadPlannedTrips();
}

class DeletePlannedTrip extends TripEvent {
  final String plannedTripId;

  const DeletePlannedTrip({required this.plannedTripId});

  @override
  List<Object> get props => [plannedTripId];
}

// Add this new event
class DeleteTrip extends TripEvent {
  final String tripId;

  const DeleteTrip({required this.tripId});

  @override
  List<Object> get props => [tripId];
}
