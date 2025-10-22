// lib/services/object_detection_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/hazard_object.dart';
import '../models/risk_classification.dart';

class ObjectDetectionService extends ChangeNotifier {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isModelLoaded = false;

  // YOLOv8 configuration
  static const int INPUT_SIZE = 640;
  static const double CONFIDENCE_THRESHOLD = 0.3;
  static const double IOU_THRESHOLD = 0.5;

  bool get isModelLoaded => _isModelLoaded;

  /// Initialize and load the TFLite model
  Future<void> loadModel() async {
    try {
      print('📦 Loading YOLOv8 model...');

      // Load model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolov8n_herocs.tflite',
        options: InterpreterOptions()..threads = 4,
      );

      // Load labels
      final labelsData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();

      print('✅ Model loaded successfully. Classes: ${_labels!.length}');
      print('📋 Labels: $_labels');

      _isModelLoaded = true;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading model: $e');
      _isModelLoaded = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Detect hazards in an image
  Future<List<HazardObject>> detectHazards(img.Image image) async {
    if (!_isModelLoaded) {
      throw Exception('Model not loaded');
    }

    try {
      print('🔍 Starting hazard detection...');
      
      // Resize image to model input size
      final resized = img.copyResize(image, width: INPUT_SIZE, height: INPUT_SIZE);
      
      // Prepare input in NHWC format: (1, 640, 640, 3)
      // This matches TFLite model input: TensorSpec(shape=(1, 640, 640, 3))
      var input = List.generate(
        1,
        (_) => List.generate(
          INPUT_SIZE,  // height
          (y) => List.generate(
            INPUT_SIZE,  // width
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,  // R channel
                pixel.g / 255.0,  // G channel
                pixel.b / 255.0,  // B channel
              ];
            },
          ),
        ),
      );
      
      print('✅ Image preprocessed: ${INPUT_SIZE}x${INPUT_SIZE}');
      
      // Run inference
      List<Detection> detections = _runInference(input);
      
      print('📊 Found ${detections.length} detections above threshold');
      
      // Convert to HazardObject
      List<HazardObject> hazards = [];
      for (var detection in detections) {
        final hazardObj = _classifyHazard(
          objectName: detection.className,
          boundingBox: detection.bbox,
          confidence: detection.confidence,
        );
        hazards.add(hazardObj);
      }
      
      print('✅ Classified ${hazards.length} hazards');
      return hazards;
    } catch (e) {
      print('❌ Detection error: $e');
      rethrow;
    }
  }

  /// Run YOLOv8 inference  
  List<Detection> _runInference(List<List<List<List<double>>>> input) {
    int numClasses = _labels!.length;  // 20 classes
    
    // YOLOv8 output format: [1, 24, 8400]
    // 24 = 4 bbox coords + 20 class scores
    int outputChannels = 4 + numClasses;  // 24 channels
    int numBoxes = 8400;
    
    var output = List.generate(
      1,
      (_) => List.generate(
        outputChannels,  
        (_) => List.filled(numBoxes, 0.0),
      ),
    );
    
    // Run inference
    _interpreter!.run(input, output);
    
    List<Detection> detections = [];
    
    print('🔍 Processing $numBoxes potential detections...');
    
    for (int i = 0; i < numBoxes; i++) {
      // Get box coordinates - YOLOv8 outputs are already normalized 0-1
      double cx = output[0][0][i];  // center x (normalized)
      double cy = output[0][1][i];  // center y (normalized)  
      double w = output[0][2][i];   // width (normalized)
      double h = output[0][3][i];   // height (normalized)
      
      // Find best class
      double maxClassScore = 0;
      int bestClassIdx = 0;
      
      for (int c = 0; c < numClasses; c++) {
        double classScore = output[0][4 + c][i];
        if (classScore > maxClassScore) {
          maxClassScore = classScore;
          bestClassIdx = c;
        }
      }
      
      double confidence = maxClassScore;
      
      if (confidence >= CONFIDENCE_THRESHOLD) {
        // Convert from center format to corner format
        double x = (cx - w / 2).clamp(0.0, 1.0);
        double y = (cy - h / 2).clamp(0.0, 1.0);
        w = w.clamp(0.0, 1.0 - x);
        h = h.clamp(0.0, 1.0 - y);
        
        print('✅ Detection: ${_labels![bestClassIdx]} conf=${confidence.toStringAsFixed(2)} bbox=($x, $y, $w, $h)');
        
        detections.add(Detection(
          className: _labels![bestClassIdx],
          confidence: confidence,
          bbox: BoundingBox(x: x, y: y, width: w, height: h),
        ));
      }
    }
    
    print('📊 Found ${detections.length} valid detections');
    return detections;
  }

  /// Classify detected object as hazard with risk assessment
  HazardObject _classifyHazard({
  required String objectName,
  required BoundingBox boundingBox,
  required double confidence,
}) {
  // Get hazard labels using RiskClassification.assignHazardLabels
  final hazardLabels = RiskClassification.assignHazardLabels(
    objectName,
    objectCenterY: boundingBox.y + (boundingBox.height / 2), // center Y
  );

  // Create HazardObject - it will calculate risk internally
  return HazardObject.fromDetection(
    objectName: objectName,
    hazardLabels: hazardLabels,
    x: boundingBox.x,
    y: boundingBox.y,
    width: boundingBox.width,
    height: boundingBox.height,
    confidence: confidence,
  );
}

  /// Clean up resources
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
}

/// Helper classes for detection results
class Detection {
  final String className;
  final double confidence;
  final BoundingBox bbox;

  Detection({
    required this.className,
    required this.confidence,
    required this.bbox,
  });
}

class BoundingBox {
  final double x;      // top-left x (normalized 0-1)
  final double y;      // top-left y (normalized 0-1)
  final double width;  // width (normalized 0-1)
  final double height; // height (normalized 0-1)

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}
