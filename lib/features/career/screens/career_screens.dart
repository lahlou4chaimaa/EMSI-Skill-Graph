import 'package:flutter/material.dart';

import '../../../models/job.dart';
import '../../../models/skill_gap.dart';
import '../services/career_services.dart';


class CareerScreen extends StatefulWidget {
  const CareerScreen({super.key});

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  final CareerService _careerService = CareerService();

  List<Job> _jobs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await _careerService.getJobs();

      if (!mounted) return;

      setState(() {
        _jobs = jobs;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _openAnalysis(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CareerAnalysisScreen(
          job: job,
          careerService: _careerService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Career'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _jobs.isEmpty
              ? const Center(
                  child: Text('No career paths available.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _jobs.length,
                  itemBuilder: (context, index) {
                    final job = _jobs[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const CircleAvatar(
                          child: Icon(Icons.work_outline),
                        ),
                        title: Text(
                          job.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          job.description ??
                              'Explore this career path.',
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 18,
                        ),
                        onTap: () => _openAnalysis(job),
                      ),
                    );
                  },
                ),
    );
  }
}

class CareerAnalysisScreen extends StatefulWidget {
  final Job job;
  final CareerService careerService;

  const CareerAnalysisScreen({
    super.key,
    required this.job,
    required this.careerService,
  });

  @override
  State<CareerAnalysisScreen> createState() =>
      _CareerAnalysisScreenState();
}

class _CareerAnalysisScreenState
    extends State<CareerAnalysisScreen> {
  List<SkillGap> _gaps = [];
  bool _loading = true;
  double _score = 0;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final gaps = await widget.careerService.analyzeJob(
        widget.job,
      );

      final score =
          widget.careerService.calculateScore(gaps);

      if (!mounted) return;

      setState(() {
        _gaps = gaps;
        _score = score;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _statusText(SkillGapStatus status) {
    switch (status) {
      case SkillGapStatus.acquired:
        return 'Acquired';
      case SkillGapStatus.toImprove:
        return 'To improve';
      case SkillGapStatus.missing:
        return 'Missing';
    }
  }

  IconData _statusIcon(SkillGapStatus status) {
    switch (status) {
      case SkillGapStatus.acquired:
        return Icons.check_circle_outline;
      case SkillGapStatus.toImprove:
        return Icons.trending_up;
      case SkillGapStatus.missing:
        return Icons.warning_amber_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job.title),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'Career Match',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_score.round()}%',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF356AE6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Current skill match',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Skill Analysis',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._gaps.map(
                  (gap) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(
                        _statusIcon(gap.status),
                      ),
                      title: Text(
                        gap.skill.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Your level: ${gap.currentLevel} / '
                        'Required: ${gap.requiredLevel}',
                      ),
                      trailing: Text(
                        _statusText(gap.status),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}