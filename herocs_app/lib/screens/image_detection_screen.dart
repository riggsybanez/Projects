// lib/screens/image_detection_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import '../services/object_detection_service.dart';
import '../models/hazard_object.dart';
import '../models/household_danger_index.dart';
import '../widgets/bounding_box_painter.dart';

class ImageDetectionScreen extends StatefulWidget {
  @override
  _ImageDetectionScreenState createState() => _ImageDetectionScreenState();
}

class _ImageDetectionScreenState extends State<ImageDetectionScreen> {
  File? _selectedImage;
  bool _isProcessing = false;
  List<HazardObject> _detectedHazards = [];
  HouseholdDangerIndex? _hdi;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Image'),
        actions: [
          if (_selectedImage != null && !_isProcessing)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetSelection,
              tooltip: 'Choose another image',
            ),
        ],
      ),
      body: _selectedImage == null
          ? _buildImagePicker()
          : _buildResultsView(),
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          const Text(
            'Pumili ng larawan',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library, size: 28),
            label: const Text(
              'Gallery',
              style: TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickFromCamera,
            icon: const Icon(Icons.camera_alt, size: 28),
            label: const Text(
              'Take Photo',
              style: TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    return Column(
      children: [
        // Image with bounding boxes
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Display selected image
              Image.file(
                _selectedImage!,
                fit: BoxFit.contain,
              ),
              
              // Bounding boxes overlay
              if (_detectedHazards.isNotEmpty && !_isProcessing)
                CustomPaint(
                  painter: BoundingBoxPainter(
                    hazards: _detectedHazards,
                    imageSize: Size(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height,
                    ),
                  ),
                ),
              
              // Processing indicator
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
                          'Detecting hazards...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Results summary
        if (_hdi != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHDICard(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detected: ${_detectedHazards.length} hazard(s)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _showRecommendations,
                      child: const Text('View Report'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHDICard() {
    if (_hdi == null) return const SizedBox.shrink();

    Color hdiColor;
    switch (_hdi!.getSeverity()) {
      case HDISeverity.critical:
        hdiColor = Colors.red;
        break;
      case HDISeverity.high:
        hdiColor = Colors.orange;
        break;
      case HDISeverity.moderate:
        hdiColor = Colors.yellow[700]!;
        break;
      case HDISeverity.low:
        hdiColor = Colors.lightGreen;
        break;
      case HDISeverity.safe:
        hdiColor = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hdiColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hdiColor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'HDI Score',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _hdi!.calculateHDI().toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: hdiColor,
                ),
              ),
              Text(
                _hdi!.getInterpretation(),
                style: TextStyle(
                  fontSize: 12,
                  color: hdiColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        _processImage();
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        _processImage();
      }
    } catch (e) {
      _showError('Error taking photo: $e');
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Read image file
      final bytes = await _selectedImage!.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      
      if (decodedImage != null) {
        // Run detection
        final detectionService = Provider.of<ObjectDetectionService>(
          context,
          listen: false,
        );
        
        final hazards = await detectionService.detectHazards(decodedImage);
        
        // Calculate HDI
        final hdi = HouseholdDangerIndex(
          detectedHazards: hazards,
          assessmentTime: DateTime.now(),
        );
        
        setState(() {
          _detectedHazards = hazards;
          _hdi = hdi;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Detection error: $e');
    }
  }

  void _resetSelection() {
    setState(() {
      _selectedImage = null;
      _detectedHazards = [];
      _hdi = null;
    });
  }

  void _showRecommendations() {
    if (_hdi == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Safety Recommendations',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._hdi!.generateRecommendations().take(5).map((rec) {
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
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rec.message,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
