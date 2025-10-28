// lib/models/hazard_object.dart

import 'dart:math';

/// Represents a single hazard detected by the YOLO model
class HazardObject {
  final String id;
  final String objectName;
  final List<String> hazardLabels;
  final double riskScore;
  final String riskLevel;
  final BoundingBox boundingBox;
  final double confidence;
  final DateTime detectedAt;
  final String? imageSnapshot;

  // Edge proximity detection fields
  final bool isNearEdge;
  final double? distanceToEdge;

  HazardObject({
    required this.id,
    required this.objectName,
    required this.hazardLabels,
    required this.riskScore,
    required this.riskLevel,
    required this.boundingBox,
    required this.confidence,
    required this.detectedAt,
    this.imageSnapshot,
    this.isNearEdge = false,
    this.distanceToEdge,
  });

  /// Create from YOLO detection output
  factory HazardObject.fromDetection({
    required String objectName,
    required List<String> hazardLabels,
    required double x,
    required double y,
    required double width,
    required double height,
    required double confidence,
    bool isNearEdge = false,
    double? distanceToEdge,
  }) {
    double riskScore = calculateRiskScore(hazardLabels, isNearEdge);
    String riskLevel = getRiskLevel(riskScore);

    return HazardObject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      objectName: objectName,
      hazardLabels: hazardLabels,
      riskScore: riskScore,
      riskLevel: riskLevel,
      boundingBox: BoundingBox(x: x, y: y, width: width, height: height),
      confidence: confidence,
      detectedAt: DateTime.now(),
      isNearEdge: isNearEdge,
      distanceToEdge: distanceToEdge,
    );
  }

  /// Calculate risk score with edge proximity boost
  /// UPDATED: Now supports full 0.5 scale per thesis Table 1.0
  static double calculateRiskScore(List<String> labels, bool isNearEdge) {
    double baseScore = 0.1;

    // Highly Dangerous (0.5) - UPDATED from 0.4 to 0.5
    if (labels.contains('highly_dangerous')) {
      baseScore = 0.5;
    }
    else if ((labels.contains('sharp') || labels.contains('hot')) &&
        labels.contains('within_reach') &&
        labels.contains('unsecured')) {
      baseScore = 0.5;
    }
    else if (labels.contains('exposed_wiring') ||
        (labels.contains('poisonous') && labels.contains('unsecured')) ||
        labels.contains('explosive') ||
        labels.contains('drowning')) {
      baseScore = 0.5;
    }

    // High Risk (0.4) - NEW tier added
    else if (labels.contains('high_risk')) {
      baseScore = 0.4;
    }
    else if ((labels.contains('sharp') || labels.contains('choking')) &&
        labels.contains('within_reach')) {
      baseScore = 0.4;
    }
    else if (labels.contains('hot') && labels.contains('within_reach')) {
      baseScore = 0.4;
    }
    else if (labels.contains('flammable') || labels.contains('toxic')) {
      baseScore = 0.4;
    }

    // Moderate Risk (0.3) - UPDATED from 0.2 to 0.3
    else if (labels.contains('moderate_risk')) {
      baseScore = 0.3;
    }
    else if (labels.contains('sharp') ||
        labels.contains('electrical') ||
        labels.contains('heavy') ||
        labels.contains('fragile')) {
      baseScore = 0.3;
    }

    // Low Risk (0.2) - UPDATED from 0.1 to 0.2
    else if (labels.contains('low_risk') || labels.contains('secured')) {
      baseScore = 0.2;
    }

    // EDGE PROXIMITY BOOST (only for edge-sensitive objects)
    if (isNearEdge && baseScore < 0.5) {
      baseScore += 0.1;
      if (baseScore > 0.5) baseScore = 0.5; // Cap at 0.5
    }

    return baseScore;
  }

  /// Convert risk score to human-readable level
  /// UPDATED: Now uses 0.5 scale per thesis
  static String getRiskLevel(double score) {
    if (score >= 0.5) return 'Highly Dangerous';
    if (score >= 0.4) return 'High Risk';
    if (score >= 0.3) return 'Moderate Risk';
    if (score >= 0.2) return 'Low Risk';
    return 'Minimal Risk';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'objectName': objectName,
      'hazardLabels': hazardLabels,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'boundingBox': boundingBox.toJson(),
      'confidence': confidence,
      'detectedAt': detectedAt.toIso8601String(),
      'imageSnapshot': imageSnapshot,
      'isNearEdge': isNearEdge,
      'distanceToEdge': distanceToEdge,
    };
  }

  factory HazardObject.fromJson(Map<String, dynamic> json) {
    return HazardObject(
      id: json['id'],
      objectName: json['objectName'],
      hazardLabels: List<String>.from(json['hazardLabels']),
      riskScore: json['riskScore'],
      riskLevel: json['riskLevel'],
      boundingBox: BoundingBox.fromJson(json['boundingBox']),
      confidence: json['confidence'],
      detectedAt: DateTime.parse(json['detectedAt']),
      imageSnapshot: json['imageSnapshot'],
      isNearEdge: json['isNearEdge'] ?? false,
      distanceToEdge: json['distanceToEdge'],
    );
  }

  HazardObject copyWith({
    String? id,
    String? objectName,
    List<String>? hazardLabels,
    double? riskScore,
    String? riskLevel,
    BoundingBox? boundingBox,
    double? confidence,
    DateTime? detectedAt,
    String? imageSnapshot,
    bool? isNearEdge,
    double? distanceToEdge,
  }) {
    return HazardObject(
      id: id ?? this.id,
      objectName: objectName ?? this.objectName,
      hazardLabels: hazardLabels ?? this.hazardLabels,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      boundingBox: boundingBox ?? this.boundingBox,
      confidence: confidence ?? this.confidence,
      detectedAt: detectedAt ?? this.detectedAt,
      imageSnapshot: imageSnapshot ?? this.imageSnapshot,
      isNearEdge: isNearEdge ?? this.isNearEdge,
      distanceToEdge: distanceToEdge ?? this.distanceToEdge,
    );
  }

  @override
  String toString() {
    String edgeInfo = isNearEdge ? ' [NEAR EDGE!]' : '';
    return 'HazardObject($objectName, $riskLevel, ${(confidence * 100).toStringAsFixed(1)}%$edgeInfo)';
  }
}

