import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/geotagged_photo.dart';

class StorageService {
  static const String _photosFileName = 'geotagged_photos.json';

  /// Get app documents directory
  Future<Directory> getAppDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get photos directory
  Future<Directory> getPhotosDirectory() async {
    final appDir = await getAppDirectory();
    final photosDir = Directory(path.join(appDir.path, 'photos'));
    
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    
    return photosDir;
  }

  /// Save photo metadata
  Future<void> savePhotoMetadata(GeotaggedPhoto photo) async {
    try {
      final photos = await getAllPhotos();
      photos.add(photo);
      
      final appDir = await getAppDirectory();
      final metadataFile = File(path.join(appDir.path, _photosFileName));
      
      final jsonList = photos.map((p) => p.toJson()).toList();
      await metadataFile.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving photo metadata: $e');
      rethrow;
    }
  }

  /// Get all saved photos
  Future<List<GeotaggedPhoto>> getAllPhotos() async {
    try {
      final appDir = await getAppDirectory();
      final metadataFile = File(path.join(appDir.path, _photosFileName));
      
      if (!await metadataFile.exists()) {
        return [];
      }
      
      final jsonString = await metadataFile.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);
      
      return jsonList.map((json) => GeotaggedPhoto.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading photos: $e');
      return [];
    }
  }

  /// Delete a photo
  Future<void> deletePhoto(String photoId) async {
    try {
      final photos = await getAllPhotos();
      
      // Find photo safely
      final index = photos.indexWhere((p) => p.id == photoId);
      if (index == -1) {
        debugPrint('Photo with ID $photoId not found in metadata.');
        return;
      }
      
      final photoToDelete = photos[index];

      
      // Delete the image file
      final imageFile = File(photoToDelete.imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
      
      // Remove from metadata
      photos.removeWhere((p) => p.id == photoId);
      
      final appDir = await getAppDirectory();
      final metadataFile = File(path.join(appDir.path, _photosFileName));
      
      final jsonList = photos.map((p) => p.toJson()).toList();
      await metadataFile.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      rethrow;
    }
  }

  /// Copy file to app directory
  Future<File> copyToAppDirectory(File sourceFile, String fileName) async {
    try {
      final photosDir = await getPhotosDirectory();
      final newPath = path.join(photosDir.path, fileName);
      return await sourceFile.copy(newPath);
    } catch (e) {
      debugPrint('Error copying file: $e');
      rethrow;
    }
  }

  /// Get total number of photos
  Future<int> getPhotoCount() async {
    final photos = await getAllPhotos();
    return photos.length;
  }

  /// Clear all photos (for testing/debugging)
  Future<void> clearAllPhotos() async {
    try {
      final appDir = await getAppDirectory();
      final metadataFile = File(path.join(appDir.path, _photosFileName));
      
      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }
      
      final photosDir = await getPhotosDirectory();
      if (await photosDir.exists()) {
        await photosDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing photos: $e');
      rethrow;
    }
  }
}
