
import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../../profile/services/profile_service.dart';
import '../../skills/screens/my_skills_screen.dart';
import '../../career/screens/career_screens.dart';
import '../../map/screens/student_map_screen.dart';

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
        builder: (_) => const MySkillsScreen(),
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be available soon.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('EMSI Skill Graph'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $_name',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Build your career path with your skills.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),

            _ProfileCard(
              branch: _branch,
              campus: _campus,
              studyYear: _studyYear,
              targetRole: _targetRole,
            ),

            const SizedBox(height: 24),

            const Text(
              'Your Career Intelligence',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.account_tree_outlined,
                    title: 'Skill Graph',
                    subtitle: 'Explore your skills',
                    onTap: _openSkills,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.analytics_outlined,
                    title: 'Gap Analysis',
                    subtitle: 'Find missing skills',
                    onTap: () => _showComingSoon('Gap Analysis'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.route_outlined,
                    title: 'Roadmap',
                    subtitle: 'Build your plan',
                    onTap: () => _showComingSoon('Roadmap'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.work_outline,
                    title: 'Career',
                    subtitle: 'Explore target jobs',
                    onTap: _openCareer,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _FeatureCard(
              icon: Icons.map_outlined,
              title: 'Student Map',
              subtitle: 'Discover EMSI students',
              onTap: _openStudentMap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String branch;
  final String campus;
  final int? studyYear;
  final String targetRole;

  const _ProfileCard({
    required this.branch,
    required this.campus,
    required this.studyYear,
    required this.targetRole,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Student Profile',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.school_outlined,
              label: branch,
            ),
            _InfoRow(
              icon: Icons.location_city_outlined,
              label: campus,
            ),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Year ${studyYear ?? '-'}',
            ),
            _InfoRow(
              icon: Icons.work_outline,
              label: targetRole,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const SizedBox(width: 2),
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF356AE6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label.isEmpty ? '-' : label),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 34,
                color: const Color(0xFF356AE6),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
