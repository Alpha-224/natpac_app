import 'package:hive/hive.dart';

part 'trip_new.g.dart';

@HiveType(typeId: 3)
class Trip extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  DateTime? endTime;

  @HiveField(3)
  final List<String> segmentIds;

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  String? name;

  @HiveField(6)
  String? description;

  @HiveField(7)
  double totalDistance;

  @HiveField(8)
  int totalPoints;

  Trip({
    required this.id,
    required this.startTime,
    this.endTime,
    List<String>? segmentIds,
    this.isActive = true,
    this.name,
    this.description,
    this.totalDistance = 0,
    this.totalPoints = 0,
  }) : segmentIds = segmentIds ?? [];

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get formattedDuration {
    final dur = duration;
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    final seconds = dur.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  double get distanceInKm => totalDistance / 1000;

  double get averageSpeed {
    if (duration.inSeconds == 0) return 0;
    return totalDistance / duration.inSeconds; // m/s
  }

  double get averageSpeedKmh => averageSpeed * 3.6; // Convert m/s to km/h

  void addSegmentId(String segmentId) {
    segmentIds.add(segmentId);
  }

  void updateStatistics({
    double? additionalDistance,
    int? additionalPoints,
  }) {
    if (additionalDistance != null) {
      totalDistance += additionalDistance;
    }

    if (additionalPoints != null) {
      totalPoints += additionalPoints;
    }
  }

  void finish({String? tripName, String? tripDescription}) {
    endTime = DateTime.now();
    isActive = false;

    if (tripName != null) {
      name = tripName;
    }

    if (tripDescription != null) {
      description = tripDescription;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'segmentIds': segmentIds,
      'isActive': isActive,
      'name': name,
      'description': description,
      'totalDistance': totalDistance,
      'totalPoints': totalPoints,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'],
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      segmentIds: List<String>.from(map['segmentIds'] ?? []),
      isActive: map['isActive'] ?? false,
      name: map['name'],
      description: map['description'],
      totalDistance: map['totalDistance'] ?? 0.0,
      totalPoints: map['totalPoints'] ?? 0,
    );
  }
}
