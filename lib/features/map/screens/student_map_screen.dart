import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/live_location_map_service.dart';
import '../services/student_map_service.dart';
import 'live_location_settings_screen.dart';

class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  final StudentMapService _mapService = StudentMapService();
  final LiveLocationMapService _liveLocationService =
      LiveLocationMapService();

  final TextEditingController _searchController =
      TextEditingController();

  List<StudentMapEntry> _students = [];
  List<LiveLocationEntry> _liveLocations = [];

  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  bool _liveMode = false;

  static const Color _emsiGreen = Color(0xFF16834A);
  static const Color _darkGreen = Color(0xFF105C40);

  static const LatLng _moroccoCenter = LatLng(
    31.7917,
    -7.0926,
  );

  @override
  void initState() {
    super.initState();
    _loadCampusStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCampusStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final students = await _mapService.getVisibleStudents();

      if (!mounted) return;

      setState(() {
        _students = students;
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

  Future<void> _loadLiveLocations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final locations =
          await _liveLocationService.getVisibleLiveLocations();

      if (!mounted) return;

      setState(() {
        _liveLocations = locations;
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

  Future<void> _switchMode(bool liveMode) async {
    if (_liveMode == liveMode) return;

    setState(() {
      _liveMode = liveMode;
      _searchQuery = '';
      _searchController.clear();
    });

    if (liveMode) {
      await _loadLiveLocations();
    } else {
      await _loadCampusStudents();
    }
  }

  Future<void> _refresh() async {
    if (_liveMode) {
      await _loadLiveLocations();
    } else {
      await _loadCampusStudents();
    }
  }

  List<StudentMapEntry> get _filteredStudents {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _students;
    }

    return _students.where((student) {
      return student.fullName.toLowerCase().contains(query) ||
          student.studentNumber.toLowerCase().contains(query) ||
          student.campusName.toLowerCase().contains(query) ||
          student.city.toLowerCase().contains(query);
    }).toList();
  }

  List<LiveLocationEntry> get _filteredLiveLocations {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _liveLocations;
    }

    return _liveLocations.where((student) {
      return student.fullName.toLowerCase().contains(query) ||
          student.studentNumber.toLowerCase().contains(query) ||
          student.campus.toLowerCase().contains(query) ||
          student.city.toLowerCase().contains(query);
    }).toList();
  }

  void _openLocationSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LiveLocationSettingsScreen(),
      ),
    );
  }

  void _showStudentDetails(StudentMapEntry student) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHandle(),
              const SizedBox(height: 22),
              Row(
                children: [
                  _buildAvatar(student.firstName),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      student.fullName.isEmpty
                          ? 'Étudiant EMSI'
                          : student.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _detailRow(
                Icons.badge_outlined,
                'Matricule',
                student.studentNumber,
              ),
              _detailRow(
                Icons.school_outlined,
                'Campus',
                student.campusName,
              ),
              _detailRow(
                Icons.location_city_outlined,
                'Ville',
                student.city,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showLiveLocationDetails(LiveLocationEntry student) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHandle(),
              const SizedBox(height: 22),
              Row(
                children: [
                  _buildAvatar(student.firstName),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      student.fullName.isEmpty
                          ? 'Étudiant EMSI'
                          : student.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _detailRow(
                Icons.badge_outlined,
                'Matricule',
                student.studentNumber,
              ),
              _detailRow(
                Icons.school_outlined,
                'Campus',
                student.campus,
              ),
              _detailRow(
                Icons.location_city_outlined,
                'Ville',
                student.city,
              ),
              _detailRow(
                Icons.gps_fixed,
                'Position',
                'GPS en direct',
              ),
              if (student.updatedAt != null)
                _detailRow(
                  Icons.access_time,
                  'Mise à jour',
                  _formatDate(student.updatedAt!),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildAvatar(String firstName) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: _emsiGreen.withValues(alpha: 0.12),
      child: Text(
        firstName.isNotEmpty
            ? firstName[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: _emsiGreen,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(
            icon,
            color: _emsiGreen,
            size: 21,
          ),
          const SizedBox(width: 12),
          Text(
            '$label : ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampusMarker(StudentMapEntry student) {
    return GestureDetector(
      onTap: () => _showStudentDetails(student),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _emsiGreen,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildLiveMarker(LiveLocationEntry student) {
    return GestureDetector(
      onTap: () => _showLiveLocationDetails(student),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.blue.shade600,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.my_location,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              selected: !_liveMode,
              icon: Icons.school_outlined,
              label: 'Campus',
              onTap: () => _switchMode(false),
            ),
          ),
          Expanded(
            child: _buildModeButton(
              selected: _liveMode,
              icon: Icons.my_location,
              label: 'En direct',
              onTap: () => _switchMode(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          vertical: 11,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected
                  ? _emsiGreen
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? _darkGreen
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final campusStudents = _filteredStudents;
    final liveStudents = _filteredLiveLocations;

    return FlutterMap(
      options: const MapOptions(
        initialCenter: _moroccoCenter,
        initialZoom: 5.5,
        minZoom: 4,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),

        if (!_liveMode)
          MarkerLayer(
            markers: campusStudents.map((student) {
              return Marker(
                point: LatLng(
                  student.latitude,
                  student.longitude,
                ),
                width: 48,
                height: 48,
                child: _buildCampusMarker(student),
              );
            }).toList(),
          ),

        if (_liveMode)
          MarkerLayer(
            markers: liveStudents.map((student) {
              return Marker(
                point: LatLng(
                  student.latitude,
                  student.longitude,
                ),
                width: 52,
                height: 52,
                child: _buildLiveMarker(student),
              );
            }).toList(),
          ),

        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyMessage() {
    final empty = _liveMode
        ? _liveLocations.isEmpty
        : _students.isEmpty;

    final message = empty
        ? _liveMode
            ? 'Aucune position GPS visible pour le moment.'
            : 'Aucun étudiant visible sur la carte pour le moment.'
        : 'Aucun étudiant ne correspond à votre recherche.';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
            ),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _liveMode
        ? _filteredLiveLocations.isNotEmpty
        : _filteredStudents.isNotEmpty;

    final hasData = _liveMode
        ? _liveLocations.isNotEmpty
        : _students.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EMSI Student Map',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openLocationSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Partage GPS',
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildModeSelector(),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              12,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: _liveMode
                    ? 'Rechercher une position...'
                    : 'Rechercher un étudiant ou un campus...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                _buildMap(),

                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: _emsiGreen,
                    ),
                  ),

                if (!_loading && _error != null)
                  Center(
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Impossible de charger les positions.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _refresh,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (!_loading &&
                    _error == null &&
                    (!hasData || !hasResults))
                  _buildEmptyMessage(),

                if (!_loading && _error == null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _liveMode
                                ? Icons.my_location
                                : Icons.school_outlined,
                            size: 16,
                            color: _liveMode
                                ? Colors.blue.shade600
                                : _emsiGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _liveMode
                                ? '${_filteredLiveLocations.length} en direct'
                                : '${_filteredStudents.length} étudiant(s)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}