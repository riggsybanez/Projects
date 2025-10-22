// lib/models/risk_classification.dart
import 'hazard_object.dart';
import 'household_danger_index.dart';

/// Complete risk classification system for HEROCS
/// Implements multi-label framework: Categorical + Positional + Contextual
/// Based on thesis requirements for Filipino household hazard detection
class RiskClassification {
  
  // ========== YOUR 20 ACTUAL OBJECT CLASSES ==========
  
  /// Object classes from HEROCS Roboflow dataset
  static const List<String> objectClasses = [
    'Choking_Object',
    'Cleaning Product',
    'Electrical_Object',
    'Heavy_Object',
    'Medicine',
    'Poison_Object',
    'Stove',
    'appliance',
    'electric_plug',
    'electric_wire',
    'hard_object',
    'hot_container',
    'knife',
    'liquid_heat_source',
    'scissors',
    'sharp_object',
    'shelf_edge',
    'small_object',
    'staircase',
    'table_edge',
  ];

  // ========== MULTI-LABEL FRAMEWORK CATEGORIES ==========
  
  /// All possible contextual hazard labels for multi-label classification
  static const List<String> contextualLabels = [
    // Categorical (inherent hazard properties)
    'sharp',
    'hot',
    'electrical',
    'poisonous',
    'choking',
    'heavy',
    'hard',
    
    // Positional (accessibility based on 96cm threshold)
    'within_reach',
    'floor_level',
    'elevated',
    'mid_level',
    
    // Contextual (spatial relationships & security)
    'near_edge',
    'at_edge',
    'fall_risk',
    'unsecured',
    'secured',
    'stored_properly',
    
    // Electrical-specific
    'exposed_wiring',
    'live_current',
    
    // Composite risk levels
    'highly_dangerous',
    'high_risk',
    'moderate_risk',
    'low_risk',
  ];

  // ========== MAIN LABEL ASSIGNMENT FUNCTION ==========
  
  /// Assign multi-label hazard classifications based on object and context
  /// Implements three-dimensional framework from thesis:
  /// 1. Categorical (what type of hazard)
  /// 2. Positional (can child reach it)
  /// 3. Contextual (spatial relationships, security state)
  static List<String> assignHazardLabels(
    String objectClass, {
    // Positional parameters
    double? objectCenterY,           // Normalized Y position in image (0-1)
    
    // Contextual parameters
    bool? isSecured,
    bool? hasProperStorage,
    bool isNearEdge = false,
    bool isAtEdge = false,
    
    // Surface association (fallback for height estimation)
    String? associatedSurface,       // "table_edge", "shelf_edge", etc.
  }) {
    List<String> labels = [];

    // 1. CATEGORICAL: Get inherent hazard properties
    labels.addAll(_getInherentHazards(objectClass));

    // 2. POSITIONAL: Determine accessibility based on 96cm threshold
    if (objectCenterY != null) {
      labels.addAll(PositionalDetection.getPositionalLabels(objectCenterY));
    } else if (associatedSurface != null) {
      // Fallback: Use surface association
      labels.addAll(_getPositionFromSurface(associatedSurface));
    }

    // 3. CONTEXTUAL: Spatial relationships and security state
    
    // Edge proximity detection (your innovation)
    if (isNearEdge || isAtEdge) {
      labels.add('near_edge');
      
      // Escalate risk if dangerous object is near edge
      if (_isDangerousObject(objectClass)) {
        labels.add('fall_risk');
        // Remove low-risk classifications
        labels.remove('low_risk');
      }
    }

    // Security state
    if (isSecured == false) {
      labels.add('unsecured');
    } else if (isSecured == true) {
      labels.add('secured');
    }

    if (hasProperStorage == true) {
      labels.add('stored_properly');
    }

    // Remove duplicates and return
    return labels.toSet().toList();
  }

  // ========== CATEGORICAL HAZARD DETECTION ==========
  