/// Bounding box with edge detection capabilities
class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  // Getter properties for convenience
  double get centerX => x + (width / 2);
  double get centerY => y + (height / 2);
  double get left => x;
  double get right => x + width;
  double get top => y;
  double get bottom => y + height;

  /// Calculate distance between this box's center and another box's center
  double distanceTo(BoundingBox other) {
    double dx = centerX - other.centerX;
    double dy = centerY - other.centerY;
    return sqrt(dx * dx + dy * dy);
  }

  /// Check if this bounding box is near an edge object
  bool isNearEdge(BoundingBox edgeBox, {double threshold = 0.15}) {
    double distance = distanceTo(edgeBox);
    return distance < threshold;
  }

  /// Check if this object is directly above an edge (risk of falling)
  bool isAboveEdge(BoundingBox edgeBox, {double horizontalOverlap = 0.3}) {
    bool verticallyAligned = (bottom >= edgeBox.top - 0.05) &&
        (bottom <= edgeBox.top + 0.1);

    double overlapLeft = (left > edgeBox.left) ? left : edgeBox.left;
    double overlapRight = (right < edgeBox.right) ? right : edgeBox.right;
    double overlap = overlapRight - overlapLeft;
    bool hasOverlap = overlap > (width * horizontalOverlap);

    return verticallyAligned && hasOverlap;
  }

  /// Get absolute pixel coordinates for given image size
  Map<String, double> getAbsoluteCoordinates(double imageWidth, double imageHeight) {
    return {
      'x': x * imageWidth,
      'y': y * imageHeight,
      'width': width * imageWidth,
      'height': height * imageHeight,
    };
  }

  /// Check if bounding box overlaps with another
  bool overlaps(BoundingBox other) {
    return !(right < other.left ||
        other.right < left ||
        bottom < other.top ||
        other.bottom < top);
  }

  /// Calculate Intersection over Union (IoU) with another box
  double calculateIoU(BoundingBox other) {
    double intersectionLeft = (left > other.left) ? left : other.left;
    double intersectionTop = (top > other.top) ? top : other.top;
    double intersectionRight = (right < other.right) ? right : other.right;
    double intersectionBottom = (bottom < other.bottom) ? bottom : other.bottom;

    double intersectionWidth = intersectionRight - intersectionLeft;
    double intersectionHeight = intersectionBottom - intersectionTop;

    if (intersectionWidth <= 0 || intersectionHeight <= 0) return 0.0;

    double intersectionArea = intersectionWidth * intersectionHeight;
    double box1Area = width * height;
    double box2Area = other.width * other.height;
    double unionArea = box1Area + box2Area - intersectionArea;

    return intersectionArea / unionArea;
  }

  /// Convert to JSON
  Map<String, double> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: json['x'],
      y: json['y'],
      width: json['width'],
      height: json['height'],
    );
  }

  @override
  String toString() {
    return 'BoundingBox(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, w: ${width.toStringAsFixed(3)}, h: ${height.toStringAsFixed(3)})';
  }
}
