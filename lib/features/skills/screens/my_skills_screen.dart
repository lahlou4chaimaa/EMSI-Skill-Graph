import 'package:flutter/material.dart';

import '../../../models/skill.dart';
import '../../../models/student_skill.dart';
import '../services/skill_service.dart';

class MySkillsScreen extends StatefulWidget {
  const MySkillsScreen({super.key});

  @override
  State<MySkillsScreen> createState() => _MySkillsScreenState();
}

class _MySkillsScreenState extends State<MySkillsScreen> {
  final SkillService _skillService = SkillService();

  List<StudentSkill> _mySkills = [];
  List<Skill> _availableSkills = [];

  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    setState(() {
      _loading = true;
    });

    try {
      final results = await Future.wait([
        _skillService.getMySkills(),
        _skillService.getSkills(),
      ]);

      if (!mounted) return;

      setState(() {
        _mySkills = results[0] as List<StudentSkill>;
        _availableSkills = results[1] as List<Skill>;
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

  Future<void> _showAddSkillDialog() async {
    if (_availableSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No skills available.'),
        ),
      );
      return;
    }

    Skill? selectedSkill;
    int selectedLevel = 1;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add a skill'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Skill>(
                    initialValue: selectedSkill,
                    decoration: const InputDecoration(
                      labelText: 'Skill',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableSkills.map((skill) {
                      return DropdownMenuItem<Skill>(
                        value: skill,
                        child: Text(skill.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSkill = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    initialValue: selectedLevel,
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(5, (index) {
                      final level = index + 1;

                      return DropdownMenuItem<int>(
                        value: level,
                        child: Text(_levelLabel(level)),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedLevel = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedSkill == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext, true);
                        },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || selectedSkill == null) {
      return;
    }

    setState(() {
      _adding = true;
    });

    try {
      await _skillService.addSkill(
        skillId: selectedSkill!.id,
        level: selectedLevel,
      );

      await _loadSkills();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skill added successfully.'),
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
          _adding = false;
        });
      }
    }
  }

  Future<void> _deleteSkill(StudentSkill studentSkill) async {
    try {
      await _skillService.removeSkill(studentSkill.id);

      if (!mounted) return;

      setState(() {
        _mySkills.removeWhere(
          (skill) => skill.id == studentSkill.id,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skill removed.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $error'),
        ),
      );
    }
  }

  String _levelLabel(int level) {
    switch (level) {
      case 1:
        return '1 - Beginner';
      case 2:
        return '2 - Basic';
      case 3:
        return '3 - Intermediate';
      case 4:
        return '4 - Advanced';
      case 5:
        return '5 - Expert';
      default:
        return 'Level $level';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Skills'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadSkills,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adding ? null : _showAddSkillDialog,
        icon: _adding
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add),
        label: const Text('Add skill'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _mySkills.isEmpty
              ? _EmptySkills(
                  onAdd: _showAddSkillDialog,
                )
              : RefreshIndicator(
                  onRefresh: _loadSkills,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      100,
                    ),
                    children: [
                      const Text(
                        'Your Skill Graph',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_mySkills.length} skill${_mySkills.length > 1 ? 's' : ''} in your profile',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ..._mySkills.map(
                        (studentSkill) => _SkillCard(
                          studentSkill: studentSkill,
                          levelLabel: _levelLabel(
                            studentSkill.level,
                          ),
                          onDelete: () {
                            _deleteSkill(studentSkill);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final StudentSkill studentSkill;
  final String levelLabel;
  final VoidCallback onDelete;

  const _SkillCard({
    required this.studentSkill,
    required this.levelLabel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final skill = studentSkill.skill;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.psychology_outlined,
                color: Color(0xFF356AE6),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill?.name ?? 'Unknown skill',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    skill?.category ?? 'General',
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    levelLabel,
                    style: const TextStyle(
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            IconButton(
              tooltip: 'Remove',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySkills extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptySkills({
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_tree_outlined,
              size: 72,
              color: Color(0xFF356AE6),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Skill Graph is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add your technical and professional skills to start building your career profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add your first skill'),
            ),
          ],
        ),
      ),
    );
  }
}