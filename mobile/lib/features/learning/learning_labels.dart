/// Human-friendly labels for learning/evidence states, kept in one place so
/// the product voice stays consistent (observational, never causal).
library;

/// Short evidence chip labels by backend evidence level.
String evidenceShortLabel(String level) => switch (level.toUpperCase()) {
      'STRONG' || 'HIGH' => 'Stronger signal',
      'MODERATE' || 'MEDIUM' => 'Building signal',
      'WEAK' || 'LOW' => 'Early signal',
      _ => 'Not enough data',
    };

/// Friendly label for a personal-learning evidence_state.
String evidenceStateLabel(String state) => switch (state) {
      'positive' => 'Seemed helpful',
      'negative' => 'Seemed not helpful',
      'mixed' => 'Mixed signals',
      'neutral' => 'No clear signal',
      _ => 'Not enough data',
    };

/// The honest caveat shown alongside every personal observation.
const String learningDisclaimer =
    'This is an observation from your own data - correlation only, not proof.';
