// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_cluster.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaceClusterAdapter extends TypeAdapter<PlaceCluster> {
  @override
  final int typeId = 5;

  @override
  PlaceCluster read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlaceCluster(
      id: fields[0] as String,
      centerLatitude: fields[1] as double,
      centerLongitude: fields[2] as double,
      firstSeen: fields[3] as DateTime,
      lastUpdated: fields[4] as DateTime,
      pointCount: fields[5] as int,
      tripId: fields[6] as String,
      segmentIds: (fields[7] as List).cast<String>(),
      averageAccuracy: fields[8] as double,
      isActive: fields[9] as bool,
      label: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PlaceCluster obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.centerLatitude)
      ..writeByte(2)
      ..write(obj.centerLongitude)
      ..writeByte(3)
      ..write(obj.firstSeen)
      ..writeByte(4)
      ..write(obj.lastUpdated)
      ..writeByte(5)
      ..write(obj.pointCount)
      ..writeByte(6)
      ..write(obj.tripId)
      ..writeByte(7)
      ..write(obj.segmentIds)
      ..writeByte(8)
      ..write(obj.averageAccuracy)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.label);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceClusterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
