import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/student_skill.dart';
import '../services/skill_service.dart';
import 'my_skills_screen.dart';

class SkillGraphScreen extends StatefulWidget {
  const SkillGraphScreen({super.key});

  @override
  State<SkillGraphScreen> createState() => _SkillGraphScreenState();
}

class _SkillGraphScreenState extends State<SkillGraphScreen> {
  final SkillService _skillService = SkillService();

  List<StudentSkill> _studentSkills = [];
  bool _loading = true;
  String? _error;

  static const Color primaryBlue = Color(0xFF356AE6);
  static const Color darkBlue = Color(0xFF172B4D);

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final skills = await _skillService.getMySkills();

      if (!mounted) return;

      setState(() {
        _studentSkills = skills.where((item) => item.skill != null).toList();
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

  Map<String, List<StudentSkill>> get _groupedSkills {
    final Map<String, List<StudentSkill>> groups = {};

    for (final studentSkill in _studentSkills) {
      final category = studentSkill.skill?.category;

      final categoryName = category == null || category.trim().isEmpty
          ? 'Other'
          : category;

      groups.putIfAbsent(categoryName, () => []);
      groups[categoryName]!.add(studentSkill);
    }

    final sortedEntries = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return {for (final entry in sortedEntries) entry.key: entry.value};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('My Skill Graph'),
        backgroundColor: Colors.white,
        foregroundColor: darkBlue,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadSkills,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh skills',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildError();
    }

    if (_studentSkills.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: _loadSkills,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildIntroduction(),
          const SizedBox(height: 18),
          _buildSummary(),
          const SizedBox(height: 18),
          _buildGraphCard(),
          const SizedBox(height: 18),
          _buildLegend(),
          const SizedBox(height: 20),
          _buildCategoryList(),
          const SizedBox(height: 20),
          _buildManageSkillsButton(),
        ],
      ),
    );
  }

  Widget _buildIntroduction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Explore your skills',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Visualize your skills and how they are organized into different technical categories.',
          style: TextStyle(
            color: Colors.grey.shade700,
            height: 1.5,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final categories = _groupedSkills.length;

    final average = _studentSkills.isEmpty
        ? 0.0
        : _studentSkills.fold<int>(0, (sum, item) => sum + item.level) /
              _studentSkills.length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            Icons.psychology_outlined,
            '${_studentSkills.length}',
            'Skills',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            Icons.category_outlined,
            '$categories',
            'Categories',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            Icons.star_outline,
            average.toStringAsFixed(1),
            'Average level',
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: primaryBlue, size: 23),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphCard() {
    final groups = _groupedSkills;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              'Your skill network',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a skill node to see its details.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final graphSize = math.min(constraints.maxWidth, 420.0);

                final nodes = _buildGraphNodes(groups, graphSize);

                return SizedBox(
                  width: graphSize,
                  height: graphSize,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      _handleGraphTap(details.localPosition, nodes);
                    },
                    child: CustomPaint(
                      size: Size(graphSize, graphSize),
                      painter: _SkillGraphPainter(
                        nodes: nodes,
                        categoryCount: groups.length,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<_GraphNode> _buildGraphNodes(
    Map<String, List<StudentSkill>> groups,
    double graphSize,
  ) {
    const baseSize = 420.0;
    final scale = graphSize / baseSize;

    final center = Offset(graphSize / 2, graphSize / 2);

    final entries = groups.entries.toList();
    final categoryCount = entries.length;

    final nodes = <_GraphNode>[];

    if (categoryCount == 0) return nodes;

    for (int i = 0; i < categoryCount; i++) {
      final entry = entries[i];

      final categoryAngle = -math.pi / 2 + (2 * math.pi * i / categoryCount);

      final categoryPosition = Offset(
        center.dx + math.cos(categoryAngle) * 92 * scale,
        center.dy + math.sin(categoryAngle) * 92 * scale,
      );

      nodes.add(
        _GraphNode(
          position: categoryPosition,
          radius: 31 * scale,
          category: entry.key,
          isCategory: true,
          color: _categoryColor(i),
        ),
      );

      final skills = entry.value;
      final skillCount = skills.length;

      final spread = categoryCount == 1
          ? 2 * math.pi
          : (2 * math.pi / categoryCount) * 0.72;

      for (int j = 0; j < skillCount; j++) {
        final offsetAngle = skillCount == 1
            ? 0.0
            : ((j / (skillCount - 1)) - 0.5) * spread;

        final angle = categoryAngle + offsetAngle;

        final skillPosition = Offset(
          center.dx + math.cos(angle) * 165 * scale,
          center.dy + math.sin(angle) * 165 * scale,
        );

        final studentSkill = skills[j];

        nodes.add(
          _GraphNode(
            position: skillPosition,
            radius: 25 * scale,
            category: entry.key,
            studentSkill: studentSkill,
            isCategory: false,
            color: _levelColor(studentSkill.level),
          ),
        );
      }
    }

    return nodes;
  }

  Color _categoryColor(int index) {
    const colors = [
      Color(0xFF356AE6),
      Color(0xFF7454C8),
      Color(0xFF168A83),
      Color(0xFFE18A36),
      Color(0xFFB94D79),
      Color(0xFF527BBA),
      Color(0xFF738B42),
      Color(0xFF9264A8),
    ];

    return colors[index % colors.length];
  }

  Color _levelColor(int level) {
    if (level <= 1) return const Color(0xFFD9534F);
    if (level == 2) return const Color(0xFFE69A22);
    if (level == 3) return const Color(0xFFB9A52D);
    if (level == 4) return const Color(0xFF356AE6);

    return const Color(0xFF16865B);
  }

  void _handleGraphTap(Offset position, List<_GraphNode> nodes) {
    for (final node in nodes.reversed) {
      final distance = (position - node.position).distance;

      if (distance <= node.radius + 5) {
        if (node.isCategory) {
          final count = _groupedSkills[node.category]?.length ?? 0;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${node.category}: $count skills'),
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (node.studentSkill != null) {
          _showSkillDetails(node.studentSkill!);
        }

        return;
      }
    }
  }

  void _showSkillDetails(StudentSkill studentSkill) {
    final skill = studentSkill.skill;

    if (skill == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  skill.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                _detailRow(
                  Icons.category_outlined,
                  'Category',
                  skill.category ?? 'Other',
                ),
                _detailRow(
                  Icons.signal_cellular_alt,
                  'Current level',
                  '${studentSkill.level}/5',
                ),
                _detailRow(
                  Icons.source_outlined,
                  'Source',
                  studentSkill.source ?? 'Not specified',
                ),
                if (skill.description != null &&
                    skill.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    skill.description!,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryBlue),
          const SizedBox(width: 10),
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Skill level legend',
              style: TextStyle(fontWeight: FontWeight.bold, color: darkBlue),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: [
                _legendItem(const Color(0xFFD9534F), 'Level 1'),
                _legendItem(const Color(0xFFE69A22), 'Level 2'),
                _legendItem(const Color(0xFFB9A52D), 'Level 3'),
                _legendItem(const Color(0xFF356AE6), 'Level 4'),
                _legendItem(const Color(0xFF16865B), 'Level 5'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildCategoryList() {
    final groups = _groupedSkills;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Skill categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 12),
        ...groups.entries.map((entry) {
          return Card(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 9),
            child: ExpansionTile(
              leading: const Icon(Icons.folder_outlined, color: primaryBlue),
              title: Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: Text(
                '${entry.value.length}',
                style: const TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: entry.value.map((item) {
                return ListTile(
                  dense: true,
                  title: Text(item.skill?.name ?? 'Unknown skill'),
                  subtitle: Text('Level ${item.level}/5'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _showSkillDetails(item),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildManageSkillsButton() {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MySkillsScreen()),
        ).then((_) => _loadSkills());
      },
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Manage my skills'),
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryBlue,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: primaryBlue),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_tree_outlined,
              size: 60,
              color: primaryBlue,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your skill graph is empty',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add skills to your profile to generate your personal skill graph.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MySkillsScreen()),
                ).then((_) => _loadSkills());
              },
              icon: const Icon(Icons.add),
              label: const Text('Add my skills'),
            ),
          ],
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
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Unable to load your skills',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSkills,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphNode {
  final Offset position;
  final double radius;
  final String category;
  final StudentSkill? studentSkill;
  final bool isCategory;
  final Color color;

  const _GraphNode({
    required this.position,
    required this.radius,
    required this.category,
    required this.isCategory,
    required this.color,
    this.studentSkill,
  });
}

class _SkillGraphPainter extends CustomPainter {
  final List<_GraphNode> nodes;
  final int categoryCount;

  const _SkillGraphPainter({required this.nodes, required this.categoryCount});

  static const Color primaryBlue = Color(0xFF356AE6);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final centerPaint = Paint()
      ..color = primaryBlue
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFFD8E1F0)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw links between the central node and categories.
    for (final node in nodes.where((item) => item.isCategory)) {
      canvas.drawLine(center, node.position, linePaint);
    }

    // Draw links between categories and their skills.
    for (final skillNode in nodes.where((item) => !item.isCategory)) {
      final categoryNode = nodes.firstWhere(
        (item) => item.isCategory && item.category == skillNode.category,
      );

      canvas.drawLine(categoryNode.position, skillNode.position, linePaint);
    }

    // Draw skill nodes.
    for (final node in nodes.where((item) => !item.isCategory)) {
      final paint = Paint()
        ..color = node.color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(node.position, node.radius, paint);

      final name = node.studentSkill?.skill?.name ?? '';

      _drawLabel(
        canvas,
        name,
        node.position,
        node.radius * 1.55,
        fontSize: 8.5 * (size.width / 420),
        color: Colors.white,
        maxLines: 2,
      );

      if (node.studentSkill != null) {
        final level = node.studentSkill!.level.toString();

        final levelPainter = TextPainter(
          text: TextSpan(
            text: level,
            style: TextStyle(
              fontSize: 8 * (size.width / 420),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        levelPainter.paint(
          canvas,
          Offset(
            node.position.dx - levelPainter.width / 2,
            node.position.dy + node.radius * 0.55,
          ),
        );
      }
    }

    // Draw category nodes.
    for (final node in nodes.where((item) => item.isCategory)) {
      canvas.drawCircle(
        node.position,
        node.radius,
        Paint()..color = node.color,
      );

      _drawLabel(
        canvas,
        node.category,
        node.position,
        node.radius * 1.7,
        fontSize: 9 * (size.width / 420),
        color: Colors.white,
        maxLines: 2,
      );
    }

    // Draw the central student node.
    canvas.drawCircle(center, 38 * (size.width / 420), centerPaint);

    _drawLabel(
      canvas,
      'MY\nSKILLS',
      center,
      65 * (size.width / 420),
      fontSize: 10 * (size.width / 420),
      color: Colors.white,
      maxLines: 2,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    double maxWidth, {
    required double fontSize,
    required Color color,
    required int maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SkillGraphPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.categoryCount != categoryCount;
  }
}
