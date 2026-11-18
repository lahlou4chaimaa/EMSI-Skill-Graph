import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/job.dart';
import '../../../models/roadmap.dart';
import '../../../models/roadmap_item.dart';
import '../../../models/skill_gap_analysis_result.dart';

class RoadmapService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _studentId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    return user.id;
  }

  Future<List<Roadmap>> getMyRoadmaps() async {
    final data = await _client
        .from('student_roadmaps')
        .select('''
          id,
          student_id,
          job_id,
          source_analysis_id,
          title,
          status,
          estimated_weeks,
          created_at,
          updated_at,
          roadmap_items (
            id,
            roadmap_id,
            skill_id,
            title,
            description,
            category,
            current_level,
            target_level,
            priority,
            status,
            order_index,
            estimated_hours,
            learning_resource,
            completed_at,
            created_at
          )
        ''')
        .eq('student_id', _studentId)
        .order('created_at', ascending: false);

    return data.map<Roadmap>((item) {
      return Roadmap.fromMap(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  Future<Roadmap> getRoadmapById(String roadmapId) async {
    final data = await _client
        .from('student_roadmaps')
        .select('''
          id,
          student_id,
          job_id,
          source_analysis_id,
          title,
          status,
          estimated_weeks,
          created_at,
          updated_at,
          roadmap_items (
            id,
            roadmap_id,
            skill_id,
            title,
            description,
            category,
            current_level,
            target_level,
            priority,
            status,
            order_index,
            estimated_hours,
            learning_resource,
            completed_at,
            created_at
          )
        ''')
        .eq('id', roadmapId)
        .eq('student_id', _studentId)
        .single();

    return Roadmap.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  Future<Roadmap> createRoadmap({
    required Job job,
    required SkillGapAnalysisResult analysis,
    String? sourceAnalysisId,
  }) async {
    final gaps = [...analysis.skillsToImprove, ...analysis.missingSkills];

    if (gaps.isEmpty) {
      throw StateError(
        'No missing or improvable skills were found for this career.',
      );
    }

    final estimatedWeeks = _calculateEstimatedWeeks(gaps);

    final roadmapData = await _client
        .from('student_roadmaps')
        .insert({
          'student_id': _studentId,
          'job_id': job.id,
          'source_analysis_id': sourceAnalysisId,
          'title': 'Roadmap — ${job.title}',
          'status': 'active',
          'estimated_weeks': estimatedWeeks,
        })
        .select()
        .single();

    final roadmapId = roadmapData['id'] as String;

    final items = _buildRoadmapItems(
      roadmapId: roadmapId,
      gaps: gaps,
    );

    if (items.isNotEmpty) {
      await _client
          .from('roadmap_items')
          .insert(items);
    }

    return getRoadmapById(roadmapId);
  }

  Future<void> updateItemStatus({
    required String itemId,
    required RoadmapItemStatus status,
  }) async {
    final completedAt =
        status == RoadmapItemStatus.completed
            ? DateTime.now().toUtc().toIso8601String()
            : null;

    await _client
        .from('roadmap_items')
        .update({
          'status': _statusToDatabaseValue(status),
          'completed_at': completedAt,
        })
        .eq('id', itemId);

    await _refreshRoadmapStatusFromItems(itemId);
  }

  Future<void> deleteRoadmap(String roadmapId) async {
    await _client
        .from('student_roadmaps')
        .delete()
        .eq('id', roadmapId)
        .eq('student_id', _studentId);
  }

  Future<void> archiveRoadmap(String roadmapId) async {
    await _client
        .from('student_roadmaps')
        .update({
          'status': 'archived',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', roadmapId)
        .eq('student_id', _studentId);
  }

  List<Map<String, dynamic>> _buildRoadmapItems({
    required String roadmapId,
    required List<dynamic> gaps,
  }) {
    final sortedGaps = [...gaps];

    sortedGaps.sort((a, b) {
      final priorityA = _priorityScore(a);
      final priorityB = _priorityScore(b);

      if (priorityA != priorityB) {
        return priorityB.compareTo(priorityA);
      }

      return a.skill.name.compareTo(b.skill.name);
    });

    return List.generate(sortedGaps.length, (index) {
      final gap = sortedGaps[index];

      final priority = _calculatePriority(
        currentLevel: gap.currentLevel,
        requiredLevel: gap.requiredLevel,
      );

      final estimatedHours = _calculateEstimatedHours(
        currentLevel: gap.currentLevel,
        requiredLevel: gap.requiredLevel,
      );

      return {
        'roadmap_id': roadmapId,
        'skill_id': gap.skill.id,
        'title': gap.skill.name,
        'description': _buildDescription(gap),
        'category': gap.skill.category,
        'current_level': gap.currentLevel,
        'target_level': gap.requiredLevel,
        'priority': priority,
        'status': 'planned',
        'order_index': index,
        'estimated_hours': estimatedHours,
        'learning_resource': null,
      };
    });
  }

  String _buildDescription(dynamic gap) {
    final skillDescription = gap.skill.description;

    if (skillDescription != null &&
        skillDescription.trim().isNotEmpty) {
      return skillDescription;
    }

    if (gap.currentLevel == 0) {
      return 'Learn the fundamentals of ${gap.skill.name} and build practical experience.';
    }

    return 'Improve ${gap.skill.name} from level ${gap.currentLevel} to level ${gap.requiredLevel}.';
  }

  String _calculatePriority({
    required int currentLevel,
    required int requiredLevel,
  }) {
    final difference = requiredLevel - currentLevel;

    if (currentLevel == 0 && requiredLevel >= 4) {
      return 'high';
    }

    if (difference >= 3) {
      return 'high';
    }

    if (difference == 2) {
      return 'medium';
    }

    return 'low';
  }

  int _priorityScore(dynamic gap) {
    final priority = _calculatePriority(
      currentLevel: gap.currentLevel,
      requiredLevel: gap.requiredLevel,
    );

    switch (priority) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      default:
        return 1;
    }
  }

  int _calculateEstimatedHours({
    required int currentLevel,
    required int requiredLevel,
  }) {
    final difference = requiredLevel - currentLevel;

    if (difference <= 0) {
      return 0;
    }

    return difference * 8;
  }

  int _calculateEstimatedWeeks(List<dynamic> gaps) {
    final totalHours = gaps.fold<int>(
      0,
      (sum, gap) {
        return sum +
            _calculateEstimatedHours(
              currentLevel: gap.currentLevel,
              requiredLevel: gap.requiredLevel,
            );
      },
    );

    if (totalHours == 0) {
      return 0;
    }

    return (totalHours / 8).ceil();
  }

  String _statusToDatabaseValue(RoadmapItemStatus status) {
    switch (status) {
      case RoadmapItemStatus.planned:
        return 'planned';
      case RoadmapItemStatus.inProgress:
        return 'in_progress';
      case RoadmapItemStatus.completed:
        return 'completed';
    }
  }

  Future<void> _refreshRoadmapStatusFromItems(
    String itemId,
  ) async {
    final item = await _client
        .from('roadmap_items')
        .select('roadmap_id')
        .eq('id', itemId)
        .single();

    final roadmapId = item['roadmap_id'] as String;

    final items = await _client
        .from('roadmap_items')
        .select('status')
        .eq('roadmap_id', roadmapId);

    final statuses = items
        .map<String>((item) => item['status'] as String)
        .toList();

    String roadmapStatus = 'active';

    if (statuses.isNotEmpty &&
        statuses.every((status) => status == 'completed')) {
      roadmapStatus = 'completed';
    }

    await _client
        .from('student_roadmaps')
        .update({
          'status': roadmapStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', roadmapId)
        .eq('student_id', _studentId);
  }
}