import 'dart:io';
import 'dart:async'; // Add this
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import '../services/location_service.dart';
import 'map_screen.dart';
import '../services/image_processing_service.dart';
import '../services/storage_service.dart';
import '../models/geotagged_photo.dart';
import 'gallery_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  final LocationService _locationService = LocationService();
  final ImageProcessingService _imageService = ImageProcessingService();
  final StorageService _storageService = StorageService();

  StreamSubscription<Position>? _positionSubscription; // Add this


  Position? _currentPosition;
  String? _currentAddress;
  img.Image? _cachedMapThumbnail; // Add cached thumbnail
  DateTime? _lastMapUpdate; // Debounce map updates
  
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _isLoadingLocation = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _startLocationTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    final CameraController? cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Free up memory when camera not active
      if (_cameraController != null) {
        _cameraController!.dispose();
        _cameraController = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Re-initialize camera
      _onNewCameraSelected(cameraController.description);
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _cameraController = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) setState(() {});
      if (cameraController.value.hasError) {
        setState(() {
          _errorMessage = 'Camera error: ${cameraController.value.errorDescription}';
        });
      }
    });

    try {
      await cameraController.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_cameraController != null) {
      _cameraController!.dispose();
      _cameraController = null;
    }
    _positionSubscription?.cancel();
    super.dispose();
  }


  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() {
        _errorMessage = 'No camera found on this device';
      });
      return;
    }
    
    // Use the lifecycle logic helper to init
    _onNewCameraSelected(widget.cameras[0]);
  }

  Future<void> _startLocationTracking() async {
    setState(() {

      _isLoadingLocation = true;
    });

    // Try to get initial position with retries
    int retryCount = 0;
    const maxRetries = 5;
    
    while (_currentPosition == null && retryCount < maxRetries && mounted) {
      try {
        debugPrint('Attempting to get location (attempt ${retryCount + 1}/$maxRetries)...');
        final position = await _locationService.getCurrentPosition();
        
        if (position != null && mounted) {
          setState(() {
            _currentPosition = position;
            _isLoadingLocation = false;
          });
          
          debugPrint('Successfully acquired location: ${position.latitude}, ${position.longitude}');

          // Get address in background
          _locationService
              .getAddressFromCoordinates(position.latitude, position.longitude)
              .then((address) {
            if (mounted) {
              setState(() {
                _currentAddress = address;
              });
            }
          });
          
          break; // Exit retry loop on success
        } else {
          retryCount++;
          if (retryCount < maxRetries) {
            // Wait before retrying (exponential backoff)
            await Future.delayed(Duration(seconds: 2 * retryCount));
          }
        }
      } catch (e) {
        debugPrint('Error getting location (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * retryCount));
        }
      }
    }

    if (_currentPosition == null && mounted) {
      setState(() {
        _isLoadingLocation = false;
      });
      debugPrint('Failed to acquire location after $maxRetries attempts');
      _showSnackBar('Unable to get GPS location. Please ensure location services are enabled and you have a clear view of the sky.', isError: true);
    }

    // Continue tracking location with stream
    _positionSubscription = _locationService.getPositionStream().listen((position) {


      if (mounted) {
        setState(() {
          _currentPosition = position;
          if (_isLoadingLocation) {
            _isLoadingLocation = false;
          }
        });
        
        if (_currentAddress == null) {
          _locationService
              .getAddressFromCoordinates(position.latitude, position.longitude)
              .then((address) {
            if (mounted && address != null) {
              setState(() {
                _currentAddress = address;
              });
            }
          });
        }

        // Update map thumbnail periodically (e.g. every 30 seconds or if moved significantly)
        // For simplicity, let's just do it on time basis to avoid hammering the API
        final now = DateTime.now();
        if (_lastMapUpdate == null || now.difference(_lastMapUpdate!).inSeconds > 30) {
          _lastMapUpdate = now;
          _imageService.getMapThumbnail(position.latitude, position.longitude).then((thumbnail) {
            if (mounted && thumbnail != null) {
              _cachedMapThumbnail = thumbnail;
              // No setState needed as this doesn't affect UI directly
            }
          });
        }
      }
    }, onError: (error) {
      debugPrint('Location stream error: $error');
    });
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_currentPosition == null) {
      _showSnackBar('Waiting for GPS location...', isError: true);
      return;
    }


    // No blocking state setting here
    // setState(() { _isProcessing = true; });

    try {
      // Capture the image - this is the only part we wait for
      final XFile imageFile = await _cameraController!.takePicture();
      
      // Flash feedback
      _showSnackBar('Photo captured! Processing in background...');

      // Capture current state variables to pass to background task
      final currentLat = _currentPosition!.latitude;
      final currentLong = _currentPosition!.longitude;
      final currentAlt = _currentPosition!.altitude;
      final currentAcc = _currentPosition!.accuracy;
      final currentHeading = _currentPosition!.heading;
      final currentAddress = _currentAddress;
      final timestamp = DateTime.now();

      // Fire and forget background processing
      _processImageInBackground(
        imagePath: imageFile.path,
        lat: currentLat,
        long: currentLong,
        alt: currentAlt,
        acc: currentAcc,
        heading: currentHeading,
        address: currentAddress,
        time: timestamp,
        preloadedThumbnail: _cachedMapThumbnail, // Pass cached thumbnail
      );

    } catch (e) {
      _showSnackBar('Error capturing photo: $e', isError: true);
    }
  }

  Future<void> _openMap() async {
    if (_currentPosition == null) {
      _showSnackBar('Waiting for GPS location...', isError: true);
      return;
    }

    // Fetch all photos to show markers for them on the map
    final photos = await _storageService.getAllPhotos();

    if (mounted && _currentPosition != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MapScreen(
            latitude: _currentPosition!.latitude,
            longitude: _currentPosition!.longitude,
            photos: photos, // Pass extracted photos
          ),
        ),
      );
    }

  }

  Future<void> _processImageInBackground({
    required String imagePath,
    required double lat,
    required double long,
    required double alt,
    required double acc,
    required double heading,
    required String? address,
    required DateTime time,
    img.Image? preloadedThumbnail,
  }) async {
    try {
      // Process image with geotag
      final processedImage = await _imageService.addGeotagToImage(
        imagePath: imagePath,
        latitude: lat,
        longitude: long,
        timestamp: time,
        address: address,
        altitude: alt,
        accuracy: acc,
        preloadedMapThumbnail: preloadedThumbnail, // Pass it on
      );

      // Create photo metadata
      final photo = GeotaggedPhoto(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imagePath: processedImage.path,
        latitude: lat,
        longitude: long,
        timestamp: time,
        address: address,
        altitude: alt,
        accuracy: acc,
        heading: heading,
      );

      // Save metadata
      await _storageService.savePhotoMetadata(photo);

      // Delete temporary camera file
      await File(imagePath).delete();
      
      debugPrint('Background processing complete for photo at $time');
      
    } catch (e) {
      debugPrint('Error in background processing: $e');
      // Ideally we might want to show a delayed notification or retry, 
      // but for now logging is sufficient as we don't want to disturb the user flow.
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 5 : 2),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _errorMessage != null
            ? _buildErrorView()
            : !_isCameraInitialized
                ? const Center(child: CircularProgressIndicator())
                : _buildCameraView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: (_cameraController != null && _cameraController!.value.isInitialized)
              ? CameraPreview(_cameraController!)
              : Container(color: Colors.black, child: const Center(child: CircularProgressIndicator())),
        ),


        // Top info bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopInfoBar(),
        ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomControls(),
        ),

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Processing photo...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopInfoBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isLoadingLocation)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (_currentPosition != null ? Colors.green : Colors.red).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _currentPosition != null ? Icons.gps_fixed : Icons.gps_off,
                        color: _currentPosition != null ? Colors.green : Colors.red,
                        size: 16,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isLoadingLocation
                          ? 'Acquiring GPS location...'
                          : _currentPosition != null
                              ? _locationService.formatCoordinates(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                )
                              : 'GPS unavailable',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (_currentPosition != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _currentPosition!.accuracy <= 10.0 
                            ? Colors.green.withOpacity(0.2) 
                            : (_currentPosition!.accuracy <= 30.0 ? Colors.orange.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (_currentPosition!.accuracy <= 10.0 ? Colors.green : Colors.red).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _currentPosition!.accuracy.toStringAsFixed(1) + 'm',
                        style: TextStyle(
                          color: _currentPosition!.accuracy <= 10.0 ? Colors.greenAccent : Colors.orangeAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (_currentAddress != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.place_outlined, color: Colors.white.withOpacity(0.5), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _currentAddress!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.only(bottom: 40, top: 20, left: 24, right: 24),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Gallery button with background
          _buildFloatingActionButton(
            icon: Icons.photo_library_rounded,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GalleryScreen(),
                ),
              );
            },
          ),

          // Capture button - Redesigned
          GestureDetector(
            onTap: _isProcessing ? null : _capturePhoto,
            child: Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 4),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _currentPosition == null
                        ? [Colors.grey, Colors.grey.shade700]
                        : [Colors.white, Colors.grey.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: _isProcessing
                      ? const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blue),
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Map button
          _buildFloatingActionButton(
            icon: Icons.map_rounded,
            onPressed: _openMap,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
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
            onPressed: onPressed,
            icon: Icon(icon),
            color: Colors.white,
            iconSize: 28,
            padding: const EdgeInsets.all(12),
          ),
        ),
      ),
    );
  }

}
