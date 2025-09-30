class OSMService {
  static Future<Map<String, dynamic>?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    // TODO: Implement OpenStreetMap reverse geocoding
    return {
      'display_name': 'Location at $latitude, $longitude',
'address': {
'city': 'Unknown City',
'country': 'Unknown Country',
},
};
}

static Future<List<Map<String, dynamic>>> searchLocation(
String query,
) async {
// TODO: Implement OpenStreetMap location search
return [];
}
}
