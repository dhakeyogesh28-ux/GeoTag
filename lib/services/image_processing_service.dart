import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';

class ImageProcessingService {
  /// Process image and add geotag overlay matching GPS Map Camera style
  Future<File> addGeotagToImage({
    required String imagePath,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String? address,
    double? altitude,
    double? accuracy,
    img.Image? preloadedMapThumbnail,
  }) async {
    try {
      // Read the image file
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      
      // Decode the image
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Get map thumbnail (use preloaded if available, otherwise fetch)
      img.Image? mapThumbnail = preloadedMapThumbnail ?? await getMapThumbnail(latitude, longitude);

      // Create overlay
      final processedImage = await _createGeotagOverlay(
        originalImage,
        latitude,
        longitude,
        timestamp,
        address: address,
        altitude: altitude,
        accuracy: accuracy,
        mapThumbnail: mapThumbnail,
      );


      // Save processed image
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'geotagged_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputPath = path.join(directory.path, fileName);
      
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodeJpg(processedImage, quality: 95));

      // Save to device gallery
      await _saveToGallery(outputPath);

      return outputFile;
    } catch (e) {
      debugPrint('Error processing image: $e');
      rethrow;
    }
  }

  /// Get map thumbnail from Esri World Imagery (Satellite)
  Future<img.Image?> getMapThumbnail(double lat, double lon) async {
    try {
      // Calculate tile coordinates for zoom level 18 (more zoomed in)
      const zoom = 18;
      final x = ((lon + 180) / 360 * (1 << zoom)).floor();
      
      final latRad = lat * math.pi / 180;
      final y = ((1 - (math.log(math.tan(latRad) + 1 / math.cos(latRad))) / math.pi) / 2 * (1 << zoom)).floor();
      
      // Fetch map tile from Google Satellite (Hybrid)
      // Using a more robust URL with subdomain rotation and standard lyrs
      final subdomains = ['mt0', 'mt1', 'mt2', 'mt3'];
      final s = subdomains[math.Random().nextInt(subdomains.length)];
      final url = 'https://$s.google.com/vt/lyrs=y&x=$x&y=$y&z=$zoom';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'GeotaggingCameraApp/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final mapImage = img.decodeImage(response.bodyBytes);
        if (mapImage != null) {
          // Resize to thumbnail size (150x150)
          return img.copyResize(mapImage, width: 150, height: 150);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching map thumbnail: $e');
      return null;
    }
  }

  /// Create geotag overlay matching GPS Map Camera style
  Future<img.Image> _createGeotagOverlay(
    img.Image originalImage,
    double latitude,
    double longitude,
    DateTime timestamp, {
    String? address,
    double? altitude,
    double? accuracy,
    img.Image? mapThumbnail,
  }) async {

    // Calculate overlay dimensions
    final imageWidth = originalImage.width;
    final imageHeight = originalImage.height;
    
    // Main Container Dimensions
    final padding = 30; // Margin from screen edges
    final containerHeight = 240;
    final containerWidth = imageWidth - (padding * 2);
    final containerX = padding;
    final containerY = imageHeight - containerHeight - padding;

    // Draw Main Container (Rounded Rectangle)
    _drawRoundedRect(
      originalImage,
      x1: containerX,
      y1: containerY,
      x2: containerX + containerWidth,
      y2: containerY + containerHeight,
      color: img.ColorRgba8(0, 0, 0, 160),
      radius: 25,
    );

    // Map Configuration
    final mapSize = 200; // Slightly smaller than container height
    final mapMargin = 20;
    final mapX = containerX + mapMargin;
    final mapY = containerY + mapMargin;

    // Draw Map
    if (mapThumbnail != null) {
      // Resize map to fit
      final resizedMap = img.copyResize(mapThumbnail, width: mapSize, height: mapSize);
      
      // Draw map background (for rounded/border effect if needed)
      // Since we can't clip easily, we just draw it over
      originalImage = img.compositeImage(
        originalImage,
        resizedMap,
        dstX: mapX,
        dstY: mapY,
      );

      // Draw location pin
      final pinX = mapX + mapSize ~/ 2;
      final pinY = mapY + mapSize ~/ 2;
      
      // Pin shadow/outer ring
      originalImage = img.fillCircle(
        originalImage,
        x: pinX,
        y: pinY,
        radius: 8,
        color: img.ColorRgba8(255, 0, 0, 255), // Red
      );
      // Pin inner dot
      originalImage = img.fillCircle(
        originalImage,
        x: pinX,
        y: pinY,
        radius: 4,
        color: img.ColorRgba8(255, 255, 255, 255), // White
      );
      
      // Fake "Apple Maps" logo text bottom left of map
      originalImage = _drawText(
        originalImage,
        " Maps",
        mapX + 8,
        mapY + mapSize - 20,
        fontSize: 14,
        color: img.ColorRgba8(255, 255, 255, 220),
      );
    }

    // Text Configuration
    final textX = mapX + mapSize + 20; // Right of map, closer
    int textY = containerY + 15; // Start higher
    final lineSpacing = 28; // Spacing for 24px font
    
    // Prepare Data
    final locationName = _getLocationName(address);
    final flag = address?.contains('India') == true ? " 🇮🇳" : "";
    final coordText = 'Lat ${latitude.toStringAsFixed(6)}, Long ${longitude.toStringAsFixed(6)}';
    final dateText = DateFormat('EEEE, dd/MM/yyyy hh:mm a').format(timestamp) + ' GMT+05:30';

    // 1. Location Name (Header) - with wrapping
    if (locationName.isNotEmpty) {
      final headerText = "$locationName$flag";
      final maxTextWidth = (containerX + containerWidth) - textX - 20;
      final approxCharWidth = 14; // For bold 24px font (wider due to bold)
      final maxCharsPerLine = maxTextWidth ~/ approxCharWidth;
      
      if (headerText.length > maxCharsPerLine) {
        // Wrap header if too long
        final headerLines = _wrapText(headerText, maxCharsPerLine);
        for (var line in headerLines) {
          originalImage = _drawText(
            originalImage,
            line,
            textX,
            textY,
            fontSize: 24, // Smaller to fit better
            bold: true,
            color: img.ColorRgba8(255, 255, 255, 255),
          );
          textY += 28; // Line spacing for wrapped header
        }
        textY += 0; // No extra space after header
      } else {
        originalImage = _drawText(
          originalImage,
          headerText,
          textX,
          textY,
          fontSize: 24, // Smaller to fit better
          bold: true,
          color: img.ColorRgba8(255, 255, 255, 255),
        );
        textY += 28; // Standard line spacing
      }
    }

    // 2. Address - Multi-line with intelligent wrapping
    if (address != null && address.isNotEmpty) {
      // Calculate max width for text
      final maxTextWidth = (containerX + containerWidth) - textX - 20;
      final approxCharWidth = 12; // Approximate width for 24px font
      final maxCharsPerLine = maxTextWidth ~/ approxCharWidth;
      
      String displayAddress = address;
      if (displayAddress.length > maxCharsPerLine * 2) {
         displayAddress = displayAddress.substring(0, (maxCharsPerLine * 2) - 3) + "...";
      }
      
      // Simple manual wrapping for 2 lines max
      List<String> addressLines = [];
      if (displayAddress.length > maxCharsPerLine) {
         int splitIndex = displayAddress.lastIndexOf(' ', maxCharsPerLine);
         if (splitIndex == -1) splitIndex = maxCharsPerLine;
         addressLines.add(displayAddress.substring(0, splitIndex));
         addressLines.add(displayAddress.substring(splitIndex).trim());
      } else {
         addressLines.add(displayAddress);
      }
      
      for (var line in addressLines) {
        originalImage = _drawText(
          originalImage,
          line,
          textX,
          textY,
          fontSize: 24, // Larger readable text
          color: img.ColorRgba8(230, 230, 230, 255),
        );
        textY += 26; // Spacing for 24px font
      }
      // Add extra spacing after address block
      textY += 2;
    }

    // 3. Coordinates - with wrapping
    final maxTextWidth = (containerX + containerWidth) - textX - 20;
    final approxCharWidth = 12; // For 24px font
    final maxCharsPerLine = maxTextWidth ~/ approxCharWidth;
    
    if (coordText.length > maxCharsPerLine) {
      // Wrap coordinates if too long
      final coordLines = _wrapText(coordText, maxCharsPerLine);
      for (var line in coordLines) {
        originalImage = _drawText(
          originalImage,
          line,
          textX,
          textY,
          fontSize: 24,
          color: img.ColorRgba8(230, 230, 230, 255),
        );
        textY += 26;
      }
    } else {
      originalImage = _drawText(
        originalImage,
        coordText,
        textX,
        textY,
        fontSize: 24,
        color: img.ColorRgba8(230, 230, 230, 255),
      );
      textY += lineSpacing;
    }

    // 4. Date/Time - with wrapping
    if (dateText.length > maxCharsPerLine) {
      final dateLines = _wrapText(dateText, maxCharsPerLine);
      for (var line in dateLines) {
        originalImage = _drawText(
          originalImage,
          line,
          textX,
          textY,
          fontSize: 24,
          color: img.ColorRgba8(230, 230, 230, 255),
        );
        textY += 26;
      }
    } else {
      originalImage = _drawText(
        originalImage,
        dateText,
        textX,
        textY,
        fontSize: 24,
        color: img.ColorRgba8(230, 230, 230, 255),
      );
      textY += lineSpacing;
    }

    // 5. Altitude/Accuracy
    String altAccText = '';
    if (altitude != null) altAccText += 'Alt ${altitude.toStringAsFixed(1)}m';
    if (accuracy != null) {
      if (altAccText.isNotEmpty) altAccText += ', ';
      altAccText += 'Acc ${accuracy.toStringAsFixed(1)}m';
    }
    
    if (altAccText.isNotEmpty) {
      originalImage = _drawText(
        originalImage,
        altAccText,
        textX,
        textY,
        fontSize: 24,
        color: img.ColorRgba8(230, 230, 230, 255),
      );
      textY += lineSpacing;
    }



    // Branding Badge - Floating ABOVE container
    final badgeText = "Captured by Dr. Rajesh Dhake";
    final badgeWidth = 380; // Wider to fit longer text
    final badgeHeight = 44;
    final badgeX = containerX + containerWidth - badgeWidth; // Right aligned with container
    final badgeY = containerY - badgeHeight - 15; // Above container
    
    // Badge Background (Darker Grey/Black, rounded)
    _drawRoundedRect(
      originalImage,
      x1: badgeX,
      y1: badgeY,
      x2: badgeX + badgeWidth,
      y2: badgeY + badgeHeight,
      color: img.ColorRgba8(40, 40, 40, 255), // Opaque dark grey
      radius: 22,
    );

    // Badge Icon (Simplistic "Map" icon)
    // Blue square with yellow circle inside
    final iconSize = 24;
    final iconX = badgeX + 15;
    final iconY = badgeY + 10;
    
    // Blue box
    _drawRoundedRect(
      originalImage,
      x1: iconX,
      y1: iconY,
      x2: iconX + iconSize,
      y2: iconY + iconSize,
      color: img.ColorRgba8(0, 122, 255, 255),
      radius: 4,
    );
    // Yellow ring (simulated thickness by drawing multiple circles)
    originalImage = img.drawCircle(
      originalImage,
      x: iconX + iconSize ~/ 2,
      y: iconY + iconSize ~/ 2,
      radius: 6,
      color: img.ColorRgba8(255, 213, 0, 255),
    );
    originalImage = img.drawCircle(
      originalImage,
      x: iconX + iconSize ~/ 2,
      y: iconY + iconSize ~/ 2,
      radius: 7, // Thicker
      color: img.ColorRgba8(255, 213, 0, 255),
    );

    // Green dot
    originalImage = img.fillCircle(
      originalImage,
      x: iconX + iconSize ~/ 2,
      y: iconY + iconSize ~/ 2,
      radius: 3,
      color: img.ColorRgba8(50, 205, 50, 255),
    );

    // Badge Text - larger font for better visibility
    originalImage = _drawText(
      originalImage,
      badgeText,
      iconX + iconSize + 10,
      iconY + 4, // Centered vertically in badge
      fontSize: 24, // Larger for better readability
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    return originalImage;
  }

  /// Helper to draw rounded rectangle using circles and rects
  void _drawRoundedRect(
    img.Image image, {
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required img.Color color,
    required int radius,
  }) {
    // Draw 4 corner circles
    img.fillCircle(image, x: x1 + radius, y: y1 + radius, radius: radius, color: color); // Top-left
    img.fillCircle(image, x: x2 - radius - 1, y: y1 + radius, radius: radius, color: color); // Top-right
    img.fillCircle(image, x: x1 + radius, y: y2 - radius - 1, radius: radius, color: color); // Bottom-left
    img.fillCircle(image, x: x2 - radius - 1, y: y2 - radius - 1, radius: radius, color: color); // Bottom-right
    
    // Draw central rects
    img.fillRect(image, x1: x1 + radius, y1: y1, x2: x2 - radius, y2: y2, color: color); // Horizontal main
    img.fillRect(image, x1: x1, y1: y1 + radius, x2: x2, y2: y2 - radius, color: color); // Vertical main
  }

  /// Extract location name from address
  String _getLocationName(String? address) {
    if (address == null || address.isEmpty) return '';
    
    // Try to get city/locality from address
    final parts = address.split(',');
    if (parts.length >= 2) {
      // Return first 2-3 parts as location name
      return parts.take(2).join(',').trim();
    }
    return address;
  }

  /// Wrap text into multiple lines based on max characters per line
  List<String> _wrapText(String text, int maxCharsPerLine) {
    if (text.length <= maxCharsPerLine) {
      return [text];
    }
    
    List<String> lines = [];
    String remaining = text;
    
    while (remaining.length > maxCharsPerLine) {
      // Try to break at a space
      int breakPoint = remaining.lastIndexOf(' ', maxCharsPerLine);
      if (breakPoint == -1 || breakPoint < maxCharsPerLine ~/ 2) {
        // No good break point, just break at max
        breakPoint = maxCharsPerLine;
      }
      
      lines.add(remaining.substring(0, breakPoint).trim());
      remaining = remaining.substring(breakPoint).trim();
    }
    
    if (remaining.isNotEmpty) {
      lines.add(remaining);
    }
    
    return lines;
  }

  /// Draw text on image
  img.Image _drawText(
    img.Image image,
    String text,
    int x,
    int y, {
    int fontSize = 14,
    bool bold = false,
    img.Color? color,
  }) {
    // Select appropriate font based on size
    // The image package has fixed-size fonts: arial14, arial24, arial48
    img.BitmapFont font;
    if (fontSize <= 14) {
      font = img.arial14;
    } else if (fontSize <= 24) {
      font = img.arial24;
    } else {
      font = img.arial48;
    }
    
    final textColor = color ?? img.ColorRgba8(255, 255, 255, 255);
    
    // Draw text once normally
    img.Image result = img.drawString(
      image,
      text,
      font: font,
      x: x,
      y: y,
      color: textColor,
    );
    
    // If bold, draw again with slight offsets to simulate bold
    if (bold) {
      result = img.drawString(
        result,
        text,
        font: font,
        x: x + 1,
        y: y,
        color: textColor,
      );
      result = img.drawString(
        result,
        text,
        font: font,
        x: x,
        y: y + 1,
        color: textColor,
      );
      result = img.drawString(
        result,
        text,
        font: font,
        x: x + 1,
        y: y + 1,
        color: textColor,
      );
    }
    
    return result;
  }

  /// Save image to device gallery
  Future<void> _saveToGallery(String imagePath) async {
    try {
      await Gal.putImage(imagePath, album: 'Geotagging Camera');
      debugPrint('Image saved to gallery successfully');
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
    }
  }

  /// Create thumbnail from image
  Future<File> createThumbnail(String imagePath, {int size = 300}) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Create thumbnail
      img.Image thumbnail = img.copyResize(
        originalImage,
        width: size,
        height: size,
        maintainAspect: true,
      );

      // Save thumbnail
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'thumb_${path.basename(imagePath)}';
      final outputPath = path.join(directory.path, 'thumbnails', fileName);
      
      // Create thumbnails directory if it doesn't exist
      final thumbDir = Directory(path.dirname(outputPath));
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 85));

      return outputFile;
    } catch (e) {
      debugPrint('Error creating thumbnail: $e');
      rethrow;
    }
  }
}
