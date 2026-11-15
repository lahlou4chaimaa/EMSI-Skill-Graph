import 'skill.dart';

class JobSkill {
  final String id;
  final String jobId;
  final String skillId;
  final int requiredLevel;
  final Skill? skill;

  const JobSkill({
    required this.id,
    required this.jobId,
    required this.skillId,
    required this.requiredLevel,
    this.skill,
  });

  factory JobSkill.fromMap(Map<String, dynamic> map) {
    final skillData = map['skills'];

    return JobSkill(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      skillId: map['skill_id'] as String,
      requiredLevel: map['required_level'] as int,
      skill: skillData == null
          ? null
          : Skill.fromMap(
              Map<String, dynamic>.from(
                skillData as Map,
              ),
            ),
    );
  }
}