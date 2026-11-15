import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/student_profile.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<StudentProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return StudentProfile.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  Future<StudentProfile> updateProfile({
    required String fullName,
    required String campus,
    required String branch,
    required int studyYear,
    required String targetRole,
    required String bio,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    final data = await _client
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'campus': campus,
          'branch': branch,
          'study_year': studyYear,
          'target_role': targetRole.trim(),
          'bio': bio.trim(),
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