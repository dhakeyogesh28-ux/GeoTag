import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check and request location permissions
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }

  /// Get current GPS position
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return null;
      }

      // Check permissions
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        debugPrint('Location permission denied');
        return null;
      }

      // Try to get fresh, accurate position first
      debugPrint('Getting accurate GPS location...');
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation, // Highest precision
        ).timeout(

          const Duration(seconds: 10), // Longer timeout for better fix
          onTimeout: () async {
            debugPrint('Best accuracy timeout, trying high accuracy...');
            return await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            ).timeout(const Duration(seconds: 5));
          },
        );

        debugPrint('Accurate location acquired: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');
        return position;
      } catch (e) {
        debugPrint('Could not get fresh position: $e');
        
        // Fallback: Check if last known position is recent and accurate
        try {
          Position? lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            final age = DateTime.now().difference(lastPosition.timestamp);
            final isRecent = age.inMinutes < 5; // Less than 5 minutes old
            final isAccurate = lastPosition.accuracy < 50; // Better than 50 meters
            
            if (isRecent && isAccurate) {
              debugPrint('Using recent last known position: ${lastPosition.latitude}, ${lastPosition.longitude}, age: ${age.inSeconds}s, accuracy: ${lastPosition.accuracy}m');
              return lastPosition;
            } else {
              debugPrint('Last known position too old (${age.inMinutes}min) or inaccurate (${lastPosition.accuracy}m)');
            }
          }
        } catch (e2) {
          debugPrint('Could not get last known position: $e2');
        }
        
        // Final fallback: medium accuracy
        try {
          debugPrint('Trying medium accuracy as final fallback...');
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          ).timeout(const Duration(seconds: 5));
          debugPrint('Location acquired with medium accuracy: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');
          return position;
        } catch (e3) {
          debugPrint('Failed to get location: $e3');
          return null;
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Get address from coordinates (reverse geocoding)
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> addressParts = [];

        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && 
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        return addressParts.join(', ');
      }
      return null;
    } catch (e) {
      debugPrint('Error getting address: $e');
      return null;
    }
  }

  /// Get formatted coordinates string
  String formatCoordinates(double latitude, double longitude) {
    final latDirection = latitude >= 0 ? 'N' : 'S';
    final lonDirection = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(6)}°$latDirection, ${longitude.abs().toStringAsFixed(6)}°$lonDirection';
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation, // Highest precision
              distanceFilter: 0,
              forceLocationManager: false, // Use Fused provider for better multi-sensor accuracy
              intervalDuration: const Duration(seconds: 1),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 0,
            ),
    );
  }


}
