
import 'job_skill.dart';

class Job {
  final String id;
  final String title;
  final String? sector;
  final String? description;
  final List<JobSkill> skills;

  const Job({
    required this.id,
    required this.title,
    this.sector,
    this.description,
    this.skills = const [],
  });

  factory Job.fromMap(Map<String, dynamic> map) {
    final skillsData = map['job_skills'] as List? ?? [];

    return Job(
      id: map['id'] as String,
      title: map['title'] as String,
      sector: map['sector'] as String?,
      description: map['description'] as String?,
      skills: skillsData.map((item) {
        return JobSkill.fromMap(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList(),
    );
  }
}
