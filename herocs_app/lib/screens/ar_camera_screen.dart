// lib/screens/ar_camera_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import '../services/object_detection_service.dart';
import '../models/hazard_object.dart';
import '../models/household_danger_index.dart';
import '../models/risk_classification.dart';

class ARCameraScreen extends StatefulWidget {
  const ARCameraScreen({Key? key}) : super(key: key);

  @override
  State<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends State<ARCameraScreen> {
  // Camera package for image capture
  CameraController? cameraController;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;

  // ArCore ONLY for overlay
  ArCoreController? arCoreController;

  // Detection state
  List<HazardObject> detectedHazards = [];
  HouseholdDangerIndex? currentHDI;
  Timer? detectionTimer;
  bool isDetecting = false;
  HazardObject? selectedHazard; // ✅ Track selected hazard

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _startPeriodicDetection();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        cameraController = CameraController(
          cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await cameraController!.initialize();

        if (mounted) {
          setState(() => isCameraInitialized = true);
        }
      }
    } catch (e) {
      print('❌ Camera initialization error: $e');
    }
  }

  void _startPeriodicDetection() {
    detectionTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (isCameraInitialized && !isDetecting && mounted) {
        _captureAndDetect();
      }
    });
  }

  Future<void> _captureAndDetect() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }

    setState(() => isDetecting = true);

    try {
      final image = await cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage != null && mounted) {
        final detectionService = Provider.of<ObjectDetectionService>(context, listen: false);
        final hazards = await detectionService.detectHazards(decodedImage);

        if (mounted) {
          setState(() {
            detectedHazards = hazards;
            if (hazards.isNotEmpty) {
              currentHDI = HouseholdDangerIndex(
                detectedHazards: hazards,
                assessmentTime: DateTime.now(),
              );
            }
          });
        }
      }
    } catch (e) {
      print('❌ Detection error: $e');
    } finally {
      if (mounted) {
        setState(() => isDetecting = false);
      }
    }
  }

  // ✅ FIXED: Handle screen tap with proper coordinate mapping
  void _handleScreenTap(TapDownDetails details) {
    if (detectedHazards.isEmpty) return;

    final size = MediaQuery.of(context).size;
    
    // Get tap position normalized to 0-1
    final tapX = details.globalPosition.dx / size.width;
    final tapY = details.globalPosition.dy / size.height;

    print('🎯 AR Tap at normalized: ($tapX, $tapY)');

    // Find hazard whose bounding box contains the tap
    for (var hazard in detectedHazards) {
      final bbox = hazard.boundingBox;
      
      final left = bbox.x;
      final right = bbox.x + bbox.width;
      final top = bbox.y;
      final bottom = bbox.y + bbox.height;

      print('   Checking ${hazard.objectName}: [$left-$right, $top-$bottom]');

      if (tapX >= left && tapX <= right && tapY >= top && tapY <= bottom) {
        print('✅ Hit detected on ${hazard.objectName}!');
        setState(() => selectedHazard = hazard);
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
              setState(() => selectedHazard = null);
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

  @override
  Widget build(BuildContext context) {
    if (!isCameraInitialized || cameraController == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing AR Camera...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: GestureDetector(
        onTapDown: _handleScreenTap, // ✅ Handle taps
        child: Stack(
          children: [
            // Camera preview (full screen)
            Positioned.fill(
              child: CameraPreview(cameraController!),
            ),

            // AR bounding boxes overlay
            if (detectedHazards.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: ARBoundingBoxPainter(
                    hazards: detectedHazards,
                    selectedHazard: selectedHazard, // ✅ Pass selected hazard
                  ),
                ),
              ),

            // Top status bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AR Scan Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (isDetecting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom info panel
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentHDI != null) _buildHDIDisplay(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard(
                          'Hazards',
                          '${detectedHazards.length}',
                          Icons.warning_amber,
                          Colors.orange,
                        ),
                        _buildStatCard(
                          'High Risk',
                          '${detectedHazards.where((h) => h.riskLevel == 'Highly Dangerous' || h.riskLevel == 'High Risk').length}',
                          Icons.dangerous,
                          Colors.red,
                        ),
                        _buildStatCard(
                          'Scanning',
                          isDetecting ? 'Active' : 'Idle',
                          Icons.radar,
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tap instruction overlay
            if (detectedHazards.isNotEmpty)
              Positioned(
                top: MediaQuery.of(context).padding.top + 70,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '👆 Tap any bounding box for details',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHDIDisplay() {
    if (currentHDI == null) return const SizedBox.shrink();

    Color hdiColor;
    switch (currentHDI!.getSeverity()) {
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hdiColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hdiColor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'HDI Score',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currentHDI!.calculateHDI().toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: hdiColor,
                ),
              ),
              Text(
                currentHDI!.getInterpretation(),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    detectionTimer?.cancel();
    cameraController?.dispose();
    arCoreController?.dispose();
    super.dispose();
  }
}

// AR Bounding Box Painter
class ARBoundingBoxPainter extends CustomPainter {
  final List<HazardObject> hazards;
  final HazardObject? selectedHazard;

  ARBoundingBoxPainter({
    required this.hazards,
    this.selectedHazard,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var hazard in hazards) {
      final isSelected = selectedHazard == hazard;
      
      Color boxColor;
      switch (hazard.riskLevel) {
        case 'Highly Dangerous':
          boxColor = Colors.red;
          break;
        case 'High Risk':
          boxColor = Colors.orange;
          break;
        case 'Moderate Risk':
          boxColor = Colors.yellow;
          break;
        default:
          boxColor = Colors.green;
      }

      final bbox = hazard.boundingBox;
      final left = bbox.x * size.width;
      final top = bbox.y * size.height;
      final width = bbox.width * size.width;
      final height = bbox.height * size.height;

      // Draw bounding box
      final paint = Paint()
        ..color = boxColor.withOpacity(isSelected ? 1.0 : 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 5 : 3;

      canvas.drawRect(Rect.fromLTWH(left, top, width, height), paint);

      // Highlight selected
      if (isSelected) {
        final fillPaint = Paint()
          ..color = boxColor.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTWH(left, top, width, height), fillPaint);
      }

      // Draw label background
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

      final labelBgPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, labelTop, textPainter.width + 12, 24),
          const Radius.circular(4),
        ),
        labelBgPaint,
      );

      textPainter.paint(canvas, Offset(left + 6, labelTop + 4));

      // Add tap icon if not selected
      if (!isSelected) {
        final iconPainter = TextPainter(
          text: const TextSpan(text: '👆', style: TextStyle(fontSize: 18)),
          textDirection: TextDirection.ltr,
        );
        iconPainter.layout();
        iconPainter.paint(canvas, Offset(left + width - 28, top + 4));
      }

      // Edge warning icon
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
