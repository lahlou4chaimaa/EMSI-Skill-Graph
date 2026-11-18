import 'skill_gap.dart';

class SkillGapAnalysisResult {
  final List<SkillGap> gaps;
  final double matchScore;

  const SkillGapAnalysisResult({
    required this.gaps,
    required this.matchScore,
  });

  List<SkillGap> get acquiredSkills {
    return gaps
        .where((gap) => gap.isAcquired)
        .toList();
  }

  List<SkillGap> get skillsToImprove {
    return gaps
        .where((gap) => gap.isToImprove)
        .toList();
  }

  List<SkillGap> get missingSkills {
    return gaps
        .where((gap) => gap.isMissing)
        .toList();
  }

  int get totalSkills => gaps.length;

  int get acquiredCount => acquiredSkills.length;

  int get toImproveCount => skillsToImprove.length;

  int get missingCount => missingSkills.length;
}