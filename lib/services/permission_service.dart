import 'package:geolocator/geolocator.dart';

class PermissionService {
static Future<bool> requestLocationPermissions() async {
LocationPermission permission = await Geolocator.checkPermission();

if (permission == LocationPermission.denied) {
permission = await Geolocator.requestPermission();
}

return permission == LocationPermission.whileInUse ||
permission == LocationPermission.always;
}

static Future<LocationPermission> getLocationPermissionStatus() async {
return await Geolocator.checkPermission();
}
}