  /// Get inherent hazard properties based on object class
  /// Returns categorical labels (sharp, hot, electrical, poisonous, etc.)
  static List<String> _getInherentHazards(String objectClass) {
    String normalized = objectClass.toLowerCase().trim();
    
    switch (normalized) {
      // Sharp objects
      case 'knife':
        return ['sharp', 'high_risk'];
      
      case 'scissors':
        return ['sharp', 'high_risk'];
      
      case 'sharp_object':
        return ['sharp', 'high_risk'];

      // Choking hazards
      case 'choking_object':
        return ['choking', 'high_risk'];
      
      case 'small_object':
        return ['choking', 'moderate_risk'];

      // Electrical hazards
      case 'electrical_object':
        return ['electrical', 'moderate_risk'];
      
      case 'electric_plug':
        return ['electrical', 'moderate_risk'];

      case 'electric_wire':
        return ['electrical', 'exposed_wiring', 'high_risk'];

      // Poisonous/toxic substances
      case 'cleaning product':
        return ['poisonous', 'high_risk'];
      
      case 'poison_object':
        return ['poisonous', 'highly_dangerous'];

      case 'medicine':
        return ['poisonous', 'moderate_risk'];

      // Hot/burn hazards
      case 'stove':
        return ['hot', 'highly_dangerous'];
      
      case 'hot_container':
        return ['hot', 'high_risk'];
      
      case 'liquid_heat_source':
        return ['hot', 'high_risk'];

      // Heavy objects
      case 'heavy_object':
        return ['heavy', 'moderate_risk'];
      
      case 'appliance':
        return ['heavy', 'electrical', 'moderate_risk'];

      // Hard objects (blunt force injury)
      case 'hard_object':
        return ['hard', 'moderate_risk'];

      // Structural/environmental hazards
      case 'staircase':
        return ['fall_hazard', 'highly_dangerous'];

      case 'shelf_edge':
      case 'table_edge':
        return ['edge_hazard', 'low_risk'];

      default:
        return ['moderate_risk'];
    }
  }

  /// Check if object is inherently dangerous (for edge proximity escalation)
  static bool _isDangerousObject(String objectClass) {
    const dangerous = [
      'knife',
      'scissors',
      'sharp_object',
      'hot_container',
      'stove',
      'liquid_heat_source',
      'cleaning product',
      'poison_object',
      'medicine',
      'electric_wire',
      'heavy_object',
      'choking_object',
    ];
    return dangerous.contains(objectClass.toLowerCase().trim());
  }

  // ========== POSITIONAL HELPERS ==========
  
  /// Get positional labels from associated surface (fallback method)
  static List<String> _getPositionFromSurface(String surface) {
    Map<String, double> surfaceHeights = {
      'staircase': 0.0,
      'floor': 0.0,
      'table_edge': 0.75,
      'shelf_edge': 1.5,
    };

    double height = surfaceHeights[surface] ?? 0.5;
    
    if (height < PositionalDetection.FLOOR_THRESHOLD) {
      return ['floor_level', 'within_reach'];
    } else if (height <= PositionalDetection.CHILD_REACHABLE_HEIGHT) {
      return ['within_reach'];
    } else if (height <= PositionalDetection.ELEVATED_THRESHOLD) {
      return ['mid_level'];
    } else {
      return ['elevated'];
    }
  }

  // ========== EDGE PROXIMITY DETECTION ==========
  
  /// Detect spatial relationships between hazards and edges
  /// Implements edge proximity innovation for fall risk detection
  static List<HazardObject> detectEdgeProximity(
    List<HazardObject> allDetections,
  ) {
    // Separate edge objects from hazards
    List<HazardObject> edges = allDetections.where((obj) => 
      obj.objectName == 'table_edge' || obj.objectName == 'shelf_edge'
    ).toList();

    List<HazardObject> hazards = allDetections.where((obj) => 
      obj.objectName != 'table_edge' && obj.objectName != 'shelf_edge'
    ).toList();

    List<HazardObject> updatedHazards = [];

    for (var hazard in hazards) {
      bool nearEdge = false;
      double? closestDistance;
      String? associatedSurface;

      // Check proximity to each edge
      for (var edge in edges) {
        double distance = hazard.boundingBox.distanceTo(edge.boundingBox);
        
        // Check if near edge (within 15% of image dimensions)
        if (hazard.boundingBox.isNearEdge(edge.boundingBox, threshold: 0.15)) {
          nearEdge = true;
          closestDistance = distance;
          associatedSurface = edge.objectName;
          break;
        }

        // Check if object is directly above edge (high fall risk)
        if (hazard.boundingBox.isAboveEdge(edge.boundingBox)) {
          nearEdge = true;
          closestDistance = 0.0;  // Directly at edge
          associatedSurface = edge.objectName;
          break;
        }
      }

      if (nearEdge) {
        // Re-assign labels with edge context
        List<String> newLabels = assignHazardLabels(
          hazard.objectName,
          objectCenterY: hazard.boundingBox.centerY,
          isNearEdge: true,
          associatedSurface: associatedSurface,
        );

        // Recalculate risk with edge proximity
        double newRiskScore = HazardObject.calculateRiskScore(newLabels, true);
        String newRiskLevel = HazardObject.getRiskLevel(newRiskScore);

        updatedHazards.add(hazard.copyWith(
          hazardLabels: newLabels,
          riskScore: newRiskScore,
          riskLevel: newRiskLevel,
          isNearEdge: true,
          distanceToEdge: closestDistance,
        ));
      } else {
        updatedHazards.add(hazard);
      }
    }

    // Return updated hazards + original edges
    return [...updatedHazards, ...edges];
  }

