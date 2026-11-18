enum RoadmapItemStatus {
  planned,
  inProgress,
  completed,
}

enum RoadmapPriority {
  high,
  medium,
  low,
}

class RoadmapItem {
  final String id;
  final String roadmapId;
  final String? skillId;
  final String title;
  final String? description;
  final String? category;
  final int currentLevel;
  final int targetLevel;
  final RoadmapPriority priority;
  final RoadmapItemStatus status;
  final int orderIndex;
  final int estimatedHours;
  final String? learningResource;
  final DateTime? completedAt;
  final DateTime createdAt;

  const RoadmapItem({
    required this.id,
    required this.roadmapId,
    this.skillId,
    required this.title,
    this.description,
    this.category,
    required this.currentLevel,
    required this.targetLevel,
    required this.priority,
    required this.status,
    required this.orderIndex,
    required this.estimatedHours,
    this.learningResource,
    this.completedAt,
    required this.createdAt,
  });

  bool get isCompleted => status == RoadmapItemStatus.completed;

  bool get isInProgress => status == RoadmapItemStatus.inProgress;

  bool get isPlanned => status == RoadmapItemStatus.planned;

  factory RoadmapItem.fromMap(Map<String, dynamic> map) {
    return RoadmapItem(
      id: map['id'] as String,
      roadmapId: map['roadmap_id'] as String,
      skillId: map['skill_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      currentLevel: (map['current_level'] as num?)?.toInt() ?? 0,
      targetLevel: (map['target_level'] as num?)?.toInt() ?? 1,
      priority: _parsePriority(map['priority'] as String?),
      status: _parseStatus(map['status'] as String?),
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
      estimatedHours: (map['estimated_hours'] as num?)?.toInt() ?? 0,
      learningResource: map['learning_resource'] as String?,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static RoadmapPriority _parsePriority(String? value) {
    switch (value) {
      case 'high':
        return RoadmapPriority.high;
      case 'low':
        return RoadmapPriority.low;
      default:
        return RoadmapPriority.medium;
    }
  }

  static RoadmapItemStatus _parseStatus(String? value) {
    switch (value) {
      case 'in_progress':
        return RoadmapItemStatus.inProgress;
      case 'completed':
        return RoadmapItemStatus.completed;
      default:
        return RoadmapItemStatus.planned;
    }
  }

  String get priorityValue {
    switch (priority) {
      case RoadmapPriority.high:
        return 'high';
      case RoadmapPriority.medium:
        return 'medium';
      case RoadmapPriority.low:
        return 'low';
    }
  }

  String get statusValue {
    switch (status) {
      case RoadmapItemStatus.planned:
        return 'planned';
      case RoadmapItemStatus.inProgress:
        return 'in_progress';
      case RoadmapItemStatus.completed:
        return 'completed';
    }
  }

  RoadmapItem copyWith({
    RoadmapItemStatus? status,
    DateTime? completedAt,
  }) {
    return RoadmapItem(
      id: id,
      roadmapId: roadmapId,
      skillId: skillId,
      title: title,
      description: description,
      category: category,
      currentLevel: currentLevel,
      targetLevel: targetLevel,
      priority: priority,
      status: status ?? this.status,
      orderIndex: orderIndex,
      estimatedHours: estimatedHours,
      learningResource: learningResource,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
    );
  }
}