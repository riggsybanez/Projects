// lib/models/household_danger_index.dart

import 'hazard_object.dart';

/// Calculates and manages the Household Danger Index (HDI)
/// Based on the thesis formula: HDI = (Sum of risk scores) / Number of hazards
/// Scale: 0.0 - 0.5 (from thesis Table 1.0)
class HouseholdDangerIndex {
  final List<HazardObject> detectedHazards;
  final DateTime assessmentTime;
  final String? roomName; // Optional: which room was scanned

  HouseholdDangerIndex({
    required this.detectedHazards,
    required this.assessmentTime,
    this.roomName,
  });

  /// Calculate the HDI score (0.0 - 0.5)
  /// Updated to allow full 0.5 range per thesis Table 1.0
  double calculateHDI() {
    if (detectedHazards.isEmpty) return 0.0;
    
    double totalScore = detectedHazards.fold(
      0.0,
      (sum, hazard) => sum + hazard.riskScore,
    );
    
    return totalScore / detectedHazards.length;
  }

  /// Get human-readable interpretation based on thesis Table 1.0
  /// Updated thresholds to match thesis documentation
  String getInterpretation() {
    double hdi = calculateHDI();
    
    if (hdi >= 0.4) return 'Critically Unsafe';  // 0.4-0.5 range
    if (hdi >= 0.3) return 'Highly Unsafe';      // 0.3-0.39 range
    if (hdi >= 0.2) return 'Unsafe';             // 0.2-0.29 range
    if (hdi >= 0.1) return 'Safe';               // 0.1-0.19 range
    return 'No hazards detected';                 // 0.0-0.09 range
  }

  /// Get severity level for UI color coding
  /// Updated to match thesis HDI ranges
  HDISeverity getSeverity() {
    double hdi = calculateHDI();
    
    if (hdi >= 0.4) return HDISeverity.critical;   // Critically Unsafe
    if (hdi >= 0.3) return HDISeverity.high;       // Highly Unsafe
    if (hdi >= 0.2) return HDISeverity.moderate;   // Unsafe
    if (hdi >= 0.1) return HDISeverity.low;        // Safe
    return HDISeverity.safe;                        // No hazards
  }

  /// Get total count of hazards by risk level
  Map<String, int> getHazardCountByLevel() {
    Map<String, int> counts = {
      'Highly Dangerous': 0,
      'High Risk': 0,
      'Moderate Risk': 0,
      'Low Risk': 0,
    };

    for (var hazard in detectedHazards) {
      counts[hazard.riskLevel] = (counts[hazard.riskLevel] ?? 0) + 1;
    }

    return counts;
  }

  /// Get most common hazard types detected
  List<String> getMostCommonHazardTypes() {
    Map<String, int> typeCounts = {};

    for (var hazard in detectedHazards) {
      for (var label in hazard.hazardLabels) {
        typeCounts[label] = (typeCounts[label] ?? 0) + 1;
      }
    }

    // Sort by frequency and return top 5
    var sortedTypes = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedTypes.take(5).map((e) => e.key).toList();
  }

  /// Generate contextual safety recommendations based on detected hazards
  /// Updated priority thresholds to align with 0.5 scale
  List<SafetyRecommendation> generateRecommendations() {
    List<SafetyRecommendation> recommendations = [];

    // If no hazards, return generic safe message
    if (detectedHazards.isEmpty) {
      recommendations.add(SafetyRecommendation(
        message: 'No hazards detected. Great job maintaining a safe home!',
        priority: RecommendationPriority.suggested,
        category: 'General Safety',
        affectedHazards: [],
      ));
      return recommendations;
    }

    // Track which objects we've already given recommendations for
    Set<String> processedObjects = {};

    // Generate recommendations for each detected hazard
    for (var hazard in detectedHazards) {
      String objectKey = '${hazard.objectName}_${hazard.riskLevel}';

      // Skip if we already processed this object type
      if (processedObjects.contains(objectKey)) continue;
      processedObjects.add(objectKey);

      // Determine priority based on UPDATED risk thresholds (0.5 scale)
      RecommendationPriority priority;
      if (hazard.riskScore >= 0.4) {
        priority = RecommendationPriority.urgent;     // Critically dangerous
      } else if (hazard.riskScore >= 0.3) {
        priority = RecommendationPriority.important;  // High risk
      } else {
        priority = RecommendationPriority.suggested;  // Moderate/low
      }

      // Generate recommendation based on object type and hazard labels
      String message = _generateRecommendationMessage(hazard);
      String category = _getCategoryFromLabels(hazard.hazardLabels);

      recommendations.add(SafetyRecommendation(
        message: message,
        priority: priority,
        category: category,
        affectedHazards: [hazard.id],
      ));
    }

    // Add general recommendations based on HDI level (updated thresholds)
    double hdi = calculateHDI();
    if (hdi >= 0.4) {
      recommendations.add(SafetyRecommendation(
        message: 'CRITICAL DANGER LEVEL: Multiple severe hazards detected. '
            'Conduct immediate home safety audit and address all hazards urgently.',
        priority: RecommendationPriority.urgent,
        category: 'General Safety',
        affectedHazards: [],
      ));
    } else if (hdi >= 0.3) {
      recommendations.add(SafetyRecommendation(
        message: 'Multiple hazards detected. Conduct comprehensive home assessment '
            'and create a safety action plan.',
        priority: RecommendationPriority.important,
        category: 'General Safety',
        affectedHazards: [],
      ));
    }

    // Sort by priority (urgent first)
    recommendations.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    return recommendations;
  }