  // ========== COMPLETE SPATIAL CONTEXT DETECTION ==========
  
  /// Master function: Applies all spatial context detection
  /// Combines positional detection + edge proximity + surface association
  static List<HazardObject> detectSpatialContext(
    List<HazardObject> allDetections,
  ) {
    // First, apply edge proximity detection
    List<HazardObject> withEdgeContext = detectEdgeProximity(allDetections);

    // Enhance with surface-based height estimation for objects without Y-coord
    List<HazardObject> surfaces = withEdgeContext.where((obj) => 
      ['table_edge', 'shelf_edge', 'staircase'].contains(obj.objectName)
    ).toList();

    List<HazardObject> finalHazards = [];

    for (var hazard in withEdgeContext) {
      // Skip if already processed or is a surface
      if (['table_edge', 'shelf_edge', 'staircase'].contains(hazard.objectName)) {
        finalHazards.add(hazard);
        continue;
      }

      // If no positional labels yet, try to infer from nearby surfaces
      if (!hazard.hazardLabels.any((label) => 
          ['floor_level', 'within_reach', 'elevated', 'mid_level'].contains(label))) {
        
        String? nearestSurface = _findNearestSurface(hazard, surfaces);
        
        if (nearestSurface != null) {
          List<String> enhancedLabels = List.from(hazard.hazardLabels);
          enhancedLabels.addAll(_getPositionFromSurface(nearestSurface));
          
          // Recalculate risk
          double newRiskScore = HazardObject.calculateRiskScore(
            enhancedLabels, 
            hazard.isNearEdge
          );
          String newRiskLevel = HazardObject.getRiskLevel(newRiskScore);

          finalHazards.add(hazard.copyWith(
            hazardLabels: enhancedLabels,
            riskScore: newRiskScore,
            riskLevel: newRiskLevel,
          ));
          continue;
        }
      }

      finalHazards.add(hazard);
    }

    return finalHazards;
  }

  /// Find nearest surface to a hazard object
  static String? _findNearestSurface(
    HazardObject hazard, 
    List<HazardObject> surfaces
  ) {
    if (surfaces.isEmpty) return null;

    HazardObject nearest = surfaces.reduce((a, b) {
      double distA = hazard.boundingBox.distanceTo(a.boundingBox);
      double distB = hazard.boundingBox.distanceTo(b.boundingBox);
      return distA < distB ? a : b;
    });

    // Only consider if reasonably close (within 30% of image)
    if (hazard.boundingBox.distanceTo(nearest.boundingBox) < 0.3) {
      return nearest.objectName;
    }

    return null;
  }

  // ========== RECOMMENDATION GENERATION ==========
  
