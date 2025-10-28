// lib/screens/image_detection_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import '../services/object_detection_service.dart';
import '../models/hazard_object.dart';
import '../models/household_danger_index.dart';
import '../models/risk_classification.dart';

class ImageDetectionScreen extends StatefulWidget {
  @override
  _ImageDetectionScreenState createState() => _ImageDetectionScreenState();
}

class _ImageDetectionScreenState extends State<ImageDetectionScreen> {
  File? _selectedImage;
  bool _isProcessing = false;
  List<HazardObject> _detectedHazards = [];
  HouseholdDangerIndex? _hdi;
  HazardObject? _selectedHazard;
  final ImagePicker _picker = ImagePicker();
  Size _imageSize = Size.zero;
  final GlobalKey _imageKey = GlobalKey(); // ✅ Key for getting image widget size

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
          Icon(Icons.image, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 24),
          const Text(
            'Select an Image',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library, size: 28),
            label: const Text('Gallery', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickFromCamera,
            icon: const Icon(Icons.camera_alt, size: 28),
            label: const Text('Take Photo', style: TextStyle(fontSize: 18)),
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
        Expanded(
          child: GestureDetector(
            onTapDown: _handleImageTap,
            child: Container(
              key: _imageKey, // ✅ Key for measuring widget
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_selectedImage!, fit: BoxFit.contain),
                  
                  if (_detectedHazards.isNotEmpty && !_isProcessing)
                    CustomPaint(
                      painter: InteractiveBoundingBoxPainter(
                        hazards: _detectedHazards,
                        selectedHazard: _selectedHazard,
                        imageSize: _imageSize,
                      ),
                    ),
                  
                  if (_detectedHazards.isNotEmpty && !_isProcessing)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '👆 Tap any bounding box to see hazard details',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  
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
                              style: TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        
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

  // ✅ FIXED: Handle tap with proper coordinate mapping
  void _handleImageTap(TapDownDetails details) {
    if (_detectedHazards.isEmpty) return;

    // Get the container's render box
    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final localPosition = details.localPosition;

    // Account for BoxFit.contain letterboxing
    final imageAspectRatio = _imageSize.width / _imageSize.height;
    final containerAspectRatio = size.width / size.height;

    double actualImageWidth;
    double actualImageHeight;
    double offsetX = 0;
    double offsetY = 0;

    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider - letterbox top/bottom
      actualImageWidth = size.width;
      actualImageHeight = size.width / imageAspectRatio;
      offsetY = (size.height - actualImageHeight) / 2;
    } else {
      // Image is taller - letterbox left/right
      actualImageHeight = size.height;
      actualImageWidth = size.height * imageAspectRatio;
      offsetX = (size.width - actualImageWidth) / 2;
    }

    // Convert tap position to normalized coordinates (0-1)
    final tapX = (localPosition.dx - offsetX) / actualImageWidth;
    final tapY = (localPosition.dy - offsetY) / actualImageHeight;

    // Check if tap is in letterbox area
    if (tapX < 0 || tapX > 1 || tapY < 0 || tapY > 1) {
      return;
    }

    print('🎯 Tap at normalized: ($tapX, $tapY)');

    // Find which hazard's bounding box contains the tap
    for (var hazard in _detectedHazards) {
      final bbox = hazard.boundingBox;
      final left = bbox.x;
      final right = bbox.x + bbox.width;
      final top = bbox.y;
      final bottom = bbox.y + bbox.height;

      print('   Checking ${hazard.objectName}: [$left-$right, $top-$bottom]');

      if (tapX >= left && tapX <= right && tapY >= top && tapY <= bottom) {
        print('✅ Hit: ${hazard.objectName}');
        setState(() => _selectedHazard = hazard);
        _showHazardDetails(hazard);
        return;
      }
    }

    print('❌ No hazard tapped');
  }

  void _showHazardDetails(HazardObject hazard) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getHazardIcon(hazard.riskLevel),
              color: _getHazardColor(hazard.riskLevel),
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hazard.objectName.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Detection Confidence', '${(hazard.confidence * 100).toInt()}%'),
              const Divider(height: 24),
              _buildDetailRow('Risk Level', hazard.riskLevel, 
                  color: _getHazardColor(hazard.riskLevel)),
              const Divider(height: 24),
              _buildDetailRow('Risk Score', '${hazard.riskScore.toStringAsFixed(2)} / 0.5',
                  color: _getHazardColor(hazard.riskLevel)),
              const Divider(height: 24),
              _buildDetailRow('Position', 
                  PositionalDetection.getHeightDescription(hazard.boundingBox.centerY),
                  color: _getPositionalColor(hazard.hazardLabels)),
              
              if (hazard.isNearEdge) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'NEAR EDGE! Fall risk detected',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              const Text(
                'Hazard Categories:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: hazard.hazardLabels
                    .where((label) => !label.contains('_level') && !label.contains('reach'))
                    .take(8)
                    .map((label) => Chip(
                          label: Text(
                            label.replaceAll('_', ' '),
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.orange.shade100,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Safety Recommendation:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  RiskClassification.getRecommendation(hazard),
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedHazard = null);
            },
            icon: const Icon(Icons.close),
            label: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color ?? Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Color _getHazardColor(String riskLevel) {
    switch (riskLevel) {
      case 'Highly Dangerous': return Colors.red.shade700;
      case 'High Risk': return Colors.orange.shade700;
      case 'Moderate Risk': return Colors.yellow.shade700;
      case 'Low Risk': return Colors.green.shade700;
      default: return Colors.grey;
    }
  }

  Color _getPositionalColor(List<String> labels) {
    if (labels.contains('floor_level')) return Colors.red.shade700;
    if (labels.contains('within_reach')) return Colors.orange.shade700;
    if (labels.contains('elevated')) return Colors.green.shade700;
    return Colors.grey;
  }

  IconData _getHazardIcon(String riskLevel) {
    switch (riskLevel) {
      case 'Highly Dangerous': return Icons.dangerous;
      case 'High Risk': return Icons.warning;
      case 'Moderate Risk': return Icons.error_outline;
      default: return Icons.info_outline;
    }
  }

  Widget _buildHDICard() {
    if (_hdi == null) return const SizedBox.shrink();
    
    Color hdiColor;
    switch (_hdi!.getSeverity()) {
      case HDISeverity.critical: hdiColor = Colors.red; break;
      case HDISeverity.high: hdiColor = Colors.orange; break;
      case HDISeverity.moderate: hdiColor = Colors.yellow[700]!; break;
      case HDISeverity.low: hdiColor = Colors.lightGreen; break;
      case HDISeverity.safe: hdiColor = Colors.green; break;
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
          const Text('HDI Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _hdi!.calculateHDI().toStringAsFixed(2),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: hdiColor),
              ),
              Text(
                _hdi!.getInterpretation(),
                style: TextStyle(fontSize: 12, color: hdiColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
        _processImage();
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
        _processImage();
      }
    } catch (e) {
      _showError('Error taking photo: $e');
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;
    
    setState(() => _isProcessing = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage != null) {
        setState(() {
          _imageSize = Size(
            decodedImage.width.toDouble(),
            decodedImage.height.toDouble(),
          );
        });

        final detectionService = Provider.of<ObjectDetectionService>(context, listen: false);
        final hazards = await detectionService.detectHazards(decodedImage);
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
      setState(() => _isProcessing = false);
      _showError('Detection error: $e');
    }
  }

  void _resetSelection() {
    setState(() {
      _selectedImage = null;
      _detectedHazards = [];
      _hdi = null;
      _selectedHazard = null;
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                      Expanded(child: Text(rec.message, style: const TextStyle(fontSize: 14))),
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// Interactive bounding box painter
class InteractiveBoundingBoxPainter extends CustomPainter {
  final List<HazardObject> hazards;
  final HazardObject? selectedHazard;
  final Size imageSize;

  InteractiveBoundingBoxPainter({
    required this.hazards,
    this.selectedHazard,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var hazard in hazards) {
      final isSelected = selectedHazard == hazard;
      
      Color boxColor;
      switch (hazard.riskLevel) {
        case 'Highly Dangerous': boxColor = Colors.red; break;
        case 'High Risk': boxColor = Colors.orange; break;
        case 'Moderate Risk': boxColor = Colors.yellow; break;
        default: boxColor = Colors.green;
      }
      
      final bbox = hazard.boundingBox;
      final left = bbox.x * size.width;
      final top = bbox.y * size.height;
      final width = bbox.width * size.width;
      final height = bbox.height * size.height;
      
      // Draw bounding box
      final paint = Paint()
        ..color = boxColor.withOpacity(isSelected ? 1.0 : 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 5 : 3;
      
      canvas.drawRect(Rect.fromLTWH(left, top, width, height), paint);
      
      // Highlight selected
      if (isSelected) {
        final fillPaint = Paint()
          ..color = boxColor.withOpacity(0.25)
          ..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTWH(left, top, width, height), fillPaint);
      }
      
      // Draw label
      final labelText = '${hazard.objectName.replaceAll('_', ' ')} ${(hazard.confidence * 100).toInt()}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      final labelTop = top > 30 ? top - 28 : top + height + 4;
      
      final labelBgPaint = Paint()..color = boxColor..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, labelTop, textPainter.width + 12, 24),
          const Radius.circular(4),
        ),
        labelBgPaint,
      );
      
      textPainter.paint(canvas, Offset(left + 6, labelTop + 4));
      
      if (!isSelected) {
        final iconPainter = TextPainter(
          text: const TextSpan(text: '👆', style: TextStyle(fontSize: 18)),
          textDirection: TextDirection.ltr,
        );
        iconPainter.layout();
        iconPainter.paint(canvas, Offset(left + width - 28, top + 4));
      }
      
      if (hazard.isNearEdge) {
        final edgeIcon = TextPainter(
          text: const TextSpan(text: '⚠️', style: TextStyle(fontSize: 20)),
          textDirection: TextDirection.ltr,
        );
        edgeIcon.layout();
        edgeIcon.paint(canvas, Offset(left + 4, top + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
