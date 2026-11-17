import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/student_map_service.dart';

class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  final StudentMapService _mapService = StudentMapService();
  final TextEditingController _searchController = TextEditingController();

  List<StudentMapEntry> _students = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  static const Color _emsiGreen = Color(0xFF16834A);
  static const LatLng _moroccoCenter = LatLng(31.7917, -7.0926);

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
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

  List<StudentMapEntry> get _filteredStudents {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return _students;

    return _students.where((student) {
      return student.fullName.toLowerCase().contains(query) ||
          student.studentNumber.toLowerCase().contains(query) ||
          student.campusName.toLowerCase().contains(query) ||
          student.city.toLowerCase().contains(query);
    }).toList();
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
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _emsiGreen.withValues(alpha: 0.12),
                    child: Text(
                      student.firstName.isNotEmpty
                          ? student.firstName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: _emsiGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: _emsiGreen, size: 21),
          const SizedBox(width: 12),
          Text(
            '$label : ',
            style: const TextStyle(fontWeight: FontWeight.w600),
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

  Widget _buildMarker(StudentMapEntry student) {
    return GestureDetector(
      onTap: () => _showStudentDetails(student),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _emsiGreen,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
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

  @override
  Widget build(BuildContext context) {
    final visibleStudents = _filteredStudents;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EMSI Student Map',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadStudents,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un étudiant ou un campus...',
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
                FlutterMap(
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
                    MarkerLayer(
                      markers: visibleStudents.map((student) {
                        return Marker(
                          point: LatLng(
                            student.latitude,
                            student.longitude,
                          ),
                          width: 48,
                          height: 48,
                          child: _buildMarker(student),
                        );
                      }).toList(),
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),

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
                              'Impossible de charger les étudiants.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadStudents,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (!_loading && _error == null && visibleStudents.isEmpty)
                  Align(
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
                        _students.isEmpty
                            ? 'Aucun étudiant visible sur la carte pour le moment.'
                            : 'Aucun étudiant ne correspond à votre recherche.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
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