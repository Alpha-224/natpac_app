import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationFilter {
static const double ACCURACY_THRESHOLD = 50.0; // Increased from 30
static const double POOR_ACCURACY_THRESHOLD = 75.0; // Increased from 50
static const double DEGRADED_ACCURACY_THRESHOLD = 150.0; // Increased from 100

static const Map<String, double> MOVEMENT_THRESHOLDS = {
'STATIONARY': 10.0, // Keep checking for stationary
'WALKING': 0.1, // Essentially disabled
'RUNNING': 0.1, // Essentially disabled
'CYCLING': 0.1, // Essentially disabled
'DRIVING': 0.1, // Essentially disabled
'UNKNOWN': 0.1, // Essentially disabled
};

static const Map<String, double> MAX_REALISTIC_SPEEDS = {
'STATIONARY': 2.0, // Increased to handle GPS drift
'WALKING': 5.0, // Increased from 2.5
'RUNNING': 12.0, // Increased from 8.0
'CYCLING': 25.0, // Increased from 15.0
'DRIVING': 70.0, // Increased from 55.0
'UNKNOWN': 70.0, // Increased from 55.0
};

Position? _lastValidPosition;
DateTime? _lastValidTime;
final List<Position> _suspiciousPoints = [];
static const int MAX_SUSPICIOUS_POINTS = 3;

bool shouldAcceptLocation(Position position, String activityType) {
// 1. Basic accuracy check
if (position.accuracy > DEGRADED_ACCURACY_THRESHOLD) {
debugPrint('Rejecting: Too inaccurate (${position.accuracy}m)');
return false;
}

// 2. If no previous position, accept (first point)
if (_lastValidPosition == null || _lastValidTime == null) {
_updateLastValid(position);
return true;
}

// 3. Time check - reject if too close in time
final timeDelta = position.timestamp!.difference(_lastValidTime!);
if (timeDelta.inSeconds < 1) {
debugPrint('Rejecting: Too frequent (${timeDelta.inSeconds}s)');
return false;
}

// 4. Distance and speed checks
final distance = _calculateDistance(_lastValidPosition!, position);
final speed = distance / timeDelta.inSeconds; // m/s

// 5. Movement threshold check (only for stationary)
final movementThreshold = MOVEMENT_THRESHOLDS[activityType] ?? 0.1;
if (distance < movementThreshold && activityType == 'STATIONARY') {
debugPrint('Rejecting: Below movement threshold for $activityType (${distance}m)');
return false;
}

// 6. Speed check
final maxSpeed = MAX_REALISTIC_SPEEDS[activityType] ?? 70.0;
if (speed > maxSpeed) {
debugPrint('Rejecting: Speed too high (${speed}m/s for $activityType)');
_handleSuspiciousPoint(position);
return false;
}

// 7. Handle suspicious points buffer
if (_suspiciousPoints.isNotEmpty) {
_processSuspiciousPoints(position, activityType);
}

// 8. Accept the point
_updateLastValid(position);
return true;
}

void _handleSuspiciousPoint(Position position) {
_suspiciousPoints.add(position);

// Keep buffer manageable
if (_suspiciousPoints.length > MAX_SUSPICIOUS_POINTS) {
_suspiciousPoints.removeAt(0);
}
}

void _processSuspiciousPoints(Position currentPosition, String activityType) {
// Check if current position validates suspicious points
for (int i = _suspiciousPoints.length - 1; i >= 0; i--) {
final suspiciousPoint = _suspiciousPoints[i];
final distance = _calculateDistance(suspiciousPoint, currentPosition);
final timeDelta = currentPosition.timestamp!.difference(suspiciousPoint.timestamp!);

if (timeDelta.inSeconds > 0) {
final speed = distance / timeDelta.inSeconds;
final maxSpeed = MAX_REALISTIC_SPEEDS[activityType] ?? 70.0;

if (speed <= maxSpeed) {
// Suspicious point is now validated, we could process it
debugPrint('Validated suspicious point after ${timeDelta.inSeconds}s');
}
}
}

// Clear suspicious points buffer
_suspiciousPoints.clear();
}

double _calculateDistance(Position pos1, Position pos2) {
return Geolocator.distanceBetween(
pos1.latitude,
pos1.longitude,
pos2.latitude,
pos2.longitude,
);
}

void _updateLastValid(Position position) {
_lastValidPosition = position;
_lastValidTime = position.timestamp;
}

void reset() {
_lastValidPosition = null;
_lastValidTime = null;
_suspiciousPoints.clear();
}

LocationQuality getLocationQuality(Position position) {
if (position.accuracy <= ACCURACY_THRESHOLD) {
return LocationQuality.good;
} else if (position.accuracy <= POOR_ACCURACY_THRESHOLD) {
return LocationQuality.fair;
} else if (position.accuracy <= DEGRADED_ACCURACY_THRESHOLD) {
return LocationQuality.poor;
} else {
return LocationQuality.unusable;
}
}
}

enum LocationQuality { good, fair, poor, unusable }
