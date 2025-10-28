// lib/models/risk_classification.dart

import 'hazard_object.dart';
import 'household_danger_index.dart';

/// Complete risk classification system for HEROCS
/// Implements multi-label framework: Categorical + Positional + Contextual
/// Based on thesis requirements for Filipino household hazard detection

class RiskClassification {

  // ========== YOUR 26 UPDATED OBJECT CLASSES ==========
  /// Object classes from HEROCS Roboflow dataset
  static const List<String> objectClasses = [
    'surface_edge',
    'hot_container',
    'electric_wire',
    'fragile_object',
    'electric_plug',
    'cleaning_product',
    'sharp_object',
    'stove',
    'furniture_sharp_corner',
    'appliance_furniture',
    'staircase_no_railing',
    'furniture_low',
    'pharmaceutical',
    'stool',
    'water_bucket',
    'lead_paint',
    'toxic_chemical',
    'hard_object',
    'choking_object',
    'fragile_furniture',
    'gas_container',
    'flammable_object',
    'exposed_metal_bed_frame',
    'furniture_unstable',
    'unprotected_balcony',
    'flammable_liquid',
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
    'fragile',
    'flammable',
    'explosive',
    'drowning',
    'fall_hazard',
    'toxic',
    'structural_hazard',

    // Positional (accessibility based on 96cm threshold) - 3 LEVELS ONLY
    'within_reach',
    'floor_level',
    'elevated',

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

  // ========== EDGE-SENSITIVE OBJECTS ==========
  /// Objects that pose increased fall/breakage risk near edges
  /// Only these objects trigger edge proximity escalation
  static const List<String> edgeSensitiveObjects = [
    'fragile_object',
    'sharp_object',
    'hard_object',
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
    double? objectCenterY, // Normalized Y position in image (0-1)
    // Contextual parameters
    bool? isSecured,
    bool? hasProperStorage,
    bool isNearEdge = false,
    bool isAtEdge = false,
    // Surface association (fallback for height estimation)
    String? associatedSurface, // "surface_edge", "staircase_no_railing", etc.
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
    // Edge proximity detection (ONLY for edge-sensitive objects)
    if (isNearEdge || isAtEdge) {
      if (_isEdgeSensitive(objectClass)) {
        labels.add('near_edge');
        labels.add('fall_risk');
        // Remove low-risk classifications for edge-sensitive objects
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
  /// ALL 26 CLASSES FULLY COVERED
  static List<String> _getInherentHazards(String objectClass) {
    String normalized = objectClass.toLowerCase().trim();

    switch (normalized) {
      // ===== SHARP OBJECTS =====
      case 'sharp_object':
        return ['sharp', 'high_risk'];
      
      case 'furniture_sharp_corner':
        return ['sharp', 'moderate_risk'];

      // ===== CHOKING HAZARDS =====
      case 'choking_object':
        return ['choking', 'high_risk'];

      // ===== ELECTRICAL HAZARDS =====
      case 'electric_plug':
        return ['electrical', 'moderate_risk'];
      
      case 'electric_wire':
        return ['electrical', 'exposed_wiring', 'high_risk'];
      
      case 'exposed_metal_bed_frame':
        return ['electrical', 'hard', 'moderate_risk'];

      // ===== POISONOUS/TOXIC SUBSTANCES =====
      case 'cleaning_product':
        return ['poisonous', 'toxic', 'high_risk'];
      
      case 'pharmaceutical':
        return ['poisonous', 'highly_dangerous'];
      
      case 'toxic_chemical':
        return ['toxic', 'poisonous', 'highly_dangerous'];
      
      case 'lead_paint':
        return ['toxic', 'poisonous', 'moderate_risk'];

      // ===== HOT/BURN HAZARDS =====
      case 'stove':
        return ['hot', 'highly_dangerous'];
      
      case 'hot_container':
        return ['hot', 'high_risk'];

      // ===== FLAMMABLE/EXPLOSIVE =====
      case 'gas_container':
        return ['explosive', 'flammable', 'highly_dangerous'];
      
      case 'flammable_object':
        return ['flammable', 'high_risk'];
      
      case 'flammable_liquid':
        return ['flammable', 'poisonous', 'highly_dangerous'];

      // ===== DROWNING HAZARDS =====
      case 'water_bucket':
        return ['drowning', 'high_risk'];

      // ===== HEAVY/UNSTABLE FURNITURE & APPLIANCES =====
      case 'appliance_furniture':
        return ['heavy', 'electrical', 'moderate_risk'];
      
      case 'furniture_unstable':
        return ['fall_hazard', 'heavy', 'high_risk', 'unsecured'];
      
      case 'stool':
        return ['fall_hazard', 'moderate_risk'];
      
      case 'furniture_low':
        return ['fall_hazard', 'moderate_risk']; // Climbing hazard

      // ===== HARD OBJECTS (BLUNT FORCE INJURY) =====
      case 'hard_object':
        return ['hard', 'moderate_risk'];

      // ===== FRAGILE OBJECTS =====
      case 'fragile_object':
        return ['fragile', 'sharp', 'moderate_risk'];
      
      case 'fragile_furniture':
        return ['fragile', 'fall_hazard', 'moderate_risk'];

      // ===== STRUCTURAL/ENVIRONMENTAL HAZARDS =====
      case 'staircase_no_railing':
        return ['fall_hazard', 'structural_hazard', 'highly_dangerous'];
      
      case 'unprotected_balcony':
        return ['fall_hazard', 'structural_hazard', 'highly_dangerous'];
      
      case 'surface_edge':
        return ['fall_risk', 'structural_hazard', 'moderate_risk'];

      // ===== DEFAULT =====
      default:
        return ['moderate_risk'];
    }
  }

  /// Check if object is edge-sensitive (fragile, sharp, or hard objects only)
  static bool _isEdgeSensitive(String objectClass) {
    return edgeSensitiveObjects.contains(objectClass.toLowerCase().trim());
  }

  // ========== POSITIONAL HELPERS ==========
  /// Get positional labels from associated surface (fallback method)
  static List<String> _getPositionFromSurface(String surface) {
    Map<String, double> surfaceHeights = {
      'staircase_no_railing': 0.0,
      'floor': 0.0,
      'surface_edge': 0.75,
      'furniture_low': 0.5,
    };

    double height = surfaceHeights[surface] ?? 0.5;

    if (height < PositionalDetection.FLOOR_THRESHOLD) {
      return ['floor_level', 'within_reach'];
    } else if (height <= PositionalDetection.CHILD_REACHABLE_HEIGHT) {
      return ['within_reach'];
    } else {
      return ['elevated'];
    }
  }

  // ========== EDGE PROXIMITY DETECTION ==========
  /// Detect spatial relationships between hazards and edges
  /// REFINED: Only applies to edge-sensitive objects (fragile, sharp, hard)
  static List<HazardObject> detectEdgeProximity(
    List<HazardObject> allDetections,
  ) {
    // Separate edge objects from hazards
    List<HazardObject> edges = allDetections.where((obj) =>
        obj.objectName == 'surface_edge'
    ).toList();

    List<HazardObject> hazards = allDetections.where((obj) =>
        obj.objectName != 'surface_edge'
    ).toList();

    List<HazardObject> updatedHazards = [];

    for (var hazard in hazards) {
      bool nearEdge = false;
      double? closestDistance;
      String? associatedSurface;

      // ONLY check edge proximity for edge-sensitive objects
      if (_isEdgeSensitive(hazard.objectName)) {
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
            closestDistance = 0.0; // Directly at edge
            associatedSurface = edge.objectName;
            break;
          }
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
    // First, apply edge proximity detection (only for edge-sensitive objects)
    List<HazardObject> withEdgeContext = detectEdgeProximity(allDetections);

    // Enhance with surface-based height estimation for objects without Y-coord
    List<HazardObject> surfaces = withEdgeContext.where((obj) =>
        ['surface_edge', 'staircase_no_railing', 'furniture_low'].contains(obj.objectName)
    ).toList();

    List<HazardObject> finalHazards = [];

    for (var hazard in withEdgeContext) {
      // Skip if already processed or is a surface
      if (['surface_edge', 'staircase_no_railing', 'furniture_low'].contains(hazard.objectName)) {
        finalHazards.add(hazard);
        continue;
      }

      // If no positional labels yet, try to infer from nearby surfaces
      if (!hazard.hazardLabels.any((label) =>
          ['floor_level', 'within_reach', 'elevated'].contains(label))) {
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

  // ========== RECOMMENDATION GENERATION (ENGLISH ONLY) ==========
  /// Generate English safety recommendations
  /// ALL 26 CLASSES COVERED
  static String getRecommendation(HazardObject hazard) {
    String objectName = hazard.objectName.replaceAll('_', ' ');

    // Priority 1: Edge proximity warning (only for edge-sensitive objects)
    if (hazard.isNearEdge && _isEdgeSensitive(hazard.objectName)) {
      return '⚠️ WARNING: $objectName is near an edge. '
          'Move it to the center of the surface or a safer location to prevent falling.';
    }

    // Priority 2: Structural hazards (stairs/balcony)
    if (hazard.objectName == 'staircase_no_railing') {
      return '🚪 URGENT: Install safety gates at the top and bottom of stairs. '
          'Never leave children unattended near staircases without railings.';
    }

    if (hazard.objectName == 'unprotected_balcony') {
      return '🚪 URGENT: Install proper railing or safety nets on the balcony. '
          'Keep doors locked and never allow children unsupervised access.';
    }

    // Priority 3: Drowning hazard
    if (hazard.hazardLabels.contains('drowning')) {
      return '💧 DANGER: Remove water from buckets immediately after use. '
          'Children can drown in as little as 2 inches of water. Never leave water containers unattended.';
    }

    // Priority 4: Explosive/flammable
    if (hazard.hazardLabels.contains('explosive')) {
      return '💥 EXTREME HAZARD: Store $objectName in a locked outdoor storage area away from '
          'children and heat sources. Ensure proper ventilation and safety protocols.';
    }

    if (hazard.hazardLabels.contains('flammable') && 
        hazard.objectName == 'flammable_liquid') {
      return '🔥 DANGER: Store flammable liquids in approved containers in a locked cabinet '
          'away from children, heat sources, and open flames. Keep out of reach (above 96cm).';
    }

    if (hazard.hazardLabels.contains('flammable')) {
      return '🔥 WARNING: Store $objectName away from heat sources and open flames. '
          'Keep in a high, locked location out of children\'s reach.';
    }

    // Priority 5: Electrical hazards
    if (hazard.hazardLabels.contains('exposed_wiring')) {
      return '⚡ IMMEDIATE DANGER: Repair exposed wiring now. This poses electric shock and fire risks. '
          'Contact a licensed electrician immediately.';
    }

    if (hazard.objectName == 'electric_wire') {
      return '⚡ Secure and cover all electrical wires. Use cord covers or run wires behind furniture. '
          'Keep away from children\'s reach.';
    }

    if (hazard.objectName == 'electric_plug') {
      return '🔌 Install tamper-resistant outlet covers on all accessible electrical outlets. '
          'Use outlet plates to prevent children from inserting objects.';
    }

    if (hazard.objectName == 'exposed_metal_bed_frame') {
      return '⚠️ Cover exposed metal parts of bed frames with padding or guards. '
          'Ensure the frame is grounded to prevent electrical hazards.';
    }

    // Priority 6: Hot/burn hazards
    if (hazard.objectName == 'stove') {
      return '🔥 Install stove guards and use back burners when possible. '
          'Turn pot handles inward. Never leave cooking unattended when children are present.';
    }

    if (hazard.hazardLabels.contains('hot')) {
      return '🔥 Keep $objectName away from children at all times. '
          'Place on elevated surfaces (above 96cm) and use safety barriers if needed.';
    }

    // Priority 7: Poisonous substances
    if (hazard.objectName == 'pharmaceutical') {
      return '💊 Store all medications in a high, locked cabinet (above 96cm). '
          'Use child-proof caps and keep medications in original containers with labels.';
    }

    if (hazard.objectName == 'toxic_chemical') {
      return '☠️ DANGER: Store toxic chemicals in a locked cabinet in a well-ventilated area. '
          'Keep in original containers with warning labels. Consider safer alternatives.';
    }

    if (hazard.objectName == 'lead_paint') {
      return '⚠️ Lead paint poses serious health risks. Cover with safe paint or wallpaper. '
          'Consider professional lead abatement for permanent solution. Keep children away from peeling paint.';
    }

    if (hazard.hazardLabels.contains('poisonous') &&
        hazard.hazardLabels.contains('unsecured')) {
      return '☠️ Store $objectName in a locked cabinet that is high and out of reach. '
          'Ensure it has a child-proof lock.';
    }

    if (hazard.hazardLabels.contains('poisonous')) {
      return '☠️ Keep $objectName in a high, locked location (above 96cm). '
          'Use child-proof containers and store out of sight.';
    }

    // Priority 8: Sharp objects
    if (hazard.hazardLabels.contains('sharp') &&
        hazard.hazardLabels.contains('within_reach')) {
      return '🔪 Store $objectName in a locked drawer or high shelf (above 96cm, out of child\'s reach). '
          'Use safety locks on drawers containing sharp objects.';
    }

    if (hazard.objectName == 'furniture_sharp_corner') {
      return '🛡️ Install corner guards or edge bumpers on sharp furniture corners. '
          'This prevents injuries from falls and collisions.';
    }

    // Priority 9: Choking hazards
    if (hazard.hazardLabels.contains('choking') &&
        hazard.hazardLabels.contains('floor_level')) {
      return '⚠️ Remove small objects like $objectName from the floor immediately. '
          'These can be swallowed by children and cause choking. Keep small items in secure containers.';
    }

    if (hazard.hazardLabels.contains('choking')) {
      return '⚠️ Keep small objects out of reach. Store in high cabinets (above 96cm) or locked containers. '
          'Regularly check floors and low surfaces for choking hazards.';
    }

    // Priority 10: Unstable furniture
    if (hazard.objectName == 'furniture_unstable') {
      return '📦 URGENT: Anchor $objectName to the wall immediately using furniture straps or brackets. '
          'Tip-overs can cause serious injuries or death. Do not allow children to climb on furniture.';
    }

    if (hazard.objectName == 'fragile_furniture') {
      return '⚠️ Secure or remove $objectName. Fragile furniture can break easily and cause cuts or injuries. '
          'Consider replacing with sturdy, child-safe alternatives.';
    }

    if (hazard.objectName == 'stool') {
      return '🪜 Store stools in a secure location when not in use. '
          'Children may use them to climb and reach dangerous objects. Supervise when in use.';
    }

    if (hazard.objectName == 'furniture_low') {
      return '⚠️ Secure low furniture to prevent tipping. Remove or store items on top that children '
          'might try to reach by climbing. Consider corner guards.';
    }

    if (hazard.objectName == 'appliance_furniture') {
      return '📺 Anchor heavy appliances and furniture to the wall. Keep electrical cords secured and out of reach. '
          'Place appliances as far back on surfaces as possible.';
    }

    // Priority 11: Hard objects
    if (hazard.hazardLabels.contains('hard')) {
      return '⚠️ Secure $objectName to prevent falls. Hard objects can cause blunt force injuries. '
          'Store heavy hard objects on low, stable surfaces or secured shelving.';
    }

    // Priority 12: Fragile objects
    if (hazard.hazardLabels.contains('fragile')) {
      return '🔔 Move $objectName to a secure, elevated location (above 96cm). '
          'Fragile items can break and cause cuts or injuries. Use display cases with locks if needed.';
    }

    // Priority 13: Surface edges
    if (hazard.objectName == 'surface_edge') {
      return '⚠️ Install edge guards or bumpers on table/counter edges. '
          'Keep dangerous objects away from edges to prevent falls.';
    }

    // Generic safety message
    return '✅ Ensure $objectName is safe and out of children\'s reach (above 96cm). '
        'Store in a secure location and supervise children during use.';
  }

  /// Determine recommendation priority level
  static RecommendationPriority getRecommendationPriority(HazardObject hazard) {
    // Urgent: Structural hazards
    if (hazard.objectName == 'staircase_no_railing' || 
        hazard.objectName == 'unprotected_balcony') {
      return RecommendationPriority.urgent;
    }

    // Urgent: Edge proximity for edge-sensitive objects
    if (hazard.isNearEdge && _isEdgeSensitive(hazard.objectName)) {
      return RecommendationPriority.urgent;
    }

    // Urgent: Multiple severe hazards
    if ((hazard.hazardLabels.contains('sharp') ||
            hazard.hazardLabels.contains('electrical')) &&
        hazard.hazardLabels.contains('within_reach') &&
        hazard.hazardLabels.contains('unsecured')) {
      return RecommendationPriority.urgent;
    }

    if (hazard.hazardLabels.contains('exposed_wiring') ||
        hazard.hazardLabels.contains('highly_dangerous') ||
        hazard.hazardLabels.contains('explosive') ||
        hazard.hazardLabels.contains('drowning') ||
        hazard.objectName == 'furniture_unstable') {
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
        hazard.hazardLabels.contains('flammable') ||
        (hazard.hazardLabels.contains('heavy') &&
            hazard.hazardLabels.contains('unsecured'))) {
      return RecommendationPriority.important;
    }

    // Suggested: Minor hazards or properly secured
    return RecommendationPriority.suggested;
  }
}

// ========================================================================
// POSITIONAL DETECTION CLASS - 3 LEVELS ONLY
// ========================================================================

/// Image-based height estimation using WHO Child Growth Standards
/// Three-tier system: Floor Level, Within Reach, Elevated
class PositionalDetection {
  // ========== WHO CHILD GROWTH STANDARDS ==========
  /// Reference height: WHO 50th percentile for 36-month-old children
  /// Boys: 96.1cm, Girls: 95.1cm → Average: 96cm
  /// Source: WHO Child Growth Standards 2006
  static const double CHILD_REACHABLE_HEIGHT = 0.96; // 96cm

  /// Camera and environmental constants
  static const double ASSUMED_CAMERA_HEIGHT = 1.5; // Adult chest level (150cm)
  static const double FLOOR_THRESHOLD = 0.3; // Objects below 30cm = floor

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

  /// Classify position based on WHO 96cm threshold (3 levels only)
  static PositionCategory classifyPosition(double estimatedHeight) {
    if (estimatedHeight < FLOOR_THRESHOLD) {
      return PositionCategory.floorLevel; // 0-30cm: On floor
    } else if (estimatedHeight <= CHILD_REACHABLE_HEIGHT) {
      return PositionCategory.withinReach; // 30-96cm: Child can reach
    } else {
      return PositionCategory.elevated; // 96cm+: Safe/elevated
    }
  }

  /// Get positional labels for multi-label classification (3 levels)
  static List<String> getPositionalLabels(double objectCenterY) {
    List<String> labels = [];
    double estimatedHeight = estimateHeightFromImagePosition(objectCenterY);
    PositionCategory category = classifyPosition(estimatedHeight);

    switch (category) {
      case PositionCategory.floorLevel:
        labels.addAll(['floor_level', 'within_reach']); // Floor items are also reachable
        break;
      case PositionCategory.withinReach:
        labels.add('within_reach');
        break;
      case PositionCategory.elevated:
        labels.add('elevated');
        break;
    }

    return labels;
  }

  /// Get human-readable height description (English)
  static String getHeightDescription(double normalizedY) {
    double height = estimateHeightFromImagePosition(normalizedY);
    if (height < FLOOR_THRESHOLD) {
      return 'Floor level';
    } else if (height <= CHILD_REACHABLE_HEIGHT) {
      return 'Within reach - ${(height * 100).toInt()}cm';
    } else {
      return 'Elevated (safe) - ${(height * 100).toInt()}cm';
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
// ENUMS - 3 POSITION CATEGORIES ONLY
// ========================================================================

/// Position categories based on WHO child height standards (3 levels)
enum PositionCategory {
  floorLevel,   // 0-30cm: Immediate danger (on floor)
  withinReach,  // 30-96cm: Accessible to children 0-3 years
  elevated,     // 96cm+: Out of reach (safe)
}

/// Recommendation urgency levels for UI prioritization