/// Static topic-relationship graph for the Mind Map screen: which taxonomy
/// categories are conceptually connected, e.g. "Fines & Black Points"
/// penalizes violations from most other categories, and "Roundabouts &
/// Intersections" shares right-of-way logic with "Traffic Rules & Right of
/// Way" and lane discipline with "Highway Driving".
///
/// This is a curated study aid (not derived from content data) describing
/// how UAE theory-test topics relate to each other, meant to help a learner
/// see the syllabus as a connected whole rather than isolated categories —
/// a differentiator versus theorytestrta.com / yallapass.ae / RTA's own
/// practice tools, none of which visualize topic relationships.
library;

/// categoryId -> list of related categoryIds. The graph is undirected but
/// declared one-directional here; [expandUndirected] mirrors it both ways.
const Map<String, List<String>> _rawRelations = {
  'fines_penalty': [
    'speed_limits',
    'parking_rules',
    'alcohol_fatigue',
    'seatbelt_child_safety',
    'vehicle_docs_insurance',
    'traffic_rules_row',
  ],
  'traffic_rules_row': [
    'roundabouts_intersections',
    'highway_lane',
    'road_signs',
    'alcohol_fatigue',
  ],
  'road_signs': [
    'parking_rules',
    'roundabouts_intersections',
    'speed_limits',
  ],
  'speed_limits': [
    'highway_lane',
  ],
  'roundabouts_intersections': [
    'highway_lane',
  ],
};

/// The category to draw at the centre of the radial diagram — the one with
/// the most connections, matching the brief's "Fines connects to each rule
/// category it penalizes" example.
const String mindMapCentralCategory = 'fines_penalty';

Map<String, Set<String>> _expandUndirected() {
  final map = <String, Set<String>>{};
  for (final entry in _rawRelations.entries) {
    map.putIfAbsent(entry.key, () => {}).addAll(entry.value);
    for (final other in entry.value) {
      map.putIfAbsent(other, () => {}).add(entry.key);
    }
  }
  return map;
}

final Map<String, Set<String>> topicRelations = _expandUndirected();

List<String> relatedCategories(String categoryId) => (topicRelations[categoryId] ?? const {}).toList();
