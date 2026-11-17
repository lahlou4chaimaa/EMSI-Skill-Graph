
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveLocationEntry {
  final String studentId;
  final String firstName;
  final String lastName;
  final String studentNumber;
  final String campus;
  final String city;
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;

  const LiveLocationEntry({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.studentNumber,
    required this.campus,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.updatedAt,
  });

  String get fullName {
    return '$firstName $lastName'.trim();
  }

  factory LiveLocationEntry.fromMap(
    Map<String, dynamic> map,
  ) {
    return LiveLocationEntry(
      studentId: map['student_id']?.toString() ?? '',
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
      studentNumber: map['student_number']?.toString() ?? '',
      campus: map['campus']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }
}

class LiveLocationMapService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<LiveLocationEntry>> getVisibleLiveLocations() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response =
        await _client.rpc('get_visible_live_locations');

    if (response is! List) {
      return [];
    }

    return response
        .map(
          (item) => LiveLocationEntry.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
