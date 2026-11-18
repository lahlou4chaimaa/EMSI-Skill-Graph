
import 'package:flutter/material.dart';

import '../../../models/job.dart';
import '../../../models/skill_gap.dart';
import '../../../models/student_skill.dart';
import '../../skills/services/career_service.dart';
import '../../skills/services/skill_service.dart';

class CareerScreen extends StatefulWidget {
  const CareerScreen({super.key});

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  final CareerService _careerService = CareerService();
  final SkillService _skillService = SkillService();

  List<Job> _jobs = [];
  List<StudentSkill> _studentSkills = [];

  Job? _selectedJob;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _careerService.getJobs(),
        _skillService.getMySkills(),
      ]);

      final jobs = results[0] as List<Job>;
      final studentSkills = results[1] as List<StudentSkill>;

      if (!mounted) return;

      setState(() {
        _jobs = jobs;
        _studentSkills = studentSkills;

        if (_selectedJob != null) {
          _selectedJob = jobs.cast<Job?>().firstWhere(
                (job) => job?.id == _selectedJob!.id,
                orElse: () => null,
              );
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Impossible de charger les données : $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<SkillGap> _calculateGaps(Job job) {
    final currentLevels = <String, int>{
      for (final studentSkill in _studentSkills)
        studentSkill.skillId: studentSkill.level,
    };

    final gaps = <SkillGap>[];

    for (final jobSkill in job.skills) {
      final skill = jobSkill.skill;

      // Ignore une association si la compétence liée est absente.
      if (skill == null) continue;

      final currentLevel = currentLevels[jobSkill.skillId] ?? 0;
      final requiredLevel = jobSkill.requiredLevel;

      late final SkillGapStatus status;

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
    }

    return gaps;
  }

  double _calculateMatchScore(List<SkillGap> gaps) {
    if (gaps.isEmpty) return 0;

    final totalRequired = gaps.fold<int>(
      0,
      (total, gap) => total + gap.requiredLevel,
    );

    if (totalRequired == 0) return 0;

    final totalAchieved = gaps.fold<int>(
      0,
      (total, gap) =>
          total +
          (gap.currentLevel > gap.requiredLevel
              ? gap.requiredLevel
              : gap.currentLevel),
    );

    return (totalAchieved / totalRequired) * 100;
  }

  Color _statusColor(SkillGapStatus status) {
    switch (status) {
      case SkillGapStatus.acquired:
        return Colors.green;
      case SkillGapStatus.toImprove:
        return Colors.orange;
      case SkillGapStatus.missing:
        return Colors.red;
    }
  }

  String _statusLabel(SkillGapStatus status) {
    switch (status) {
      case SkillGapStatus.acquired:
        return 'Acquise';
      case SkillGapStatus.toImprove:
        return 'À améliorer';
      case SkillGapStatus.missing:
        return 'Manquante';
    }
  }

  IconData _statusIcon(SkillGapStatus status) {
    switch (status) {
      case SkillGapStatus.acquired:
        return Icons.check_circle;
      case SkillGapStatus.toImprove:
        return Icons.trending_up;
      case SkillGapStatus.missing:
        return Icons.error_outline;
    }
  }

  Widget _buildScoreCard(double score, List<SkillGap> gaps) {
    final acquired = gaps
        .where((gap) => gap.status == SkillGapStatus.acquired)
        .length;

    final toImprove = gaps
        .where((gap) => gap.status == SkillGapStatus.toImprove)
        .length;

    final missing = gaps
        .where((gap) => gap.status == SkillGapStatus.missing)
        .length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Votre compatibilité avec ce métier',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: score / 100,
                          strokeWidth: 9,
                          backgroundColor: Colors.grey.shade200,
                          color: const Color(0xFF356AE6),
                        ),
                      ),
                      Text(
                        '${score.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172B4D),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCountLine(
                        'Acquises',
                        acquired,
                        Colors.green,
                      ),
                      const SizedBox(height: 9),
                      _buildCountLine(
                        'À améliorer',
                        toImprove,
                        Colors.orange,
                      ),
                      const SizedBox(height: 9),
                      _buildCountLine(
                        'Manquantes',
                        missing,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Score indicatif calculé à partir des niveaux de compétences '
              'actuels et des niveaux requis dans le catalogue.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountLine(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillSection(
    String title,
    List<SkillGap> gaps,
    SkillGapStatus status,
  ) {
    final filteredGaps = gaps
        .where((gap) => gap.status == status)
        .toList();

    if (filteredGaps.isEmpty) {
      return const SizedBox.shrink();
    }

    final color = _statusColor(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            Icon(
              _statusIcon(status),
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${filteredGaps.length}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...filteredGaps.map(_buildSkillCard),
      ],
    );
  }

  Widget _buildSkillCard(SkillGap gap) {
    final color = _statusColor(gap.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gap.skill.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (gap.skill.category != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      gap.skill.category!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Votre niveau : ${gap.currentLevel == 0 ? "Non acquis" : "${gap.currentLevel}/5"}'
                    '   •   Requis : ${gap.requiredLevel}/5',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(gap.status),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysis() {
    final job = _selectedJob;

    if (job == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 35),
        child: Center(
          child: Text(
            'Sélectionnez un métier pour lancer l’analyse.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final gaps = _calculateGaps(job);
    final score = _calculateMatchScore(gaps);

    if (gaps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 30),
        child: Center(
          child: Text(
            'Aucune compétence associée à ce métier.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScoreCard(score, gaps),
        _buildSkillSection(
          'Compétences acquises',
          gaps,
          SkillGapStatus.acquired,
        ),
        _buildSkillSection(
          'Compétences à améliorer',
          gaps,
          SkillGapStatus.toImprove,
        ),
        _buildSkillSection(
          'Compétences manquantes',
          gaps,
          SkillGapStatus.missing,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Career & Skill Gap',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : _jobs.isEmpty
                  ? const Center(
                      child: Text('Aucun métier disponible.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                            'Explorez votre parcours professionnel',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF172B4D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choisissez un métier pour comparer vos '
                            'compétences avec celles demandées.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedJob?.id,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Métier souhaité',
                              prefixIcon: const Icon(Icons.work_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            hint: const Text('Sélectionner un métier'),
                            items: _jobs.map((job) {
                              return DropdownMenuItem<String>(
                                value: job.id,
                                child: Text(
                                  job.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (jobId) {
                              setState(() {
                                _selectedJob = _jobs.firstWhere(
                                  (job) => job.id == jobId,
                                );
                              });
                            },
                          ),
                          if (_selectedJob != null) ...[
                            const SizedBox(height: 14),
                            if (_selectedJob!.sector != null)
                              Text(
                                'Secteur : ${_selectedJob!.sector}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            if (_selectedJob!.description != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _selectedJob!.description!,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 20),
                          _buildAnalysis(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
    );
  }
}
