import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';


import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/geotagged_photo.dart';
import '../services/storage_service.dart';
import 'photo_detail_screen.dart';


class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final StorageService _storageService = StorageService();
  List<GeotaggedPhoto> _photos = [];
  bool _isLoading = true;
  bool _isMapView = false; // Add this


  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final photos = await _storageService.getAllPhotos();
      setState(() {
        _photos = photos.reversed.toList(); // Show newest first
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading photos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        title: const Text(
          'Gallery',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.grid_view_rounded : Icons.map_rounded),
            onPressed: () => setState(() => _isMapView = !_isMapView),
            tooltip: _isMapView ? 'Show Grid' : 'Show Map',
            color: Colors.white,
          ),
          if (_photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${_photos.length}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? _buildEmptyState()
              : _isMapView
                  ? _buildMapView()
                  : _buildPhotoGrid(),
    );
  }

  Widget _buildMapView() {
    if (_photos.isEmpty) return _buildEmptyState();

    // Find center of all photos or focus on latest
    final double initialLat = _photos.first.latitude;
    final double initialLng = _photos.first.longitude;

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(initialLat, initialLng),
        initialZoom: 14.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
          subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
          userAgentPackageName: 'com.geotagging.geotagging_camera',
        ),
        MarkerLayer(
          markers: _photos.map((photo) {
            return Marker(
              point: LatLng(photo.latitude, photo.longitude),
              width: 60,
              height: 60,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhotoDetailScreen(photo: photo),
                    ),
                  ).then((result) {
                    if (result == true) _loadPhotos();
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.file(
                      File(photo.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.location_on, color: Colors.red),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }



  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No photos yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture your first geotagged photo!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;
    return GridView.builder(
      padding: EdgeInsets.only(
        top: topPadding + 8,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(

        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return _buildPhotoGridItem(photo);
      },
    );
  }

  Widget _buildPhotoGridItem(GeotaggedPhoto photo) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoDetailScreen(photo: photo),
          ),
        );

        // Reload if photo was deleted
        if (result == true) {
          _loadPhotos();
        }
      },
      child: Hero(
        tag: 'photo_${photo.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(photo.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[900],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,

                        size: 40,
                      ),
                    );
                  },
                ),
                // Gradient overlay for better text visibility
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      photo.formattedTimestamp,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
