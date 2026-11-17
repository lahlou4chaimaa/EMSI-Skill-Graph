
import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentNumberController = TextEditingController();
  final _campusController = TextEditingController();
  final _targetRoleController = TextEditingController();
  final _bioController = TextEditingController();

  final ProfileService _profileService = ProfileService();

  String? _selectedCity;
  String? _selectedBranch;
  int? _selectedStudyYear;

  bool _showOnMap = false;
  bool _loading = true;
  bool _saving = false;

  final List<String> _cities = [
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

  static const Color _emsiGreen = Color(0xFF16834A);
  static const Color _darkGreen = Color(0xFF105C36);

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
        _firstNameController.text = profile.firstName ?? '';
        _lastNameController.text = profile.lastName ?? '';
        _studentNumberController.text = profile.studentNumber ?? '';
        _campusController.text = profile.campus ?? '';
        _targetRoleController.text = profile.targetRole ?? '';
        _bioController.text = profile.bio ?? '';

        if (_cities.contains(profile.city)) {
          _selectedCity = profile.city;
        }

        if (_branches.contains(profile.branch)) {
          _selectedBranch = profile.branch;
        }

        if (profile.studyYear != null &&
            profile.studyYear! >= 1 &&
            profile.studyYear! <= 5) {
          _selectedStudyYear = profile.studyYear;
        }

        _showOnMap = profile.showOnMap;
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
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCity == null ||
        _selectedBranch == null ||
        _selectedStudyYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez compléter tous les champs obligatoires.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _profileService.updateProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        studentNumber: _studentNumberController.text,
        city: _selectedCity!,
        campus: _campusController.text,
        branch: _selectedBranch!,
        studyYear: _selectedStudyYear!,
        targetRole: _targetRoleController.text,
        bio: _bioController.text,
        showOnMap: _showOnMap,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil enregistré avec succès.'),
          backgroundColor: _emsiGreen,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l’enregistrement : $error'),
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _emsiGreen),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: _emsiGreen,
          width: 1.8,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool requiredField = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        hint: hint,
      ),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ce champ est obligatoire.';
              }
              return null;
            }
          : null,
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _studentNumberController.dispose();
    _campusController.dispose();
    _targetRoleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: _emsiGreen,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _darkGreen,
        elevation: 0,
        title: const Text(
          'Profil étudiant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _emsiGreen.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              color: _emsiGreen,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'EMSI Connect',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: _darkGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Complète ton profil étudiant',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ces informations permettront de te retrouver '
                        'dans la communauté EMSI et sur la carte des étudiants.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Informations personnelles',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _firstNameController,
                  label: 'Prénom',
                  icon: Icons.person_outline,
                  requiredField: true,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _lastNameController,
                  label: 'Nom',
                  icon: Icons.person_outline,
                  requiredField: true,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _studentNumberController,
                  label: 'Matricule EMSI',
                  icon: Icons.badge_outlined,
                  hint: 'Exemple : votre numéro de matricule',
                  requiredField: true,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Localisation EMSI',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _selectedCity,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Ville',
                    icon: Icons.location_city_outlined,
                  ),
                  items: _cities.map((city) {
                    return DropdownMenuItem(
                      value: city,
                      child: Text(city),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCity = value;
                      _campusController.clear();
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Sélectionne ta ville.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _campusController,
                  label: 'Campus EMSI',
                  icon: Icons.location_on_outlined,
                  hint: 'Saisis le nom exact de ton campus',
                  requiredField: true,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Parcours académique',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _selectedBranch,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Filière',
                    icon: Icons.school_outlined,
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
                      return 'Sélectionne ta filière.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<int>(
                  initialValue: _selectedStudyYear,
                  decoration: _inputDecoration(
                    label: 'Année d’étude',
                    icon: Icons.calendar_today_outlined,
                  ),
                  items: List.generate(5, (index) {
                    final year = index + 1;
                    return DropdownMenuItem(
                      value: year,
                      child: Text('Année $year'),
                    );
                  }),
                  onChanged: (value) {
                    setState(() {
                      _selectedStudyYear = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Sélectionne ton année.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                const Text(
                  'Projet professionnel',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _targetRoleController,
                  label: 'Métier souhaité',
                  icon: Icons.work_outline,
                  hint: 'Exemple : Software Engineer',
                  requiredField: true,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _bioController,
                  label: 'À propos de moi',
                  icon: Icons.description_outlined,
                  hint: 'Présente brièvement tes intérêts et tes objectifs.',
                  maxLines: 4,
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: _emsiGreen,
                    title: const Text(
                      'Apparaître sur la carte EMSI',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Si tu actives cette option, les autres étudiants '
                      'pourront voir ton nom, ton prénom, ton matricule '
                      'et ton campus. Ta position GPS personnelle '
                      'ne sera pas utilisée.',
                    ),
                    value: _showOnMap,
                    onChanged: (value) {
                      setState(() {
                        _showOnMap = value;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _emsiGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Enregistrer mon profil',
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
