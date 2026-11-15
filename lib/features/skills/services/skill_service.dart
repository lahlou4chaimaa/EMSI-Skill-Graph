import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/skill.dart';
import '../../../models/student_skill.dart';

class SkillService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Skill>> getSkills() async {
    final data = await _client
        .from('skills')
        .select()
        .order('category')
        .order('name');

    return data
        .map<Skill>(
          (item) => Skill.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<StudentSkill>> getMySkills() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    final data = await _client
        .from('student_skills')
        .select('''
          id,
          student_id,
          skill_id,
          level,
          source,
          skills (
            id,
            name,
            category,
            description
          )
        ''')
        .eq('student_id', user.id)
        .order('created_at');

    return data
        .map<StudentSkill>(
          (item) => StudentSkill.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> addSkill({
    required String skillId,
    required int level,
    String source = 'Self assessment',
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    await _client.from('student_skills').upsert(
      {
        'student_id': user.id,
        'skill_id': skillId,
        'level': level,
        'source': source,
      },
      onConflict: 'student_id,skill_id',
    );
  }

  Future<void> removeSkill(String studentSkillId) async {
    await _client
        .from('student_skills')
        .delete()
        .eq('id', studentSkillId);
  }
}