
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/student_profile.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<StudentProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;

    return StudentProfile.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  Future<StudentProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String studentNumber,
    required String city,
    required String campus,
    required String branch,
    required int studyYear,
    required String targetRole,
    required String bio,
    required bool showOnMap,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    final cleanFirstName = firstName.trim();
    final cleanLastName = lastName.trim();
    final cleanStudentNumber = studentNumber.trim();

    if (cleanFirstName.isEmpty ||
        cleanLastName.isEmpty ||
        cleanStudentNumber.isEmpty) {
      throw Exception('Le prénom, le nom et le matricule sont obligatoires.');
    }

    final data = await _client
        .from('profiles')
        .update({
          'first_name': cleanFirstName,
          'last_name': cleanLastName,
          'full_name': '$cleanFirstName $cleanLastName',
          'student_number': cleanStudentNumber,
          'city': city,
          'campus': campus,
          'branch': branch,
          'study_year': studyYear,
          'target_role': targetRole.trim(),
          'bio': bio.trim(),
          'show_on_map': showOnMap,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', user.id)
        .select()
        .single();

    return StudentProfile.fromMap(
      Map<String, dynamic>.from(data),
    );
  }
}
