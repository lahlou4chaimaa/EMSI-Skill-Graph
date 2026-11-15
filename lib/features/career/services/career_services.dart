import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/job.dart';
import '../../../models/job_skill.dart';
import '../../../models/skill_gap.dart';

class CareerService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Job>> getJobs() async {
    final data = await _client
        .from('jobs')
        .select()
        .order('title');

    return data
        .map<Job>(
          (item) => Job.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<JobSkill>> getJobSkills(
    String jobId,
  ) async {
    final data = await _client
        .from('job_skills')
        .select('''
          id,
          job_id,
          skill_id,
          required_level,
          skills (
            id,
            name,
            category,
            description
          )
        ''')
        .eq('job_id', jobId);

    return data
        .map<JobSkill>(
          (item) => JobSkill.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<Map<String, int>> getMySkillLevels() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    final data = await _client
        .from('student_skills')
        .select('skill_id, level')
        .eq('student_id', user.id);

    return {
      for (final item in data)
        item['skill_id'] as String:
            item['level'] as int,
    };
  }

  Future<List<SkillGap>> analyzeJob(Job job) async {
    final jobSkills = await getJobSkills(job.id);
    final mySkills = await getMySkillLevels();

    final gaps = <SkillGap>[];

    for (final jobSkill in jobSkills) {
      final skill = jobSkill.skill;

      if (skill == null) {
        continue;
      }

      final currentLevel =
          mySkills[jobSkill.skillId] ?? 0;

      late final SkillGapStatus status;

      if (currentLevel >= jobSkill.requiredLevel) {
        status = SkillGapStatus.acquired;
      } else if (currentLevel > 0) {
        status = SkillGapStatus.toImprove;
      } else {
        status = SkillGapStatus.missing;
      }

      gaps.add(
        SkillGap(
          skill: skill,
          currentLevel: currentLevel,
          requiredLevel: jobSkill.requiredLevel,
          status: status,
        ),
      );
    }

    return gaps;
  }

  double calculateScore(List<SkillGap> gaps) {
    if (gaps.isEmpty) {
      return 0;
    }

    double total = 0;

    for (final gap in gaps) {
      final ratio =
          gap.currentLevel / gap.requiredLevel;

      total += ratio > 1 ? 1 : ratio;
    }

    return (total / gaps.length) * 100;
  }
}