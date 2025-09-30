import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class KalmanLocationFilter {
static const double EARTH_RADIUS_M = 6371000;
static const double DEG_TO_RAD = math.pi / 180.0;
static const double RAD_TO_DEG = 180.0 / math.pi;

double _latitude = 0;
double _longitude = 0;
double _altitude = 0;
double _velocityNorth = 0;
double _velocityEast = 0;

double _latitudeVariance = 1000.0;
double _longitudeVariance = 1000.0;
double _altitudeVariance = 1000.0;
double _velocityNorthVariance = 1000.0;
double _velocityEastVariance = 1000.0;

DateTime? _lastTimestamp;
bool _isInitialized = false;

static const double MIN_ACCURACY = 1.0;

static const Map<String, double> PROCESS_NOISE_BY_MODE = {
'STATIONARY': 1.0,
'WALKING': 4.0,
'RUNNING': 8.0,
'CYCLING': 12.0,
'DRIVING': 20.0,
'UNKNOWN': 10.0,
};

void reset() {
_isInitialized = false;
_lastTimestamp = null;
_latitudeVariance = 1000.0;
_longitudeVariance = 1000.0;
_altitudeVariance = 1000.0;
_velocityNorthVariance = 1000.0;
_velocityEastVariance = 1000.0;
}

Position? processLocation(Position measurement, String activityMode) {
if (!_isInitialized) {
return _initialize(measurement);
}

final now = measurement.timestamp ?? DateTime.now();
final deltaTimeS = now.difference(_lastTimestamp!).inMilliseconds / 1000.0;

if (deltaTimeS <= 0) {
debugPrint('Kalman: Invalid time delta: $deltaTimeS');
return null;
}

// Prediction step
_predict(deltaTimeS, activityMode);

// Update step
_update(measurement);

_lastTimestamp = now;

// Create filtered position
return Position(
latitude: _latitude,
longitude: _longitude,
timestamp: now,
accuracy: math.sqrt(_latitudeVariance + _longitudeVariance) / 2,
altitude: _altitude,
altitudeAccuracy: 0.0,
heading: _calculateHeading(),
headingAccuracy: 0.0,
speed: _calculateSpeed(),
speedAccuracy: 0.0,
);
}

Position _initialize(Position measurement) {
_latitude = measurement.latitude;
_longitude = measurement.longitude;
_altitude = measurement.altitude ?? 0.0;
_velocityNorth = 0;
_velocityEast = 0;

final accuracy = math.max(measurement.accuracy, MIN_ACCURACY);
_latitudeVariance = accuracy * accuracy;
_longitudeVariance = accuracy * accuracy;
_altitudeVariance = accuracy * accuracy;
_velocityNorthVariance = 1.0;
_velocityEastVariance = 1.0;

_lastTimestamp = measurement.timestamp ?? DateTime.now();
_isInitialized = true;

debugPrint('Kalman: Initialized at (${_latitude}, ${_longitude})');

return Position(
latitude: _latitude,
longitude: _longitude,
timestamp: _lastTimestamp!,
accuracy: accuracy,
altitude: _altitude,
altitudeAccuracy: 0.0,
heading: 0.0,
headingAccuracy: 0.0,
speed: 0.0,
speedAccuracy: 0.0,
);
}

void _predict(double deltaTimeS, String activityMode) {
// State prediction
final latDelta = _velocityNorth * deltaTimeS / EARTH_RADIUS_M * RAD_TO_DEG;
final lonDelta = _velocityEast * deltaTimeS / (EARTH_RADIUS_M * math.cos(_latitude * DEG_TO_RAD)) * RAD_TO_DEG;

_latitude += latDelta;
_longitude += lonDelta;

// Covariance prediction
final processNoise = PROCESS_NOISE_BY_MODE[activityMode] ?? 10.0;
final timeSquared = deltaTimeS * deltaTimeS;

_latitudeVariance += processNoise * timeSquared;
_longitudeVariance += processNoise * timeSquared;
_altitudeVariance += processNoise * timeSquared;
_velocityNorthVariance += processNoise;
_velocityEastVariance += processNoise;
}

void _update(Position measurement) {
final accuracy = math.max(measurement.accuracy, MIN_ACCURACY);
final measurementVariance = accuracy * accuracy;

// Kalman gain calculations
final latGain = _latitudeVariance / (_latitudeVariance + measurementVariance);
final lonGain = _longitudeVariance / (_longitudeVariance + measurementVariance);
final altGain = _altitudeVariance / (_altitudeVariance + measurementVariance);

// State updates
final latInnovation = measurement.latitude - _latitude;
final lonInnovation = measurement.longitude - _longitude;
final altInnovation = (measurement.altitude ?? _altitude) - _altitude;

_latitude += latGain * latInnovation;
_longitude += lonGain * lonInnovation;
_altitude += altGain * altInnovation;

// Velocity updates (simple finite difference)
if (_lastTimestamp != null) {
final deltaTimeS = (measurement.timestamp ?? DateTime.now())
.difference(_lastTimestamp!)
.inMilliseconds / 1000.0;

if (deltaTimeS > 0) {
final latDeltaM = latInnovation * EARTH_RADIUS_M * DEG_TO_RAD;
final lonDeltaM = lonInnovation * EARTH_RADIUS_M * math.cos(_latitude * DEG_TO_RAD) * DEG_TO_RAD;

final newVelNorth = latDeltaM / deltaTimeS;
final newVelEast = lonDeltaM / deltaTimeS;

// Smooth velocity updates
_velocityNorth = _velocityNorth * 0.7 + newVelNorth * 0.3;
_velocityEast = _velocityEast * 0.7 + newVelEast * 0.3;
}
}

// Covariance updates
_latitudeVariance *= (1 - latGain);
_longitudeVariance *= (1 - lonGain);
_altitudeVariance *= (1 - altGain);

// Prevent variance from getting too small
_latitudeVariance = math.max(_latitudeVariance, 0.01);
_longitudeVariance = math.max(_longitudeVariance, 0.01);
_altitudeVariance = math.max(_altitudeVariance, 0.01);
}

double _calculateHeading() {
if (_velocityNorth == 0 && _velocityEast == 0) {
return 0.0;
}

final heading = math.atan2(_velocityEast, _velocityNorth) * RAD_TO_DEG;
return heading < 0 ? heading + 360 : heading;
}

double _calculateSpeed() {
return math.sqrt(_velocityNorth * _velocityNorth + _velocityEast * _velocityEast);
}

bool get isInitialized => _isInitialized;
double get currentLatitude => _latitude;
double get currentLongitude => _longitude;
double get currentSpeed => _calculateSpeed();
}
