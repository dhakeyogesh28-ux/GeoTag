import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/geotagged_photo.dart';
import 'photo_detail_screen.dart';


class MapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final List<GeotaggedPhoto> photos;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.photos,
  });


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(latitude, longitude),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                userAgentPackageName: 'com.geotagging.geotagging_camera',
              ),
              MarkerLayer(
                markers: [
                  // Current location marker
                  Marker(
                    point: LatLng(latitude, longitude),
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                  // Gallery photo markers
                  ...photos.map((photo) {
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
                          );
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
                                  const Icon(Icons.photo, color: Colors.blue),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),

            ],
          ),
          
          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),


          // Attribution (Required for Esri/OSM)
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: Colors.black.withOpacity(0.5),
              child: const Text(
                '© Google',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
