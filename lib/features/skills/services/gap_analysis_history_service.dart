
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/job.dart';
import '../../../models/gap_analysis_history.dart';
import '../../../models/skill_gap_analysis_result.dart';

class GapAnalysisHistoryService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _studentId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    return user.id;
  }

  /// Saves a snapshot of the analysis at the current moment.
  Future<GapAnalysisHistory> saveAnalysis({
    required Job job,
    required SkillGapAnalysisResult analysis,
  }) async {
    final snapshot = <String, dynamic>{
      'job_title': job.title,
      'job_sector': job.sector,
      'job_description': job.description,
      'total_skills': analysis.totalSkills,
      'acquired_count': analysis.acquiredCount,
      'to_improve_count': analysis.toImproveCount,
      'missing_count': analysis.missingCount,
      'skills': analysis.gaps.map((gap) {
        return {
          'skill_id': gap.skill.id,
          'skill_name': gap.skill.name,
          'category': gap.skill.category,
          'description': gap.skill.description,
          'current_level': gap.currentLevel,
          'required_level': gap.requiredLevel,
          'status': gap.status.name,
        };
      }).toList(),
    };

    final data = await _client
        .from('gap_analysis_history')
        .insert({
          'student_id': _studentId,
          'job_id': job.id,
          'match_score': analysis.matchScore,
          'analysis_snapshot': snapshot,
        })
        .select()
        .single();

    return GapAnalysisHistory.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  /// Returns all analyses of the current student, newest first.
  Future<List<GapAnalysisHistory>> getHistory() async {
    final data = await _client
        .from('gap_analysis_history')
        .select()
        .eq('student_id', _studentId)
        .order('created_at', ascending: false);

    return data.map<GapAnalysisHistory>((item) {
      return GapAnalysisHistory.fromMap(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  /// Returns the history of a specific job.
  Future<List<GapAnalysisHistory>> getHistoryForJob(
    String jobId,
  ) async {
    final data = await _client
        .from('gap_analysis_history')
        .select()
        .eq('student_id', _studentId)
        .eq('job_id', jobId)
        .order('created_at', ascending: false);

    return data.map<GapAnalysisHistory>((item) {
      return GapAnalysisHistory.fromMap(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  /// Deletes one analysis from the current student's history.
  Future<void> deleteAnalysis(String analysisId) async {
    await _client
        .from('gap_analysis_history')
        .delete()
        .eq('student_id', _studentId)
        .eq('id', analysisId);
  }
}
