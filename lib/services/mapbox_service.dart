class MapboxService {
  static Future<Map<String, dynamic>?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    // TODO: Implement Mapbox reverse geocoding
    return {
      'place_name': 'Location at $latitude, $longitude',
'properties': {
'address': 'Unknown Address',
},
};
}

static Future<List<Map<String, dynamic>>> searchLocation(
String query,
) async {
// TODO: Implement Mapbox location search
return [];
}
}