  /// Generate specific recommendation message for a hazard
  String _generateRecommendationMessage(HazardObject hazard) {
    List<String> labels = hazard.hazardLabels;
    String objectName = hazard.objectName.replaceAll('_', ' ');

    // Check for specific hazard types
    if (labels.any((l) => l.toLowerCase().contains('sharp'))) {
      return 'Store $objectName in a locked cabinet or high location out of child\'s reach.';
    }

    if (labels.any((l) => l.toLowerCase().contains('electrical'))) {
      return 'Ensure $objectName is covered and out of reach. Install outlet covers.';
    }

    if (labels.any((l) => l.toLowerCase().contains('choking'))) {
      return 'Remove $objectName from floor and low surfaces to prevent choking hazard.';
    }

    if (labels.any((l) => l.toLowerCase().contains('toxic') ||
        l.toLowerCase().contains('poison'))) {
      return 'Store $objectName in a locked cabinet with child-proof locks and proper labeling.';
    }

    if (labels.any((l) => l.toLowerCase().contains('heavy') ||
        l.toLowerCase().contains('unstable'))) {
      return 'Secure $objectName to the wall or move to stable surface to prevent tipping.';
    }

    if (labels.any((l) => l.toLowerCase().contains('hot') ||
        l.toLowerCase().contains('burn'))) {
      return 'Never leave children unattended near $objectName. Use safety gates if necessary.';
    }

    if (labels.any((l) => l.toLowerCase().contains('edge'))) {
      return 'Install edge protectors on $objectName to prevent injuries.';
    }

    // Default recommendation based on risk level (updated thresholds)
    if (hazard.riskScore >= 0.4) {
      return 'CRITICAL: $objectName poses immediate danger! Remove or secure immediately.';
    } else if (hazard.riskScore >= 0.3) {
      return 'Secure $objectName and implement safety measures.';
    } else {
      return 'Monitor $objectName and ensure it is safe for children.';
    }
  }

  /// Get category from hazard labels
  String _getCategoryFromLabels(List<String> labels) {
    if (labels.any((l) => l.toLowerCase().contains('sharp'))) return 'Sharp Objects';
    if (labels.any((l) => l.toLowerCase().contains('electrical'))) return 'Electrical Safety';
    if (labels.any((l) => l.toLowerCase().contains('choking'))) return 'Choking Prevention';
    if (labels.any((l) => l.toLowerCase().contains('toxic') ||
        l.toLowerCase().contains('poison'))) return 'Poisoning Prevention';
    if (labels.any((l) => l.toLowerCase().contains('heavy') ||
        l.toLowerCase().contains('fall'))) return 'Fall Prevention';
    if (labels.any((l) => l.toLowerCase().contains('burn') ||
        l.toLowerCase().contains('hot'))) return 'Burn Prevention';
    return 'General Safety';
  }

  /// Get overall safety status message (English)
  /// Updated thresholds to match thesis Table 1.0
  String getOverallSafetyMessage() {
    double hdi = calculateHDI();
    
    if (hdi >= 0.4) {
      return 'CRITICAL DANGER! Multiple severe hazards in the home. Immediate action required for family safety.';
    } else if (hdi >= 0.3) {
      return 'Serious hazards detected. Urgent action needed for a safe home environment.';
    } else if (hdi >= 0.2) {
      return 'Some hazards identified. Follow recommendations to improve safety.';
    } else if (hdi >= 0.1) {
      return 'Home is safe! Continue monitoring for ongoing family health and safety.';
    }
    
    return 'No hazards detected. Great job!';
  }

  /// Export assessment as JSON
  Map<String, dynamic> toJson() {
    return {
      'hdi_score': calculateHDI(),
      'interpretation': getInterpretation(),
      'severity': getSeverity().toString(),
      'assessment_time': assessmentTime.toIso8601String(),
      'room_name': roomName,
      'total_hazards': detectedHazards.length,
      'hazard_counts': getHazardCountByLevel(),
      'detected_hazards': detectedHazards.map((h) => h.toJson()).toList(),
      'recommendations': generateRecommendations().map((r) => r.toJson()).toList(),
      'overall_message': getOverallSafetyMessage(),
    };
  }
}

/// Severity levels for UI representation
/// Aligned with thesis Table 1.0 HDI ranges
enum HDISeverity {
  safe,      // 0.0 - 0.1
  low,       // 0.1 - 0.2
  moderate,  // 0.2 - 0.3
  high,      // 0.3 - 0.4
  critical,  // 0.4 - 0.5
}

/// Represents a single safety recommendation
class SafetyRecommendation {
  final String message;
  final RecommendationPriority priority;
  final String category;
  final List<String> affectedHazards; // IDs of hazards this addresses
  bool isCompleted;

  SafetyRecommendation({
    required this.message,
    required this.priority,
    required this.category,
    required this.affectedHazards,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'priority': priority.toString(),
      'category': category,
      'affected_hazards': affectedHazards,
      'is_completed': isCompleted,
    };
  }
}

/// Priority levels for recommendations
enum RecommendationPriority {
  suggested,  // Minor improvements
  important,  // Should address soon
  urgent,     // Immediate action required
}
