// lib/screens/camera_scan_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import '../services/object_detection_service.dart';
import '../models/hazard_object.dart';
import '../models/household_danger_index.dart';
import '../widgets/bounding_box_painter.dart';

class CameraScanScreen extends StatefulWidget {
  @override
  _CameraScanScreenState createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  
  // Detection results
  List<HazardObject> _detectedHazards = [];
  HouseholdDangerIndex? _hdi;
  
  // For periodic detection
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras!.isEmpty) {
        print('No cameras found');
        return;
      }

      // Use back camera (first camera is usually back)
      _cameraController = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        
        // Start periodic detection (every 1 second)
        _startPeriodicDetection();
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _startPeriodicDetection() {
    _detectionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_isDetecting && _cameraController != null) {
        _runDetection();
      }
    });
  }

  Future<void> _runDetection() async {
    if (_isDetecting || _cameraController == null) return;
    
    setState(() {
      _isDetecting = true;
    });

    try {
      // Capture image from camera
      final image = await _cameraController!.takePicture();
      
      // Convert to image package format
      final bytes = await image.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      
      if (decodedImage != null) {
        // Run detection
        final detectionService = Provider.of<ObjectDetectionService>(
          context,
          listen: false,
        );
        
        final hazards = await detectionService.detectHazards(decodedImage);
        
        // Calculate HDI
        final hdi = HouseholdDangerIndex(  // ✅ Use the regular constructor
          detectedHazards: hazards,
          assessmentTime: DateTime.now(),
        );
        
        if (mounted) {
          setState(() {
            _detectedHazards = hazards;
            _hdi = hdi;
          });
        }
      }
    } catch (e) {
      print('Detection error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          CameraPreview(_cameraController!),
          
          // AR Bounding boxes overlay
          if (_detectedHazards.isNotEmpty)
            CustomPaint(
              painter: BoundingBoxPainter(
                hazards: _detectedHazards,
                imageSize: Size(
                  _cameraController!.value.previewSize!.height,
                  _cameraController!.value.previewSize!.width,
                ),
              ),
            ),
          
          // Top overlay - HDI card
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: _buildHDICard(),
          ),
          
          // Bottom overlay - Detection count
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: _buildDetectionInfo(),
          ),
          
          // Back button
          Positioned(
            top: 50,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          // Detecting indicator
          if (_isDetecting)
            Positioned(
              top: 50,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Detecting...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHDICard() {
    if (_hdi == null) {
      return SizedBox.shrink();
    }

    Color hdiColor;
    switch (_hdi!.getSeverity()) {  // ✅ Call getSeverity() method instead of .severity property
      case HDISeverity.critical:     // ✅ Changed from criticallyUnsafe
        hdiColor = Colors.red;
        break;
      case HDISeverity.high:         // ✅ Changed from highlyUnsafe
        hdiColor = Colors.orange;
        break;
      case HDISeverity.moderate:     // ✅ Changed from unsafe
        hdiColor = Colors.yellow[700]!;
        break;
      case HDISeverity.low:          // ✅ Added this case
        hdiColor = Colors.lightGreen;
        break;
      case HDISeverity.safe:
        hdiColor = Colors.green;
        break;
    }

    return Card(
      color: Colors.black87,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HDI Score',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: hdiColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _hdi!.calculateHDI().toStringAsFixed(2),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              _hdi!.getInterpretation(),
              style: TextStyle(
                color: hdiColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionInfo() {
    return Card(
      color: Colors.black87,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hazards Detected: ${_detectedHazards.length}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            ElevatedButton(
              onPressed: _detectedHazards.isEmpty ? null : () {
                // TODO: Navigate to results screen
                _showResultsDialog();
              },
              child: Text('View Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultsDialog() {
    if (_hdi == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safety Recommendations',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ...(_hdi!.generateRecommendations().take(5).map((rec) {
                IconData icon;
                Color color;
                switch (rec.priority) {
                  case RecommendationPriority.urgent:
                    icon = Icons.warning;
                    color = Colors.red;
                    break;
                  case RecommendationPriority.important:
                    icon = Icons.priority_high;
                    color = Colors.orange;
                    break;
                  case RecommendationPriority.suggested:
                    icon = Icons.info;
                    color = Colors.blue;
                    break;
                }
                
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rec.message,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList()),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
