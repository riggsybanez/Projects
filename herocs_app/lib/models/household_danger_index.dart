import 'hazard_object.dart';

/// Calculates and manages the Household Danger Index (HDI)
/// Based on the thesis formula: HDI = (Sum of risk scores) / Number of hazards
/// Scale: 0.0 - 0.5+ (from your thesis Table 1.0)
class HouseholdDangerIndex {
  final List<HazardObject> detectedHazards;
  final DateTime assessmentTime;
  final String? roomName;  // Optional: which room was scanned

  HouseholdDangerIndex({
    required this.detectedHazards,
    required this.assessmentTime,
    this.roomName,
  });

  /// Calculate the HDI score (0.0 - 0.5+)
  double calculateHDI() {
    if (detectedHazards.isEmpty) return 0.0;
    
    double totalScore = detectedHazards.fold(
      0.0, 
      (sum, hazard) => sum + hazard.riskScore,
    );
    
    return totalScore / detectedHazards.length;
  }

  /// Get human-readable interpretation based on thesis guidelines
  String getInterpretation() {
    double hdi = calculateHDI();
    
    if (hdi >= 0.4) return 'Critically Unsafe';
    if (hdi >= 0.3) return 'Highly Unsafe';
    if (hdi >= 0.2) return 'Unsafe';
    if (hdi >= 0.1) return 'Safe';
    return 'No hazards detected';
  }

  /// Get severity level for UI color coding
  HDISeverity getSeverity() {
    double hdi = calculateHDI();
    
    if (hdi >= 0.4) return HDISeverity.critical;
    if (hdi >= 0.3) return HDISeverity.high;
    if (hdi >= 0.2) return HDISeverity.moderate;
    if (hdi >= 0.1) return HDISeverity.low;
    return HDISeverity.safe;
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
List<SafetyRecommendation> generateRecommendations() {
  List<SafetyRecommendation> recommendations = [];
  
  // If no hazards, return generic safe message
  if (detectedHazards.isEmpty) {
    recommendations.add(SafetyRecommendation(
      message: 'Walang nakitang panganib. Magandang trabaho sa pagpapanatili ng ligtas na tahanan!',
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
    
    // Determine priority based on risk level
    RecommendationPriority priority;
    if (hazard.riskScore >= 0.4) {
      priority = RecommendationPriority.urgent;
    } else if (hazard.riskScore >= 0.3) {
      priority = RecommendationPriority.important;
    } else {
      priority = RecommendationPriority.suggested;
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
  
  // Add general recommendations based on HDI level
  double hdi = calculateHDI();
  if (hdi >= 0.3) {
    recommendations.add(SafetyRecommendation(
      message: 'Maraming panganib ang nakita. Magsagawa ng kabuuang pagsusuri ng bahay at gumawa ng safety checklist.',
      priority: RecommendationPriority.urgent,
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
  String objectName = hazard.objectName;
  
  // Check for specific hazard types
  if (labels.any((l) => l.toLowerCase().contains('sharp'))) {
    return 'I-tago ang ${objectName} sa locked cabinet o mataas na lugar na hindi maaabot ng bata.';
  }
  
  if (labels.any((l) => l.toLowerCase().contains('electrical'))) {
    return 'Siguraduhing naka-cover ang ${objectName} at hindi maaabot ng bata. Install outlet covers.';
  }
  
  if (labels.any((l) => l.toLowerCase().contains('choking'))) {
    return 'Alisin ang ${objectName} sa sahig at mababang surfaces para maiwasan ang choking hazard.';
  }
  
  if (labels.any((l) => l.toLowerCase().contains('toxic') || 
                        l.toLowerCase().contains('poison'))) {
    return 'I-store ang ${objectName} sa locked cabinet with child-proof locks at tamang labeling.';
  }
  
  if (labels.any((l) => l.toLowerCase().contains('heavy') || 
                        l.toLowerCase().contains('unstable'))) {
    return 'I-secure ang ${objectName} sa pader o ilipat sa stable na surface para maiwasan ang pagbagsak.';
  }
  
  if (labels.any((l) => l.toLowerCase().contains('hot') || 
                        l.toLowerCase().contains('burn'))) {
    return 'Huwag iwanang nag-iisa ang bata malapit sa ${objectName}. Use safety gates kung kinakailangan.';
  }
  
  if (labels.any((l) => l.toLowerCase().contains('slip') || 
                        l.toLowerCase().contains('trip'))) {
    return 'Linisin ang walkway at i-secure ang ${objectName} para maiwasan ang pagkadulas o pagtisod.';
  }
  
  if (labels.any((l) => l.toLowerCase().contains('edge'))) {
    return 'Lagyan ng edge protectors ang ${objectName} para maiwasan ang mga sugat.';
  }
  
  // Default recommendation based on risk level
  if (hazard.riskScore >= 0.4) {
    return 'Delikado ang ${objectName}! Agarang tanggalin o i-secure ang item na ito.';
  } else if (hazard.riskScore >= 0.3) {
    return 'I-secure ang ${objectName} at lagyan ng safety measures.';
  } else {
    return 'Bantayan ang ${objectName} at siguraduhing ligtas para sa mga bata.';
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
  if (labels.any((l) => l.toLowerCase().contains('slip') || 
                        l.toLowerCase().contains('trip'))) return 'Fall Prevention';
  
  return 'General Safety';
}


  /// Get overall safety status message for Filipino context
  String getFilipinoCulturalMessage() {
    double hdi = calculateHDI();
    
    if (hdi >= 0.4) {
      return 'Delikado! Maraming panganib sa bahay. Aksyunan kaagad para sa kaligtasan ng pamilya.';
    } else if (hdi >= 0.3) {
      return 'May mga seryosong panganib. Kailangan ng agarang aksyon para sa ligtas na tahanan.';
    } else if (hdi >= 0.2) {
      return 'May ilang panganib na nakita. Sundin ang mga rekomendasyon para mas ligtas.';
    } else if (hdi >= 0.1) {
      return 'Ligtas ang bahay! Patuloy na magbantay para sa kalusugan ng pamilya.';
    }
    return 'Walang nakitang panganib. Magandang trabaho!';
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
      'filipino_message': getFilipinoCulturalMessage(),
    };
  }
}


/// Severity levels for UI representation
enum HDISeverity {
  safe,      // 0.0 - 0.1
  low,       // 0.1 - 0.2
  moderate,  // 0.2 - 0.3
  high,      // 0.3 - 0.4
  critical,  // 0.4+
}


/// Represents a single safety recommendation
class SafetyRecommendation {
  final String message;
  final RecommendationPriority priority;
  final String category;
  final List<String> affectedHazards;  // IDs of hazards this addresses
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
  suggested,   // Minor improvements
  important,   // Should address soon
  urgent,      // Immediate action required
}
