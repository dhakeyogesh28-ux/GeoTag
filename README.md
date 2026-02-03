# Geotagging Camera App

A Flutter application that captures photos with GPS location data and displays geotags (coordinates, timestamp, address) overlaid on the images.

## Features

- 📷 **Real-time Camera Preview** - Live camera feed with instant capture
- 📍 **GPS Location Tracking** - Automatic coordinate tracking with high accuracy
- 🏷️ **Automatic Geotag Overlay** - Coordinates, timestamp, and address on photos
- 🖼️ **Photo Gallery** - Grid view of all captured geotagged photos
- 🔍 **Photo Detail View** - Pinch-to-zoom with detailed metadata
- 💾 **Persistent Storage** - Photos and metadata saved locally
- 🌓 **Dark Mode Support** - Automatic theme switching

## Screenshots

The app displays:
- Current GPS coordinates in real-time
- Address (via reverse geocoding)
- GPS accuracy indicator
- Altitude and heading information
- Professional geotag overlay on captured photos

## Requirements

- Flutter SDK 3.10.4 or higher
- **Physical device required** (camera and GPS don't work on emulators)
- Android 5.0+ or iOS 12.0+

## Installation

1. Clone or navigate to the project:
```bash
cd Y:\geotagging
```

2. Install dependencies:
```bash
flutter pub get
```

3. Connect your physical device via USB

4. Run the app:
```bash
flutter run
```

## Permissions

The app will request:
- **Camera** - To capture photos
- **Location** - To add GPS coordinates to photos
- **Storage** - To save photos (Android only)

## Usage

1. **Launch the app** - Camera preview appears with GPS coordinates
2. **Wait for GPS fix** - Coordinates will appear at the top (may take 10-30 seconds)
3. **Tap capture button** - Large circular button at bottom center
4. **View in gallery** - Tap gallery icon to see all captured photos
5. **View details** - Tap any photo to see full-size with metadata
6. **Delete photos** - Tap delete icon in photo detail view

## Building for Release

### Android APK
```bash
flutter build apk --release
```

### iOS (requires macOS)
```bash
flutter build ios --release
```

## Project Structure

```
lib/
├── models/          # Data models
├── services/        # Business logic (location, image, storage)
├── screens/         # UI screens (camera, gallery, detail)
└── main.dart        # App entry point
```

## Dependencies

- `camera` - Camera functionality
- `geolocator` - GPS location services
- `geocoding` - Reverse geocoding (coordinates to address)
- `image` - Image processing and overlay
- `path_provider` - Storage paths
- `intl` - Date/time formatting

## Troubleshooting

**GPS not working?**
- Enable location services on your device
- Go outdoors for better GPS signal
- Wait 30-60 seconds for initial GPS fix

**Camera not working?**
- Grant camera permission when prompted
- Restart the app if camera fails to initialize

**Address not showing?**
- Requires internet connection
- May not be available in all locations

## License
# Geotagging Camera Guide

This guide provides an overview of the key features and screens in the Geotagging Camera application.

## 1. Camera View

The Camera View is the main interface of the application. It provides real-time location data overlaid on the camera preview.

**Key Features:**
*   **Live Coordinates:** Displays current Latitude and Longitude at the top.
*   **Address Information:** Shows the reverse-geocoded address of your current location.
*   **Accuracy:** Indicates the GPS accuracy radius.
*   **Capture Button:** Large central button to take the photo.
*   **Gallery Access:** Button to quickly access stored photos.

![Camera Preview](assets/screenshots/camera_preview.jpg)

---

## 2. Gallery View

The Gallery View allows you to browse all the photos you have captured with the app.

**Key Features:**
*   **Grid Layout:** View your photos in an easy-to-navigate grid.
*   **Timestamps:** See when each photo was taken.
*   **Selection:** Tap on any photo to view it in full screen with detailed metadata.

![Gallery View](assets/screenshots/gallery_view.png)

## 3. Map View

The Map View provides a global perspective of your captured data using high-resolution satellite imagery.

**Key Features:**
*   **Geotagged Photo Markers:** See exactly where every photo was taken with high-precision map markers.
*   **Satellite Hybrid Map:** Toggle between different map layers with professional satellite detail.
*   **Interactive Thumbnails:** Tap on photo markers to view instant previews and jump to full photo details.
*   **Real-Time Tracking:** See your current location relative to your captured photo collection.


<!-- Image placeholder for Map View - User will add later -->
![Map View Overview](assets/screenshots/map_view.png)

---

## 4. Geotagged Image

When you view a photo or export it, the app overlays a professional geotag onto the image itself.

**Key Features:**
*   **Map Thumbnail:** A visual representation of the location on a map.
*   **Detailed Metadata:** Includes Coordinates, Timestamp, Address, Altitude, and Accuracy.
*   **Watermark:** Ensures the location data is permanently attached to the visual record.

This project is created for educational purposes.

## Author

Created with Flutter ❤️