  /// Generate Filipino-contextualized safety recommendation
  static String getRecommendation(HazardObject hazard) {
    // Priority 1: Edge proximity warning
    if (hazard.isNearEdge) {
      return '⚠️ PELIGRO: Ang ${hazard.objectName} ay malapit sa gilid. '
             'Ilipat ito sa gitna ng mesa o sa mas ligtas na lugar para hindi mahulog.';
    }

    // Priority 2: Sharp + within reach
    if (hazard.hazardLabels.contains('sharp') && 
        hazard.hazardLabels.contains('within_reach')) {
      return '🔪 Itago ang ${hazard.objectName} sa loob ng locked drawer o mataas na shelf '
             '(hindi maaabot ng bata na 96cm ang taas).';
    }

    // Priority 3: Choking + floor level
    if (hazard.hazardLabels.contains('choking') && 
        hazard.hazardLabels.contains('floor_level')) {
      return '⚠️ Alisin kaagad ang maliliit na bagay tulad ng ${hazard.objectName} sa sahig. '
             'Pwedeng makainin ng bata at mabara sa lalamunan.';
    }

    // Priority 4: Hot containers
    if (hazard.hazardLabels.contains('hot')) {
      return '🔥 Panatilihing malayo sa mga bata ang ${hazard.objectName}. '
             'Gumamit ng safety barriers o ilagay sa hindi maaabot na lugar (higit sa 96cm).';
    }

    // Priority 5: Poisonous + unsecured
    if (hazard.hazardLabels.contains('poisonous') && 
        hazard.hazardLabels.contains('unsecured')) {
      return '☠️ Ilagay ang ${hazard.objectName} sa locked cabinet na matataas at hindi '
             'maaabot ng bata. Siguruhing may child-proof lock.';
    }

    // Priority 6: Electrical hazards
    if (hazard.hazardLabels.contains('electrical')) {
      if (hazard.hazardLabels.contains('exposed_wiring')) {
        return '⚡ PELIGRO! Ayusin kaagad ang exposed wiring. Baka makuryente ang bata o '
               'magdulot ng sunog.';
      }
      return '🔌 I-cover ang electrical outlets gamit outlet protectors. '
             'Itago ang mga wires at ${hazard.objectName}.';
    }

    // Priority 7: Heavy objects
    if (hazard.hazardLabels.contains('heavy') && 
        hazard.hazardLabels.contains('unsecured')) {
      return '📦 I-secure ang ${hazard.objectName} sa dingding gamit furniture straps. '
             'Maaaring bumagsak at makasakit ng bata.';
    }

    // Priority 8: Stairs
    if (hazard.objectName == 'staircase') {
      return '🚪 Maglagay ng safety gate sa taas at baba ng hagdan. '
             'Huwag iwanang mag-isa ang bata malapit sa hagdan.';
    }

    // Generic safety message
    return '✅ Siguraduhing ligtas at hindi maaabot ng mga bata (96cm pataas) ang ${hazard.objectName}.';
  }

  /// Determine recommendation priority level
  static RecommendationPriority getRecommendationPriority(HazardObject hazard) {
    // Urgent: Multiple severe hazards or edge proximity
    if (hazard.isNearEdge && _isDangerousObject(hazard.objectName)) {
      return RecommendationPriority.urgent;
    }

    if ((hazard.hazardLabels.contains('sharp') || 
         hazard.hazardLabels.contains('electrical')) &&
        hazard.hazardLabels.contains('within_reach') &&
        hazard.hazardLabels.contains('unsecured')) {
      return RecommendationPriority.urgent;
    }

    if (hazard.hazardLabels.contains('exposed_wiring') ||
        hazard.hazardLabels.contains('highly_dangerous')) {
      return RecommendationPriority.urgent;
    }

    if (hazard.hazardLabels.contains('choking') && 
        hazard.hazardLabels.contains('floor_level')) {
      return RecommendationPriority.urgent;
    }

    // Important: Single severe or multiple moderate hazards
    if (hazard.hazardLabels.contains('sharp') || 
        hazard.hazardLabels.contains('hot') ||
        hazard.hazardLabels.contains('poisonous') ||
        (hazard.hazardLabels.contains('heavy') && 
         hazard.hazardLabels.contains('unsecured'))) {
      return RecommendationPriority.important;
    }

    // Suggested: Minor hazards or properly secured
    return RecommendationPriority.suggested;
  }
}


// ========================================================================
// POSITIONAL DETECTION CLASS
// ========================================================================

/// Image-based height estimation using WHO Child Growth Standards
/// Single threshold system: 96cm (3-year-old median height)
class PositionalDetection {
  
  // ========== WHO CHILD GROWTH STANDARDS ==========
  
