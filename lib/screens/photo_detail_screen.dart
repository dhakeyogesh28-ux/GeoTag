import 'dart:io';
import 'package:flutter/material.dart';
import '../models/geotagged_photo.dart';
import '../services/storage_service.dart';

class PhotoDetailScreen extends StatelessWidget {
  final GeotaggedPhoto photo;

  const PhotoDetailScreen({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Photo Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),

      body: Column(
        children: [
          // Photo viewer
          Expanded(
            child: Center(
              child: Hero(
                tag: 'photo_${photo.id}',
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.file(
                    File(photo.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Photo info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow(
                    Icons.location_on_rounded,
                    'Coordinates',
                    photo.formattedCoordinates,
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildInfoRow(
                    Icons.access_time_rounded,
                    'Timestamp',
                    photo.formattedTimestamp,
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  if (photo.address != null) ...[
                    _buildInfoRow(
                      Icons.place_rounded,
                      'Address',
                      photo.address!,
                    ),
                    const Divider(color: Colors.white10, height: 24),
                  ],
                  Row(
                    children: [
                      if (photo.altitude != null)
                        Expanded(
                          child: _buildInfoRow(
                            Icons.terrain_rounded,
                            'Altitude',
                            '${photo.altitude!.toStringAsFixed(1)} m',
                          ),
                        ),
                      if (photo.accuracy != null)
                        Expanded(
                          child: _buildInfoRow(
                            Icons.my_location_rounded,
                            'Accuracy',
                            '±${photo.accuracy!.toStringAsFixed(1)} m',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _deletePhoto(context);
    }
  }

  Future<void> _deletePhoto(BuildContext context) async {
    try {
      final storageService = StorageService();
      await storageService.deletePhoto(photo.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo deleted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
