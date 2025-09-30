// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'segment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SegmentAdapter extends TypeAdapter<Segment> {
  @override
  final int typeId = 2;

  @override
  Segment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Segment(
      id: fields[0] as String,
      tripId: fields[1] as String,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime?,
      transportMode: fields[4] as String,
      pointCacheIds: (fields[5] as List?)?.cast<String>(),
      totalDistance: fields[6] as double,
      averageSpeed: fields[7] as double,
      maxSpeed: fields[8] as double,
      pointCount: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Segment obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tripId)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.transportMode)
      ..writeByte(5)
      ..write(obj.pointCacheIds)
      ..writeByte(6)
      ..write(obj.totalDistance)
      ..writeByte(7)
      ..write(obj.averageSpeed)
      ..writeByte(8)
      ..write(obj.maxSpeed)
      ..writeByte(9)
      ..write(obj.pointCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SegmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
