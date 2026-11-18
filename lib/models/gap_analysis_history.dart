
class GapAnalysisHistory {
  final String id;
  final String jobId;
  final double matchScore;
  final Map<String, dynamic> snapshot;
  final DateTime createdAt;

  const GapAnalysisHistory({
    required this.id,
    required this.jobId,
    required this.matchScore,
    required this.snapshot,
    required this.createdAt,
  });

  String get jobTitle {
    return snapshot['job_title'] as String? ?? 'Unknown job';
  }

  String? get jobSector {
    return snapshot['job_sector'] as String?;
  }

  List<Map<String, dynamic>> get skills {
    final data = snapshot['skills'] as List? ?? [];

    return data.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  factory GapAnalysisHistory.fromMap(Map<String, dynamic> map) {
    return GapAnalysisHistory(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      matchScore: (map['match_score'] as num).toDouble(),
      snapshot: Map<String, dynamic>.from(
        map['analysis_snapshot'] as Map? ?? {},
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
