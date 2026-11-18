import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../../profile/services/profile_service.dart';
import '../../career/screens/career_screen.dart';
import '../../map/screens/student_map_screen.dart';
import '../../ai_assistant/screens/ai_assistant_screen.dart';
import '../../skills/screens/skill_gap_screen.dart';
import '../../skills/screens/skill_graph_screen.dart';
import '../../roadmap/screens/roadmap_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  String _name = 'Student';
  String _targetRole = '';
  String _branch = '';
  String _campus = '';
  int? _studyYear;

  bool _loading = true;

  static const Color primaryBlue = Color(0xFF356AE6);
  static const Color darkBlue = Color(0xFF172B4D);
  static const Color backgroundColor = Color(0xFFF5F7FC);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getCurrentProfile();

      if (!mounted) return;

      if (profile != null) {
        setState(() {
          _name = profile.fullName ?? 'Student';
          _targetRole = profile.targetRole ?? '';
          _branch = profile.branch ?? '';
          _campus = profile.campus ?? '';
          _studyYear = profile.studyYear;
        });
      }
    } catch (_) {
      // Keep default values if profile loading fails.
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $error')),
      );
    }
  }

  void _openSkills() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SkillGraphScreen(),
      ),
    );
  }

  void _openGapAnalysis() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SkillGapScreen(),
      ),
    );
  }

  void _openRoadmap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RoadmapScreen(),
      ),
    );
  }

  void _openCareer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CareerScreen(),
      ),
    );
  }

  void _openStudentMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StudentMapScreen(),
      ),
    );
  }

  void _openAiAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AiAssistantScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: primaryBlue,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileCard(),

                    const SizedBox(height: 30),

                    _buildSectionHeader(
                      title: 'Career Intelligence',
                      subtitle: 'Tools to build your professional future',
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.account_tree_rounded,
                            title: 'Skill Graph',
                            subtitle: 'Explore your skills',
                            color: const Color(0xFF356AE6),
                            backgroundColor: const Color(0xFFEAF0FF),
                            onTap: _openSkills,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.analytics_rounded,
                            title: 'Gap Analysis',
                            subtitle: 'Find missing skills',
                            color: const Color(0xFF16865B),
                            backgroundColor: const Color(0xFFE6F5EE),
                            onTap: _openGapAnalysis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 13),

                    Row(
                      children: [
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.route_rounded,
                            title: 'Roadmap',
                            subtitle: 'Build your learning plan',
                            color: const Color(0xFF8B5CF6),
                            backgroundColor: const Color(0xFFF0EAFE),
                            onTap: _openRoadmap,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.work_rounded,
                            title: 'Career',
                            subtitle: 'Explore target jobs',
                            color: const Color(0xFFE69A22),
                            backgroundColor: const Color(0xFFFFF4DF),
                            onTap: _openCareer,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    _buildSectionHeader(
                      title: 'EMSI Community',
                      subtitle: 'Connect, discover and get assistance',
                    ),

                    const SizedBox(height: 16),

                    _WideFeatureCard(
                      icon: Icons.smart_toy_rounded,
                      title: 'EMSI Assistant',
                      subtitle: 'Ask questions and get AI-powered answers',
                      color: const Color(0xFF356AE6),
                      backgroundColor: const Color(0xFFEAF0FF),
                      onTap: _openAiAssistant,
                    ),

                    const SizedBox(height: 12),

                    _WideFeatureCard(
                      icon: Icons.map_rounded,
                      title: 'Student Map',
                      subtitle: 'Discover EMSI students',
                      color: const Color(0xFF16865B),
                      backgroundColor: const Color(0xFFE6F5EE),
                      onTap: _openStudentMap,
                    ),

                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        'EMSI SKILL GRAPH',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final firstName = _name.trim().isEmpty
        ? 'Student'
        : _name.trim().split(' ').first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF356AE6),
            Color(0xFF244CA8),
            Color(0xFF172B4D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 11),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EMSI SKILL GRAPH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Student dashboard',
                      style: TextStyle(
                        color: Color(0xFFDCE6FF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              Material(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
                child: IconButton(
                  tooltip: 'Déconnexion',
                  onPressed: _logout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          Text(
            'WELCOME BACK',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Hello, $firstName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Build your career path with your skills.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9EDF5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172B4D).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: primaryBlue,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Profile',
                      style: TextStyle(
                        color: darkBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your academic information',
                      style: TextStyle(
                        color: Color(0xFF8993A5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF16865B),
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Divider(
            height: 1,
            color: Color(0xFFEEF1F6),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _ProfileInfo(
                  icon: Icons.school_outlined,
                  label: 'Branch',
                  value: _branch,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProfileInfo(
                  icon: Icons.location_city_outlined,
                  label: 'Campus',
                  value: _campus,
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          Row(
            children: [
              Expanded(
                child: _ProfileInfo(
                  icon: Icons.calendar_month_outlined,
                  label: 'Study year',
                  value: _studyYear?.toString() ?? '-',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProfileInfo(
                  icon: Icons.work_outline_rounded,
                  label: 'Target role',
                  value: _targetRole,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: darkBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF356AE6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8993A5),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? '-' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF172B4D),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 155,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE9EDF5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF172B4D).withValues(alpha: 0.025),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 23,
                ),
              ),

              const SizedBox(height: 17),

              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF172B4D),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8993A5),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _WideFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: const Color(0xFFE9EDF5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 25,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF172B4D),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8993A5),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF9AA5B5),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
