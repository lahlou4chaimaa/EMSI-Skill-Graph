import '../../../../../models/job.dart';
import '../../../../../models/skill_gap.dart';
import '../../../../../models/skill_gap_analysis_result.dart';
import '../../../../../models/student_skill.dart';

class SkillGapAnalyzer {
  /// Compare les compétences de l'étudiant avec celles requises
  /// pour un métier et calcule un score de correspondance.
  static SkillGapAnalysisResult analyze({
    required Job job,
    required List<StudentSkill> studentSkills,
  }) {
    // Map : ID de compétence -> niveau actuel de l'étudiant.
    final Map<String, int> studentSkillLevels = {
      for (final studentSkill in studentSkills)
        studentSkill.skillId: studentSkill.level,
    };

    final List<SkillGap> gaps = [];

    double earnedPoints = 0;
    double totalRequiredPoints = 0;

    for (final jobSkill in job.skills) {
      final skill = jobSkill.skill;

      // Une association sans compétence liée est ignorée.
      if (skill == null) {
        continue;
      }

      final int currentLevel =
          studentSkillLevels[jobSkill.skillId] ?? 0;

      final int requiredLevel =
          jobSkill.requiredLevel.clamp(1, 5);

      final SkillGapStatus status;

      if (currentLevel >= requiredLevel) {
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
          requiredLevel: requiredLevel,
          status: status,
        ),
      );

      // Le score prend en compte le niveau, pas uniquement
      // le nombre de compétences possédées.
      totalRequiredPoints += requiredLevel;

      earnedPoints += currentLevel
          .clamp(0, requiredLevel);
    }

    final double matchScore = totalRequiredPoints == 0
        ? 0
        : (earnedPoints / totalRequiredPoints) * 100;

    return SkillGapAnalysisResult(
      gaps: gaps,
      matchScore: matchScore,
    );
  }
}
