import 'skill.dart';

class StudentSkill {
  final String id;
  final String studentId;
  final String skillId;
  final int level;
  final String? source;
  final Skill? skill;

  const StudentSkill({
    required this.id,
    required this.studentId,
    required this.skillId,
    required this.level,
    this.source,
    this.skill,
  });

  factory StudentSkill.fromMap(Map<String, dynamic> map) {
    final skillData = map['skills'];

    return StudentSkill(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      skillId: map['skill_id'] as String,
      level: map['level'] as int,
      source: map['source'] as String?,
      skill: skillData != null
          ? Skill.fromMap(
              Map<String, dynamic>.from(skillData as Map),
            )
          : null,
    );
  }
}