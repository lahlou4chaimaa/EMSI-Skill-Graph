import 'skill.dart';

enum SkillGapStatus {
  acquired,
  toImprove,
  missing,
}

class SkillGap {
  final Skill skill;
  final int currentLevel;
  final int requiredLevel;
  final SkillGapStatus status;

  const SkillGap({
    required this.skill,
    required this.currentLevel,
    required this.requiredLevel,
    required this.status,
  });

  bool get isAcquired => status == SkillGapStatus.acquired;

  bool get isToImprove => status == SkillGapStatus.toImprove;

  bool get isMissing => status == SkillGapStatus.missing;
}