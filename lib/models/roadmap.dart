import 'roadmap_item.dart';

enum RoadmapStatus {
  active,
  completed,
  archived,
}

class Roadmap {
  final String id;
  final String studentId;
  final String jobId;
  final String? sourceAnalysisId;
  final String title;
  final RoadmapStatus status;
  final int estimatedWeeks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RoadmapItem> items;

  const Roadmap({
    required this.id,
    required this.studentId,
    required this.jobId,
    this.sourceAnalysisId,
    required this.title,
    required this.status,
    required this.estimatedWeeks,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  int get totalItems => items.length;

  int get completedItems {
    return items.where((item) => item.isCompleted).length;
  }

  int get inProgressItems {
    return items.where((item) => item.isInProgress).length;
  }

  double get progress {
    if (items.isEmpty) {
      return 0;
    }

    return completedItems / totalItems;
  }

  int get progressPercentage {
    return (progress * 100).round();
  }

  bool get isCompleted {
    return status == RoadmapStatus.completed;
  }

  factory Roadmap.fromMap(Map<String, dynamic> map) {
    final itemsData = map['roadmap_items'] as List? ?? [];

    return Roadmap(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      jobId: map['job_id'] as String,
      sourceAnalysisId: map['source_analysis_id'] as String?,
      title: map['title'] as String,
      status: _parseStatus(map['status'] as String?),
      estimatedWeeks: (map['estimated_weeks'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      items: itemsData.map((item) {
        return RoadmapItem.fromMap(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList(),
    );
  }

  static RoadmapStatus _parseStatus(String? value) {
    switch (value) {
      case 'completed':
        return RoadmapStatus.completed;
      case 'archived':
        return RoadmapStatus.archived;
      default:
        return RoadmapStatus.active;
    }
  }

  String get statusValue {
    switch (status) {
      case RoadmapStatus.active:
        return 'active';
      case RoadmapStatus.completed:
        return 'completed';
      case RoadmapStatus.archived:
        return 'archived';
    }
  }

  Roadmap copyWith({
    RoadmapStatus? status,
    List<RoadmapItem>? items,
    DateTime? updatedAt,
  }) {
    return Roadmap(
      id: id,
      studentId: studentId,
      jobId: jobId,
      sourceAnalysisId: sourceAnalysisId,
      title: title,
      status: status ?? this.status,
      estimatedWeeks: estimatedWeeks,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }
}