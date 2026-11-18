import 'package:flutter/material.dart';

import '../../../models/roadmap.dart';
import '../../../models/roadmap_item.dart';
import '../services/roadmap_service.dart';

class RoadmapDetailsScreen extends StatefulWidget {
  final String roadmapId;

  const RoadmapDetailsScreen({
    super.key,
    required this.roadmapId,
  });

  @override
  State<RoadmapDetailsScreen> createState() =>
      _RoadmapDetailsScreenState();
}

class _RoadmapDetailsScreenState
    extends State<RoadmapDetailsScreen> {
  static const Color primaryBlue = Color(0xFF356AE6);
  static const Color darkBlue = Color(0xFF172B4D);

  final RoadmapService _roadmapService = RoadmapService();

  Roadmap? _roadmap;
  bool _isLoading = true;
  String? _errorMessage;
  String? _updatingItemId;

  @override
  void initState() {
    super.initState();
    _loadRoadmap();
  }

  Future<void> _loadRoadmap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final roadmap =
          await _roadmapService.getRoadmapById(widget.roadmapId);

      if (!mounted) return;

      setState(() {
        _roadmap = roadmap;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _updateItemStatus(
    RoadmapItem item,
    RoadmapItemStatus status,
  ) async {
    setState(() {
      _updatingItemId = item.id;
    });

    try {
      await _roadmapService.updateItemStatus(
        itemId: item.id,
        status: status,
      );

      await _loadRoadmap();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update step: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingItemId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Roadmap',
          style: TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: darkBlue,
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadRoadmap,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _roadmap == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _roadmap == null) {
      return _buildErrorState();
    }

    final roadmap = _roadmap;

    if (roadmap == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _loadRoadmap,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _buildOverview(roadmap),
          const SizedBox(height: 24),
          _buildSectionTitle(),
          const SizedBox(height: 12),
          ...roadmap.items
              .toList()
              .asMap()
              .entries
              .map((entry) {
            return _buildItemCard(
              entry.value,
              entry.key,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOverview(Roadmap roadmap) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF356AE6),
            Color(0xFF234AA7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  roadmap.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStat(
                '${roadmap.progressPercentage}%',
                'Progress',
              ),
              _buildDivider(),
              _buildStat(
                '${roadmap.completedItems}',
                'Completed',
              ),
              _buildDivider(),
              _buildStat(
                '${roadmap.estimatedWeeks}',
                'Weeks',
              ),
            ],
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: roadmap.progress,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              valueColor: const AlwaysStoppedAnimation(
                Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.20),
    );
  }

  Widget _buildSectionTitle() {
    return const Row(
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          color: primaryBlue,
          size: 21,
        ),
        SizedBox(width: 8),
        Text(
          'Learning path',
          style: TextStyle(
            color: darkBlue,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(
    RoadmapItem item,
    int index,
  ) {
    final isUpdating = _updatingItemId == item.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: item.isCompleted
              ? Colors.green.withValues(alpha: 0.30)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepNumber(
                  index + 1,
                  item.isCompleted,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: darkBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (item.category != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          item.category!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildPriorityBadge(item.priority),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              item.description ?? '',
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.45,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildLevelBadge(
                  'Current',
                  item.currentLevel,
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                _buildLevelBadge(
                  'Target',
                  item.targetLevel,
                ),
                const Spacer(),
                if (item.estimatedHours > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.estimatedHours}h',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (isUpdating)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              _buildActionButton(item),
          ],
        ),
      ),
    );
  }

  Widget _buildStepNumber(
    int number,
    bool completed,
  ) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: completed
            ? Colors.green.withValues(alpha: 0.12)
            : primaryBlue.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: completed
          ? const Icon(
              Icons.check_rounded,
              color: Colors.green,
              size: 22,
            )
          : Text(
              '$number',
              style: const TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _buildPriorityBadge(RoadmapPriority priority) {
    String label;
    Color color;

    switch (priority) {
      case RoadmapPriority.high:
        label = 'HIGH';
        color = Colors.red;
        break;
      case RoadmapPriority.medium:
        label = 'MEDIUM';
        color = Colors.orange;
        break;
      case RoadmapPriority.low:
        label = 'LOW';
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildLevelBadge(
    String label,
    int level,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $level/5',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButton(RoadmapItem item) {
    if (item.isCompleted) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            _updateItemStatus(
              item,
              RoadmapItemStatus.inProgress,
            );
          },
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Reopen step'),
        ),
      );
    }

    if (item.isInProgress) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            _updateItemStatus(
              item,
              RoadmapItemStatus.completed,
            );
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Mark as completed'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          _updateItemStatus(
            item,
            RoadmapItemStatus.inProgress,
          );
        },
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start learning'),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 54,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load roadmap',
              style: TextStyle(
                color: darkBlue,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loadRoadmap,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}