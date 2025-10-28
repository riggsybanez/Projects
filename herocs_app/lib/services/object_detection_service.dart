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
  static const double IOU_THRESHOLD = 0.65;
  
  // Temporal smoothing for stable detections
  final Map<String, List<HazardObject>> _detectionHistory = {};
  static const int HISTORY_LENGTH = 3;
  
  // ✅ BLACKLIST: Classes that perform poorly
  static const Set<String> BLOCKED_CLASSES = {
    'exposed_metal_bed_frame',  // Misclassifies everything
    'stool',                      // 2.4% precision
    'lead_paint',                 // 24.6% precision
    'hard_object',                // 0% recall
    'fragile_furniture',          // 0% recall
    'choking_object',             // 0% recall
  };
  
  // DATA-DRIVEN: Based on validation metrics
  static const Map<String, double> CLASS_CONFIDENCE_MULTIPLIERS = {
    'fragile_object': 1,
    'water_bucket': 1,
    'gas_container': 1,
    'pharmaceutical': 1.2,
    'electric_wire': 1,
    
    'surface_edge': 0.7,
    'furniture_sharp_corner': 0.7,
    'electric_plug': 1,
    'staircase_no_railing': 0.8,
  };
  
  static const Map<String, double> MIN_CONFIDENCE_THRESHOLD = {
    'surface_edge': 0.5,
    'staircase_no_railing': 0.5,
    'furniture_sharp_corner': 0.5,
    'electric_plug': 0.45,
    
    'toxic_chemical': 0.2,
    'pharmaceutical': 0.2,
    'gas_container': 0.25,
    'stove': 0.25,
    'flammable_object': 0.25,
    'flammable_liquid': 0.25,
  };

  bool get isModelLoaded => _isModelLoaded;

  Future<void> loadModel() async {
    try {
      print('📦 Loading YOLOv8 model...');

      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolov8n_herocs.tflite',
        options: InterpreterOptions()..threads = 4,
      );

      final labelsData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsData
          .split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();

      print('✅ Model loaded successfully. Classes: ${_labels!.length}');
      print('📋 Active classes: ${_labels!.where((l) => !BLOCKED_CLASSES.contains(l)).length}');
      print('🚫 Blocked classes: ${BLOCKED_CLASSES.length}');

      _isModelLoaded = true;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading model: $e');
      _isModelLoaded = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<List<HazardObject>> detectHazards(img.Image image) async {
    if (!_isModelLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    try {
      print('🔍 Starting hazard detection...');

      final resized = img.copyResize(image, width: INPUT_SIZE, height: INPUT_SIZE);

      var input = List.generate(
        1,
        (_) => List.generate(
          INPUT_SIZE,
          (y) => List.generate(
            INPUT_SIZE,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      print('✅ Image preprocessed: ${INPUT_SIZE}x$INPUT_SIZE');

      List<Detection> detections = _runInference(input);
      print('📊 Raw detections: ${detections.length}');

      detections = _applyNMS(detections);
      print('📊 After NMS: ${detections.length} detections');

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

      final smoothedHazards = _applySmoothingFilter(hazards);
      print('📊 After smoothing: ${smoothedHazards.length} stable hazards');

      return smoothedHazards;
    } catch (e) {
      print('❌ Detection error: $e');
      rethrow;
    }
  }

  List<Detection> _runInference(List<List<List<List<double>>>> input) {
    int numClasses = _labels!.length;
    int outputChannels = 4 + numClasses;
    int numBoxes = 8400;

    var output = List.generate(
      1,
      (_) => List.generate(
        outputChannels,
        (_) => List.filled(numBoxes, 0.0),
      ),
    );

    _interpreter!.run(input, output);

    List<Detection> detections = [];
    print('🔍 Processing $numBoxes potential detections...');
    print('═══════════════════════════════════════════════════════');

    Map<String, int> classDetectionCount = {};
    Map<String, double> classMaxConfidence = {};
    Map<String, int> blockedCount = {};
    int totalAboveBase = 0;
    int totalAfterAdjustment = 0;
    int totalBlocked = 0;

    for (int i = 0; i < numBoxes; i++) {
      double cx = output[0][0][i];
      double cy = output[0][1][i];
      double w = output[0][2][i];
      double h = output[0][3][i];

      double maxClassScore = 0;
      int bestClassIdx = 0;
      for (int c = 0; c < numClasses; c++) {
        double classScore = output[0][4 + c][i];
        if (classScore > maxClassScore) {
          maxClassScore = classScore;
          bestClassIdx = c;
        }
      }

      final className = _labels![bestClassIdx];
      double rawConfidence = maxClassScore;

      // ✅ CHECK BLACKLIST FIRST
      if (BLOCKED_CLASSES.contains(className)) {
        if (rawConfidence >= CONFIDENCE_THRESHOLD) {
          blockedCount[className] = (blockedCount[className] ?? 0) + 1;
          totalBlocked++;
        }
        continue;
      }

      classDetectionCount[className] = (classDetectionCount[className] ?? 0) + 1;
      if (rawConfidence > (classMaxConfidence[className] ?? 0)) {
        classMaxConfidence[className] = rawConfidence;
      }

      if (rawConfidence >= CONFIDENCE_THRESHOLD) {
        totalAboveBase++;
      }

      final multiplier = CLASS_CONFIDENCE_MULTIPLIERS[className] ?? 1.0;
      double adjustedConfidence = (rawConfidence * multiplier).clamp(0.0, 1.0);

      final minThreshold = MIN_CONFIDENCE_THRESHOLD[className] ?? CONFIDENCE_THRESHOLD;

      if (adjustedConfidence >= minThreshold) {
        totalAfterAdjustment++;
        
        double x = (cx - w / 2).clamp(0.0, 1.0);
        double y = (cy - h / 2).clamp(0.0, 1.0);
        w = w.clamp(0.0, 1.0 - x);
        h = h.clamp(0.0, 1.0 - y);

        detections.add(Detection(
          className: className,
          confidence: adjustedConfidence,
          rawConfidence: rawConfidence,
          bbox: BoundingBox(x: x, y: y, width: w, height: h),
        ));

        print('  ✅ Detection #${detections.length}:');
        print('     Class: $className');
        print('     Raw: ${(rawConfidence * 100).toStringAsFixed(1)}%');
        print('     Adjusted: ${(adjustedConfidence * 100).toStringAsFixed(1)}% (x${multiplier.toStringAsFixed(2)})');
        print('     Threshold: ${(minThreshold * 100).toStringAsFixed(1)}%');
        print('     BBox: [${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${w.toStringAsFixed(3)}, ${h.toStringAsFixed(3)}]');
        print('     ---');
      }
    }

    print('═══════════════════════════════════════════════════════');
    print('📊 DETECTION SUMMARY:');
    print('   Total boxes processed: $numBoxes');
    print('   Blocked (unreliable classes): $totalBlocked');
    print('   Above base threshold: $totalAboveBase');
    print('   After adjustments: $totalAfterAdjustment');
    print('   Final detections: ${detections.length}');
    
    if (blockedCount.isNotEmpty) {
      print('');
      print('🚫 BLOCKED DETECTIONS:');
      blockedCount.forEach((className, count) {
        print('   $className: $count blocked');
      });
    }
    
    print('');
    print('📊 TOP DETECTIONS BY CONFIDENCE:');
    
    var sortedClasses = classMaxConfidence.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (var entry in sortedClasses.take(10)) {
      final className = entry.key;
      final maxConf = entry.value;
      final count = classDetectionCount[className] ?? 0;
      final multiplier = CLASS_CONFIDENCE_MULTIPLIERS[className] ?? 1.0;
      final threshold = MIN_CONFIDENCE_THRESHOLD[className] ?? CONFIDENCE_THRESHOLD;
      
      print('   $className:');
      print('     Max: ${(maxConf * 100).toStringAsFixed(1)}% | Count: $count | Mult: ${multiplier.toStringAsFixed(2)}x | Thresh: ${(threshold * 100).toInt()}%');
    }
    
    print('═══════════════════════════════════════════════════════');
    
    return detections;
  }

  List<Detection> _applyNMS(List<Detection> detections) {
    if (detections.isEmpty) return detections;

    print('🔧 Applying NMS (IOU threshold: ${IOU_THRESHOLD})...');
    
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    List<Detection> kept = [];
    int removed = 0;

    for (var current in detections) {
      bool shouldKeep = true;

      for (var existing in kept) {
        final iou = current.bbox.calculateIoU(existing.bbox);

        if (iou > IOU_THRESHOLD && current.className == existing.className) {
          shouldKeep = false;
          removed++;
          print('   ❌ ${current.className} ${(current.confidence * 100).toStringAsFixed(1)}% (IoU: ${iou.toStringAsFixed(2)})');
          break;
        }
      }

      if (shouldKeep) {
        kept.add(current);
        print('   ✅ ${current.className} ${(current.confidence * 100).toStringAsFixed(1)}%');
      }
    }

    print('📊 NMS: Kept ${kept.length}, Removed $removed');
    return kept;
  }

  List<HazardObject> _applySmoothingFilter(List<HazardObject> newDetections) {
    final now = DateTime.now().millisecondsSinceEpoch.toString();

    _detectionHistory[now] = newDetections;

    if (_detectionHistory.length > HISTORY_LENGTH) {
      final oldestKey = _detectionHistory.keys.first;
      _detectionHistory.remove(oldestKey);
    }

    if (_detectionHistory.length < 2) {
      print('🕐 Temporal smoothing: Single frame, skipping');
      return newDetections;
    }

    print('🕐 Temporal smoothing: Checking ${_detectionHistory.length} frames');

    final consistentDetections = <HazardObject>[];

    for (var detection in newDetections) {
      int appearanceCount = 0;

      for (var historyFrame in _detectionHistory.values) {
        for (var pastDetection in historyFrame) {
          if (pastDetection.objectName == detection.objectName &&
              _isSimilarLocation(detection.boundingBox, pastDetection.boundingBox)) {
            appearanceCount++;
            break;
          }
        }
      }

      final isConsistent = appearanceCount >= 2;
      print('   ${detection.objectName}: $appearanceCount/${_detectionHistory.length} frames ${isConsistent ? "✅" : "❌"}');

      if (isConsistent) {
        consistentDetections.add(detection);
      }
    }

    return consistentDetections.isEmpty ? newDetections : consistentDetections;
  }

  bool _isSimilarLocation(BoundingBox box1, BoundingBox box2) {
    final centerDist = (box1.centerX - box2.centerX).abs() +
        (box1.centerY - box2.centerY).abs();
    return centerDist < 0.30;
  }

  HazardObject _classifyHazard({
    required String objectName,
    required BoundingBox boundingBox,
    required double confidence,
  }) {
    final hazardLabels = RiskClassification.assignHazardLabels(
      objectName,
      objectCenterY: boundingBox.centerY,
    );

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

  void clearHistory() {
    _detectionHistory.clear();
  }

  @override
  void dispose() {
    _interpreter?.close();
    _detectionHistory.clear();
    super.dispose();
  }
}

class Detection {
  final String className;
  final double confidence;
  final double rawConfidence;
  final BoundingBox bbox;

  Detection({
    required this.className,
    required this.confidence,
    required this.rawConfidence,
    required this.bbox,
  });
}
