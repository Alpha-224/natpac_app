import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

class ActivityRecognitionService extends ChangeNotifier {
  static ActivityRecognitionService? _instance;
  ActivityRecognitionService._();
  static ActivityRecognitionService get instance {
    _instance ??= ActivityRecognitionService._();
    return _instance!;
  }

  final FlutterActivityRecognition _activityRecognition =
      FlutterActivityRecognition.instance;
  StreamSubscription<Activity>? _activityStreamSubscription;
  ActivityType? _currentActivity;
  ActivityConfidence? _currentConfidence;
  String _currentTransportMode = 'UNKNOWN';
  bool _isTracking = false;

  // Confidence threshold (50% for faster transitions)
  static const int confidenceThreshold = 50;

  ActivityType? get currentActivity => _currentActivity;
  ActivityConfidence? get currentConfidence => _currentConfidence;
  String get currentTransportMode => _currentTransportMode;
  bool get isTracking => _isTracking;

  Future<bool> requestPermissions() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('Activity Recognition permission denied');
      return;
    }

    try {
      _activityStreamSubscription = _activityRecognition.activityStream
          .listen(_onActivityChanged, onError: _onError);

      _isTracking = true;
      debugPrint('Activity Recognition started');
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting activity recognition: $e');
    }
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    await _activityStreamSubscription?.cancel();
    _activityStreamSubscription = null;
    _isTracking = false;

    debugPrint('Activity Recognition stopped');
    notifyListeners();
  }

  void _onActivityChanged(Activity activity) {
    _currentActivity = activity.type;
    _currentConfidence = activity.confidence;

    // Get confidence as percentage (different API approach)
    final confidencePercent = _getConfidencePercent(_currentConfidence!);

    // Only update transport mode if confidence is high enough
    if (confidencePercent >= confidenceThreshold) {
      final newTransportMode = _mapActivityToTransportMode(activity.type);

      if (newTransportMode != _currentTransportMode) {
        final oldMode = _currentTransportMode;
        _currentTransportMode = newTransportMode;

        debugPrint(
            'Transport mode changed: $oldMode -> $newTransportMode (confidence: $confidencePercent%)');
      }
    }

    notifyListeners();
  }

  void _onError(dynamic error) {
    debugPrint('Activity Recognition error: $error');
  }

  String _mapActivityToTransportMode(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.STILL:
        return 'STATIONARY';
      case ActivityType.WALKING:
        return 'WALKING';
      case ActivityType.RUNNING:
        return 'RUNNING';
      case ActivityType.IN_VEHICLE:
        return 'DRIVING'; // Could be bus, car, etc.
      case ActivityType.ON_BICYCLE:
        return 'CYCLING';
      case ActivityType.UNKNOWN:
      default:
        return 'UNKNOWN';
    }
  }

  // Manual transport mode override (for user selection)
  void setManualTransportMode(String mode) {
    if (_currentTransportMode != mode) {
      final oldMode = _currentTransportMode;
      _currentTransportMode = mode;
      debugPrint('Manual transport mode change: $oldMode -> $mode');
      notifyListeners();
    }
  }

  // Get confidence percentage - FIXED API
  int getConfidencePercentage() {
    return _getConfidencePercent(_currentConfidence ?? ActivityConfidence.LOW);
  }

  // Helper method to convert ActivityConfidence enum to percentage
  int _getConfidencePercent(ActivityConfidence confidence) {
    switch (confidence) {
      case ActivityConfidence.LOW:
        return 25;
      case ActivityConfidence.MEDIUM:
        return 50;
      case ActivityConfidence.HIGH:
        return 75;
      default:
        return 0;
    }
  }

  // Check if current detection is reliable
  bool isDetectionReliable() {
    return getConfidencePercentage() >= confidenceThreshold;
  }

  // Get activity display string - REMOVED TILTING
  String getActivityDisplayString() {
    if (_currentActivity == null) return 'Unknown';

    switch (_currentActivity!) {
      case ActivityType.STILL:
        return 'Still';
      case ActivityType.WALKING:
        return 'Walking';
      case ActivityType.RUNNING:
        return 'Running';
      case ActivityType.IN_VEHICLE:
        return 'In Vehicle';
      case ActivityType.ON_BICYCLE:
        return 'Cycling';
      case ActivityType.UNKNOWN:
      default:
        return 'Unknown';
    }
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
