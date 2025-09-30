// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripAdapter extends TypeAdapter<Trip> {
  @override
  final int typeId = 0;

  @override
  Trip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Trip(
      id: fields[0] as String,
      originName: fields[1] as String,
      destinationName: fields[2] as String,
      timestamp: fields[3] as DateTime,
      distanceInKm: fields[4] as double,
      duration: fields[8] as Duration,
      transportMode: fields[6] as TransportMode,
      routePoints: (fields[7] as List).cast<LatLng>(),
    );
  }

  @override
  void write(BinaryWriter writer, Trip obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.originName)
      ..writeByte(2)
      ..write(obj.destinationName)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.distanceInKm)
      ..writeByte(5)
      ..write(obj.durationMinutes)
      ..writeByte(6)
      ..write(obj.transportMode)
      ..writeByte(7)
      ..write(obj.routePoints)
      ..writeByte(8)
      ..write(obj.duration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlannedTripAdapter extends TypeAdapter<PlannedTrip> {
  @override
  final int typeId = 1;

  @override
  PlannedTrip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedTrip(
      id: fields[0] as String,
      originName: fields[1] as String,
      destinationName: fields[2] as String,
      plannedDateTime: fields[3] as DateTime,
      transportMode: fields[4] as TransportMode,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedTrip obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.originName)
      ..writeByte(2)
      ..write(obj.destinationName)
      ..writeByte(3)
      ..write(obj.plannedDateTime)
      ..writeByte(4)
      ..write(obj.transportMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedTripAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransportModeAdapter extends TypeAdapter<TransportMode> {
  @override
  final int typeId = 2;

  @override
  TransportMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransportMode.walking;
      case 1:
        return TransportMode.driving;
      case 2:
        return TransportMode.cycling;
      case 3:
        return TransportMode.bus;
      case 4:
        return TransportMode.train;
      case 5:
        return TransportMode.still;
      default:
        return TransportMode.walking;
    }
  }

  @override
  void write(BinaryWriter writer, TransportMode obj) {
    switch (obj) {
      case TransportMode.walking:
        writer.writeByte(0);
        break;
      case TransportMode.driving:
        writer.writeByte(1);
        break;
      case TransportMode.cycling:
        writer.writeByte(2);
        break;
      case TransportMode.bus:
        writer.writeByte(3);
        break;
      case TransportMode.train:
        writer.writeByte(4);
        break;
      case TransportMode.still:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransportModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
