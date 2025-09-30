// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'point_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PointCacheAdapter extends TypeAdapter<PointCache> {
  @override
  final int typeId = 1;

  @override
  PointCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PointCache(
      id: fields[0] as String,
      segmentId: fields[1] as String,
      points: (fields[2] as List?)?.cast<LocationPoint>(),
      sequenceNumber: fields[3] as int,
      createdAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PointCache obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.segmentId)
      ..writeByte(2)
      ..write(obj.points)
      ..writeByte(3)
      ..write(obj.sequenceNumber)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PointCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
