
import 'package:flutter/material.dart';

import '../../../models/job.dart';
import '../../../models/skill_gap.dart';
import '../../../models/skill_gap_analysis_result.dart';
import '../../../models/student_skill.dart';
import '../../../models/gap_analysis_history.dart';

import '../services/career_service.dart';
import '../services/skill_service.dart';
import '../services/skill_gap_analyzer.dart';
import '../services/saved_jobs_service.dart';
import '../services/gap_analysis_history_service.dart';
import '../../roadmap/services/roadmap_service.dart';
import '../../roadmap/screens/roadmap_details_screen.dart';

class SkillGapScreen extends StatefulWidget {
  const SkillGapScreen({super.key});

  @override
  State<SkillGapScreen> createState() => _SkillGapScreenState();
}

class _SkillGapScreenState extends State<SkillGapScreen>
    with SingleTickerProviderStateMixin {
  final CareerService _careerService = CareerService();
  final SkillService _skillService = SkillService();
  final RoadmapService _roadmapService = RoadmapService();
  final SavedJobsService _savedJobsService = SavedJobsService();
  final GapAnalysisHistoryService _historyService =
      GapAnalysisHistoryService();

  late TabController _tabController;

  List<Job> _jobs = [];
  List<StudentSkill> _studentSkills = [];
  Set<String> _savedJobIds = {};
  List<GapAnalysisHistory> _history = [];

  Job? _selectedJob;
  SkillGapAnalysisResult? _analysis;

  bool _loading = true;
  bool _savingAnalysis = false;
  bool _creatingRoadmap = false;
  bool _savingJob = false;
  bool _loadingHistory = false;
  String? _error;

  static const Color primaryBlue = Color(0xFF356AE6);
  static const Color darkBlue = Color(0xFF172B4D);

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _careerService.getJobs(),
        _skillService.getMySkills(),
        _savedJobsService.getSavedJobIds(),
        _historyService.getHistory(),
      ]);

      final jobs = results[0] as List<Job>;
      final skills = results[1] as List<StudentSkill>;
      final savedIds = results[2] as Set<String>;
      final history = results[3] as List<GapAnalysisHistory>;

      if (!mounted) return;

      final previousJobId = _selectedJob?.id;

      Job? restoredJob;

      if (previousJobId != null) {
        for (final job in jobs) {
          if (job.id == previousJobId) {
            restoredJob = job;
            break;
          }
        }
      }

      setState(() {
        _jobs = jobs;
        _studentSkills = skills;
        _savedJobIds = savedIds;
        _history = history;

        _selectedJob = restoredJob;

        _analysis = restoredJob == null
            ? null
            : SkillGapAnalyzer.analyze(
                job: restoredJob,
                studentSkills: skills,
              );

        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);

    try {
      final history = await _historyService.getHistory();

      if (!mounted) return;

      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loadingHistory = false);

      _showMessage('Unable to load history: $error');
    }
  }

  void _selectJob(Job job) {
    setState(() {
      _selectedJob = job;
      _analysis = SkillGapAnalyzer.analyze(
        job: job,
        studentSkills: _studentSkills,
      );
    });
  }

  void _openExplorer(Job job) {
    _selectJob(job);
    _tabController.animateTo(0);
  }

  // ============================================================
  // SAVE / REMOVE JOB
  // ============================================================

  Future<void> _toggleSavedJob(Job job) async {
    if (_savingJob) return;

    setState(() => _savingJob = true);

    try {
      final alreadySaved = _savedJobIds.contains(job.id);

      if (alreadySaved) {
        await _savedJobsService.removeSavedJob(job.id);

        if (!mounted) return;

        setState(() {
          _savedJobIds.remove(job.id);
        });

        _showMessage('${job.title} removed from My Jobs.');
      } else {
        await _savedJobsService.saveJob(job.id);

        if (!mounted) return;

        setState(() {
          _savedJobIds.add(job.id);
        });

        _showMessage('${job.title} saved successfully.');
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage('Unable to update saved jobs: $error');
    } finally {
      if (mounted) {
        setState(() => _savingJob = false);
      }
    }
  }

  // ============================================================
  // SAVE ANALYSIS
  // ============================================================

  Future<void> _saveCurrentAnalysis() async {
    if (_selectedJob == null || _analysis == null || _savingAnalysis) {
      return;
    }

    setState(() => _savingAnalysis = true);

    try {
      await _historyService.saveAnalysis(
        job: _selectedJob!,
        analysis: _analysis!,
      );

      if (!mounted) return;

      await _loadHistory();

      if (!mounted) return;

      _showMessage('Analysis saved to your history.');
    } catch (error) {
      if (!mounted) return;

      _showMessage('Unable to save analysis: $error');
    } finally {
      if (mounted) {
        setState(() => _savingAnalysis = false);
      }
    }
  }

Future<void> _createPersonalizedRoadmap() async {
  if (_selectedJob == null || _analysis == null || _creatingRoadmap) {
    return;
  }

  final gaps = [
    ..._analysis!.skillsToImprove,
    ..._analysis!.missingSkills,
  ];

  if (gaps.isEmpty) {
    _showMessage(
      'You already meet all the required skill levels for this career.',
    );
    return;
  }

  setState(() => _creatingRoadmap = true);

  try {
    // 1. Save the current analysis in history.
    final savedAnalysis = await _historyService.saveAnalysis(
      job: _selectedJob!,
      analysis: _analysis!,
    );

    // 2. Refresh the analysis history.
    final updatedHistory = await _historyService.getHistory();

    // 3. Create the roadmap using the saved analysis.
    final roadmap = await _roadmapService.createRoadmap(
      job: _selectedJob!,
      analysis: _analysis!,
      sourceAnalysisId: savedAnalysis.id,
    );

    if (!mounted) return;

    setState(() {
      _history = updatedHistory;
    });

    // 4. Open the newly created roadmap.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoadmapDetailsScreen(
          roadmapId: roadmap.id,
        ),
      ),
    );

    if (!mounted) return;

    // Refresh the screen when returning from roadmap details.
    await _loadData();
  } catch (error) {
    if (!mounted) return;

    _showMessage(
      'Unable to create roadmap: $error',
    );
  } finally {
    if (mounted) {
      setState(() => _creatingRoadmap = false);
    }
  }
}

  Future<void> _deleteHistoryItem(
    GapAnalysisHistory item,
  ) async {
    try {
      await _historyService.deleteAnalysis(item.id);

      if (!mounted) return;

      setState(() {
        _history.removeWhere((history) => history.id == item.id);
      });

      _showMessage('Analysis removed from history.');
    } catch (error) {
      if (!mounted) return;

      _showMessage('Unable to delete analysis: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Career Gap Analysis'),
        backgroundColor: Colors.white,
        foregroundColor: darkBlue,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: primaryBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.explore_outlined),
              text: 'Explore',
            ),
            Tab(
              icon: Icon(Icons.bookmark_outline),
              text: 'My Jobs',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'History',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExplorerTab(),
                    _buildSavedJobsTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  // ============================================================
  // TAB 1: EXPLORE
  // ============================================================

  Widget _buildExplorerTab() {
    if (_jobs.isEmpty) {
      return _buildEmpty(
        'No careers available',
        'There are currently no careers in the database.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Discover your skill gaps',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Compare your current skills with the requirements of your target career.',
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildJobSelector(),
          if (_selectedJob == null) ...[
            const SizedBox(height: 20),
            _buildSelectionMessage(),
          ],
          if (_analysis != null) ...[
            const SizedBox(height: 20),
            _buildScoreCard(_analysis!),
            const SizedBox(height: 16),
            _buildStatistics(_analysis!),
            const SizedBox(height: 24),
            _buildSkillSection(
              title: 'Acquired skills',
              subtitle: 'You already meet the required level.',
              skills: _analysis!.acquiredSkills,
              color: const Color(0xFF16865B),
              icon: Icons.check_circle_outline,
              emptyMessage: 'No acquired skills yet.',
            ),
            const SizedBox(height: 18),
            _buildSkillSection(
              title: 'Skills to improve',
              subtitle: 'You have these skills, but need a higher level.',
              skills: _analysis!.skillsToImprove,
              color: const Color(0xFFE69A22),
              icon: Icons.trending_up,
              emptyMessage: 'No skills to improve.',
            ),
            const SizedBox(height: 18),
            _buildSkillSection(
              title: 'Missing skills',
              subtitle: 'These skills are not in your profile.',
              skills: _analysis!.missingSkills,
              color: const Color(0xFFD9534F),
              icon: Icons.warning_amber_outlined,
              emptyMessage: 'No missing skills.',
            ),
            const SizedBox(height: 20),
            _buildAnalysisActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildJobSelector() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select your target career',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedJob?.id,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.work_outline,
                  color: primaryBlue,
                ),
                hintText: 'Choose a career',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _jobs.map((job) {
                return DropdownMenuItem<String>(
                  value: job.id,
                  child: Text(
                    job.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id == null) return;

                final job = _jobs.firstWhere(
                  (item) => item.id == id,
                );

                _selectJob(job);
              },
            ),
            if (_selectedJob != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedJob!.sector ?? 'Career',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _savingJob
                        ? null
                        : () => _toggleSavedJob(_selectedJob!),
                    icon: Icon(
                      _savedJobIds.contains(_selectedJob!.id)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 19,
                    ),
                    label: Text(
                      _savedJobIds.contains(_selectedJob!.id)
                          ? 'Saved'
                          : 'Save job',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionMessage() {
    return _informationCard(
      icon: Icons.analytics_outlined,
      title: 'Choose a career to start',
      message: 'Your skill analysis will appear here after selecting a career.',
    );
  }

 
Widget _buildAnalysisActions() {
  final hasSkillsToWorkOn = _analysis != null &&
      (_analysis!.skillsToImprove.isNotEmpty ||
          _analysis!.missingSkills.isNotEmpty);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // CREATE PERSONALIZED ROADMAP
      ElevatedButton.icon(
        onPressed: (_creatingRoadmap || !hasSkillsToWorkOn)
            ? null
            : _createPersonalizedRoadmap,
        icon: _creatingRoadmap
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.route_outlined),
        label: Text(
          _creatingRoadmap
              ? 'Creating your roadmap...'
              : 'Create Personalized Roadmap',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: darkBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      if (!hasSkillsToWorkOn) ...[
        const SizedBox(height: 8),
        Text(
          'You have no missing or improvable skills for this career. '
          'A roadmap is not necessary at the moment.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],

      const SizedBox(height: 12),

      // SAVE ANALYSIS
      ElevatedButton.icon(
        onPressed: _savingAnalysis ? null : _saveCurrentAnalysis,
        icon: _savingAnalysis
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _savingAnalysis ? 'Saving...' : 'Save this analysis',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),

      const SizedBox(height: 10),

      // REFRESH ANALYSIS
      OutlinedButton.icon(
        onPressed: _refreshCurrentAnalysis,
        icon: const Icon(Icons.refresh),
        label: const Text(
          'Refresh analysis with my latest skills',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    ],
  );
}


  Future<void> _refreshCurrentAnalysis() async {
    if (_selectedJob == null) return;

    try {
      final skills = await _skillService.getMySkills();

      if (!mounted) return;

      setState(() {
        _studentSkills = skills;
        _analysis = SkillGapAnalyzer.analyze(
          job: _selectedJob!,
          studentSkills: skills,
        );
      });

      _showMessage('Analysis refreshed.');
    } catch (error) {
      if (!mounted) return;

      _showMessage('Unable to refresh analysis: $error');
    }
  }

  // ============================================================
  // TAB 2: SAVED JOBS
  // ============================================================

  Widget _buildSavedJobsTab() {
    final savedJobs = _jobs.where(
      (job) => _savedJobIds.contains(job.id),
    ).toList();

    if (savedJobs.isEmpty) {
      return _buildEmpty(
        'No saved careers yet',
        'Explore careers and save the ones you want to work towards. They will remain available when you log in again.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'My target careers',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${savedJobs.length} saved career${savedJobs.length > 1 ? 's' : ''}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),
          ...savedJobs.map((job) {
            final latestAnalysis = _latestAnalysisForJob(job.id);

            return Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFEAF0FF),
                          child: Icon(
                            Icons.work_outline,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: darkBlue,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                job.sector ?? 'Career',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove saved job',
                          onPressed: _savingJob
                              ? null
                              : () => _toggleSavedJob(job),
                          icon: const Icon(
                            Icons.bookmark_remove_outlined,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    if (latestAnalysis != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'Latest saved score',
                            style: TextStyle(fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            '${latestAnalysis.matchScore.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openExplorer(job),
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('Open career analysis'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  GapAnalysisHistory? _latestAnalysisForJob(String jobId) {
    for (final item in _history) {
      if (item.jobId == jobId) return item;
    }

    return null;
  }

  // ============================================================
  // TAB 3: HISTORY
  // ============================================================

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return _buildEmpty(
        'No analysis history',
        'When you save an analysis, it will appear here. You can keep several analyses for the same career.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Analysis history',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${_history.length} saved analys${_history.length > 1 ? 'es' : 'is'}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),
          ..._history.map(_buildHistoryCard),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(GapAnalysisHistory item) {
    final score = item.matchScore.clamp(0.0, 100.0);

    final scoreColor = score >= 75
        ? const Color(0xFF16865B)
        : score >= 40
            ? const Color(0xFFE69A22)
            : const Color(0xFFD9534F);

    final date = item.createdAt.toLocal();

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showHistoryDetails(item),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${score.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.jobTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${date.day.toString().padLeft(2, '0')}/'
                      '${date.month.toString().padLeft(2, '0')}/'
                      '${date.year}  '
                      '${date.hour.toString().padLeft(2, '0')}:'
                      '${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.skills.length} skills analyzed',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'details') {
                    _showHistoryDetails(item);
                  } else if (value == 'delete') {
                    _confirmDeleteHistory(item);
                  } else if (value == 'open') {
                    final job = _jobs.where(
                      (job) => job.id == item.jobId,
                    ).firstOrNull;

                    if (job != null) {
                      _openExplorer(job);
                    } else {
                      _showMessage('This career is no longer available.');
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'details',
                    child: Text('View saved results'),
                  ),
                  PopupMenuItem(
                    value: 'open',
                    child: Text('Open current analysis'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete history item'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryDetails(GapAnalysisHistory item) {
    final snapshot = item.snapshot;
    final skills = item.skills;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Color(0xFFF6F8FC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(22),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.jobTitle,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                  children: [
                    _historyScoreCard(item),
                    const SizedBox(height: 16),
                    _historyCounts(snapshot),
                    const SizedBox(height: 18),
                    const Text(
                      'Skills at the time of this analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...skills.map(_historySkillItem),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _historyScoreCard(GapAnalysisHistory item) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Saved match score',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${item.matchScore.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
            ),
            Text(
              item.jobSector ?? 'Career',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCounts(Map<String, dynamic> snapshot) {
    final acquired = snapshot['acquired_count'] as int? ?? 0;
    final improve = snapshot['to_improve_count'] as int? ?? 0;
    final missing = snapshot['missing_count'] as int? ?? 0;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            acquired,
            'Acquired',
            const Color(0xFF16865B),
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            improve,
            'To improve',
            const Color(0xFFE69A22),
            Icons.trending_up,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            missing,
            'Missing',
            const Color(0xFFD9534F),
            Icons.warning_amber_outlined,
          ),
        ),
      ],
    );
  }

  Widget _historySkillItem(Map<String, dynamic> skill) {
    final name = skill['skill_name'] as String? ?? 'Unknown skill';
    final current = (skill['current_level'] as num?)?.toInt() ?? 0;
    final required = (skill['required_level'] as num?)?.toInt() ?? 1;
    final status = skill['status'] as String? ?? 'missing';

    final Color color;

    switch (status) {
      case 'acquired':
        color = const Color(0xFF16865B);
        break;
      case 'toImprove':
        color = const Color(0xFFE69A22);
        break;
      default:
        color = const Color(0xFFD9534F);
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Current: $current/5  •  Required: $required/5',
        ),
        trailing: Icon(Icons.circle, color: color, size: 13),
      ),
    );
  }

  Future<void> _confirmDeleteHistory(
    GapAnalysisHistory item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete analysis?'),
          content: const Text(
            'This saved analysis will be permanently removed from your history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteHistoryItem(item);
    }
  }

  // ============================================================
  // SHARED ANALYSIS WIDGETS
  // ============================================================

  Widget _buildScoreCard(SkillGapAnalysisResult result) {
    final score = result.matchScore.clamp(0.0, 100.0);

    final scoreColor = score >= 75
        ? const Color(0xFF16865B)
        : score >= 40
            ? const Color(0xFFE69A22)
            : const Color(0xFFD9534F);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Career match score',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 145,
              height: 145,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(scoreColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${score.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      const Text(
                        'Match',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _scoreDescription(score),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${result.totalSkills} required skills analyzed',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Indicative score based on the current skill levels and stored requirements.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _scoreDescription(double score) {
    if (score >= 75) {
      return 'Your current skills closely match this career.';
    }

    if (score >= 40) {
      return 'You have a good starting point. Some skills need improvement.';
    }

    return 'You have several skills to develop for this career.';
  }

  Widget _buildStatistics(SkillGapAnalysisResult result) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            result.acquiredCount,
            'Acquired',
            const Color(0xFF16865B),
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            result.toImproveCount,
            'To improve',
            const Color(0xFFE69A22),
            Icons.trending_up,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            result.missingCount,
            'Missing',
            const Color(0xFFD9534F),
            Icons.warning_amber_outlined,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    int count,
    String label,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillSection({
    required String title,
    required String subtitle,
    required List<SkillGap> skills,
    required Color color,
    required IconData icon,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title (${skills.length})',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        if (skills.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          ...skills.map((gap) => _buildSkillItem(gap, color)),
      ],
    );
  }

  Widget _buildSkillItem(SkillGap gap, Color color) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    gap.skill.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${gap.currentLevel}/${gap.requiredLevel}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: List.generate(5, (index) {
                final active = index < gap.currentLevel;

                return Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: active ? color : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 7),
            Text(
              'Required level: ${gap.requiredLevel}/5',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
            if (gap.skill.category != null &&
                gap.skill.category!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                gap.skill.category!,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMMON STATES
  // ============================================================

  Widget _informationCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 55, color: primaryBlue),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _informationCard(
          icon: Icons.work_outline,
          title: title,
          message: message,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load Gap Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
