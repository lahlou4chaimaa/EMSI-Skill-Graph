import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _targetRoleController = TextEditingController();
  final _bioController = TextEditingController();

  final ProfileService _profileService = ProfileService();

  String? _selectedCampus;
  String? _selectedBranch;
  int? _selectedStudyYear;

  bool _loading = true;
  bool _saving = false;

  final List<String> _campuses = [
    'Casablanca',
    'Rabat',
    'Marrakech',
    'Fès',
    'Tanger',
    'Agadir',
  ];

  final List<String> _branches = [
    'Informatique et Réseaux',
    'Développement Digital',
    'Systèmes d’Information',
    'Data & Intelligence Artificielle',
    'Cybersécurité',
    'Cloud & DevOps',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final profile = await _profileService.getCurrentProfile();

      if (!mounted) return;

      if (profile != null) {
        _fullNameController.text = profile.fullName ?? '';
        _targetRoleController.text = profile.targetRole ?? '';
        _bioController.text = profile.bio ?? '';

        if (_campuses.contains(profile.campus)) {
          _selectedCampus = profile.campus;
        }

        if (_branches.contains(profile.branch)) {
          _selectedBranch = profile.branch;
        }

        if (profile.studyYear != null &&
            profile.studyYear! >= 1 &&
            profile.studyYear! <= 5) {
          _selectedStudyYear = profile.studyYear;
        }
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement du profil : $error'),
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCampus == null ||
        _selectedBranch == null ||
        _selectedStudyYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez compléter tous les champs.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _profileService.updateProfile(
        fullName: _fullNameController.text,
        campus: _selectedCampus!,
        branch: _selectedBranch!,
        studyYear: _selectedStudyYear!,
        targetRole: _targetRoleController.text,
        bio: _bioController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil enregistré.'),
        ),
      );
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
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _targetRoleController.dispose();
    _bioController.dispose();
    super.dispose();
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
        title: const Text('Complete your profile'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Build your student profile',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'This information will be used to build your Skill Graph and career recommendations.',
                  style: TextStyle(
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 28),

                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your full name.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedCampus,
                  decoration: const InputDecoration(
                    labelText: 'Campus',
                    prefixIcon: Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _campuses.map((campus) {
                    return DropdownMenuItem(
                      value: campus,
                      child: Text(campus),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCampus = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Select your campus.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedBranch,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    prefixIcon: Icon(Icons.school_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _branches.map((branch) {
                    return DropdownMenuItem(
                      value: branch,
                      child: Text(branch),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBranch = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Select your branch.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  initialValue: _selectedStudyYear,
                  decoration: const InputDecoration(
                    labelText: 'Study year',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(5, (index) {
                    final year = index + 1;

                    return DropdownMenuItem(
                      value: year,
                      child: Text('Year $year'),
                    );
                  }),
                  onChanged: (value) {
                    setState(() {
                      _selectedStudyYear = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Select your study year.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _targetRoleController,
                  decoration: const InputDecoration(
                    labelText: 'Target role',
                    hintText: 'Example: Full Stack Developer',
                    prefixIcon: Icon(Icons.work_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your target role.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell us briefly about your interests and goals.',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}