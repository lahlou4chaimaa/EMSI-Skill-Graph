import 'package:supabase_flutter/supabase_flutter.dart';

class StudentMapEntry {
  final String id;
  final String firstName;
  final String lastName;
  final String studentNumber;
  final String campusName;
  final String city;
  final double latitude;
  final double longitude;

  const StudentMapEntry({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.studentNumber,
    required this.campusName,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  factory StudentMapEntry.fromMap(Map<String, dynamic> map) {
    return StudentMapEntry(
      id: map['id'].toString(),
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
      studentNumber: map['student_number']?.toString() ?? '',
      campusName: map['campus_name']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

class StudentMapService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<StudentMapEntry>> getVisibleStudents() async {
    if (_client.auth.currentUser == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _client.rpc('get_student_map_profiles');

    final rows = response as List<dynamic>;

    return rows
        .map(
          (item) => StudentMapEntry.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}