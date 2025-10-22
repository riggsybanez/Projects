// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/object_detection_service.dart';
import 'camera_scan_screen.dart';
import 'image_detection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Icon
              Icon(
                Icons.health_and_safety,
                size: 120,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              
              // App Title
              const Text(
                'HEROCS',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle
              const Text(
                'Hazard Detection System\nfor Filipino Households',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Model Status Indicator
              Consumer<ObjectDetectionService>(
                builder: (context, detectionService, child) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: detectionService.isModelLoaded 
                          ? Colors.green[50] 
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: detectionService.isModelLoaded 
                            ? Colors.green 
                            : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          detectionService.isModelLoaded 
                              ? Icons.check_circle 
                              : Icons.hourglass_empty,
                          color: detectionService.isModelLoaded 
                              ? Colors.green 
                              : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          detectionService.isModelLoaded 
                              ? 'AI Model Ready' 
                              : 'Loading AI Model...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: detectionService.isModelLoaded 
                                ? Colors.green[900] 
                                : Colors.orange[900],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Mode Selection Label
              Text(
                'Pumili ng Mode:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Mode 1: Real-time AR Camera
              Consumer<ObjectDetectionService>(
                builder: (context, detectionService, child) {
                  return _ModeButton(
                    icon: Icons.camera_alt,
                    title: 'Real-time Scan',
                    subtitle: 'AR camera detection',
                    color: Colors.blue,
                    enabled: detectionService.isModelLoaded,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CameraScanScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
              
              const SizedBox(height: 12),
              
              // Mode 2: Image from Gallery
              Consumer<ObjectDetectionService>(
                builder: (context, detectionService, child) {
                  return _ModeButton(
                    icon: Icons.image,
                    title: 'Scan Image',
                    subtitle: 'Upload from gallery or take photo',
                    color: Colors.green,
                    enabled: detectionService.isModelLoaded,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageDetectionScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
              
              const Spacer(),
              
              // Instructions Button
              TextButton.icon(
                onPressed: () {
                  _showInstructions(context);
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('Paano Gamitin'),
              ),
              
              // Footer
              const Text(
                'For children 0-3 years old\nBased on WHO height standards',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paano Gamitin ang HEROCS'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '2 Detection Modes:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                '📸 Real-time Scan\n'
                '• Use phone camera\n'
                '• Live AR detection\n'
                '• Hold at chest level (~150cm)\n'
                '• Tilt phone slightly downward',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 12),
              Text(
                '🖼️ Scan Image\n'
                '• Upload photo from gallery\n'
                '• Or take new photo\n'
                '• Detects hazards in static image\n'
                '• Shows results with HDI score',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Naintindihan ko'),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: enabled ? 4 : 1,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: enabled ? color.withOpacity(0.1) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: enabled ? color : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: enabled ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: enabled ? Colors.grey[600] : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: enabled ? color : Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