  /// Reference height: WHO 50th percentile for 36-month-old children
  /// Boys: 96.1cm, Girls: 95.1cm → Average: 96cm
  /// Source: WHO Child Growth Standards 2006
  static const double CHILD_REACHABLE_HEIGHT = 0.96;  // 96cm
  
  /// Camera and environmental constants
  static const double ASSUMED_CAMERA_HEIGHT = 1.5;    // Adult chest level (150cm)
  static const double FLOOR_THRESHOLD = 0.3;          // Objects below 30cm = floor
  static const double ELEVATED_THRESHOLD = 1.2;       // Above 120cm = elevated/safe
  
  // ========== HEIGHT ESTIMATION ==========
  
  /// Convert object's Y position in image to estimated real-world height
  /// 
  /// Assumption: User holds phone at chest level (1.5m) horizontally
  /// Linear interpolation: y=0.0 (top) → 1.5m, y=1.0 (bottom) → 0m
  /// 
  /// @param normalizedY: Object center Y coordinate (0.0 = top, 1.0 = bottom)
  /// @returns: Estimated height in meters from floor
  static double estimateHeightFromImagePosition(double normalizedY) {
    return ASSUMED_CAMERA_HEIGHT * (1.0 - normalizedY);
  }
  
  /// Classify position based on WHO 96cm threshold
  static PositionCategory classifyPosition(double estimatedHeight) {
    if (estimatedHeight < FLOOR_THRESHOLD) {
      return PositionCategory.floorLevel;      // 0-30cm: On floor
    } else if (estimatedHeight <= CHILD_REACHABLE_HEIGHT) {
      return PositionCategory.withinReach;     // 30-96cm: Child can reach
    } else if (estimatedHeight <= ELEVATED_THRESHOLD) {
      return PositionCategory.midLevel;        // 96-120cm: Just above reach
    } else {
      return PositionCategory.elevated;        // 120cm+: Safe/elevated
    }
  }
  
  /// Get positional labels for multi-label classification
  static List<String> getPositionalLabels(double objectCenterY) {
    List<String> labels = [];
    double estimatedHeight = estimateHeightFromImagePosition(objectCenterY);
    PositionCategory category = classifyPosition(estimatedHeight);
    
    switch (category) {
      case PositionCategory.floorLevel:
        labels.addAll(['floor_level', 'within_reach']);
        break;
      case PositionCategory.withinReach:
        labels.add('within_reach');
        break;
      case PositionCategory.midLevel:
        labels.add('mid_level');
        break;
      case PositionCategory.elevated:
        labels.add('elevated');
        break;
    }
    
    return labels;
  }
  
  /// Get human-readable height description (Filipino)
  static String getHeightDescription(double normalizedY) {
    double height = estimateHeightFromImagePosition(normalizedY);
    
    if (height < FLOOR_THRESHOLD) {
      return 'Sa sahig (Floor level)';
    } else if (height <= CHILD_REACHABLE_HEIGHT) {
      return 'Maaabot ng bata (Within reach) - ${(height * 100).toInt()}cm';
    } else if (height <= ELEVATED_THRESHOLD) {
      return 'Medyo mataas (Mid level) - ${(height * 100).toInt()}cm';
    } else {
      return 'Ligtas na taas (Elevated) - ${(height * 100).toInt()}cm';
    }
  }
  
  /// Calculate Y-coordinate threshold for "within reach" zone
  /// Used for visual overlay on camera screen (draws line at 96cm)
  /// 
  /// @returns: Y coordinate (0-1) where 96cm line should be drawn
  static double getReachableZoneYThreshold() {
    // Y = 1.0 - (height / cameraHeight)
    return 1.0 - (CHILD_REACHABLE_HEIGHT / ASSUMED_CAMERA_HEIGHT);
    // = 1.0 - (0.96 / 1.5) = 1.0 - 0.64 = 0.36
  }
}


// ========================================================================
// ENUMS
// ========================================================================

/// Position categories based on WHO child height standards
enum PositionCategory {
  floorLevel,    // 0-30cm: Immediate danger
  withinReach,   // 30-96cm: Accessible to children 0-3 years
  midLevel,      // 96-120cm: Marginally safe
  elevated,      // 120cm+: Out of reach
}
