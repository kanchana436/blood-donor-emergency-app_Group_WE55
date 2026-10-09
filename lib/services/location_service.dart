import 'dart:math';

class UserLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String city;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Default initial location: Colombo Central
  UserLocation _currentLocation = UserLocation(
    latitude: 6.9271,
    longitude: 79.8612,
    address: 'Galle Face, Colombo 03',
    city: 'Colombo',
  );

  UserLocation get currentLocation => _currentLocation;

  void setCustomLocation(UserLocation location) {
    _currentLocation = location;
  }

  /// Calculates distance in kilometers between two lat/long points using Haversine formula
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  // Pre-configured hospitals list with coordinates for quick selection
  static final List<Map<String, dynamic>> recognizedHospitals = [
    {
      'name': 'National Hospital of Sri Lanka',
      'city': 'Colombo',
      'address': 'Regent Street, Colombo 10',
      'lat': 6.9202,
      'lng': 79.8687,
    },
    {
      'name': 'Asiri Central Hospital',
      'city': 'Colombo',
      'address': 'Norris Canal Rd, Colombo 10',
      'lat': 6.9240,
      'lng': 79.8655,
    },
    {
      'name': 'Lanka Hospitals',
      'city': 'Colombo',
      'address': 'Elvitigala Mawatha, Colombo 05',
      'lat': 6.8969,
      'lng': 79.8804,
    },
    {
      'name': 'Teaching Hospital Kandy',
      'city': 'Kandy',
      'address': 'William Gopallawa Mawatha, Kandy',
      'lat': 7.2882,
      'lng': 80.6277,
    },
    {
      'name': 'Karapitiya Teaching Hospital',
      'city': 'Galle',
      'address': 'Karapitiya, Galle',
      'lat': 6.0645,
      'lng': 80.2248,
    },
  ];
}
