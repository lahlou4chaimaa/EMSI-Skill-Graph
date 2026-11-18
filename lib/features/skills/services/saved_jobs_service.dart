
import 'package:supabase_flutter/supabase_flutter.dart';

class SavedJobsService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _studentId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    return user.id;
  }

  /// Returns the IDs of all jobs saved by the current student.
  Future<Set<String>> getSavedJobIds() async {
    final data = await _client
        .from('student_saved_jobs')
        .select('job_id')
        .eq('student_id', _studentId);

    return data
        .map((item) => item['job_id'] as String)
        .toSet();
  }

  /// Checks whether a job is already saved.
  Future<bool> isJobSaved(String jobId) async {
    final data = await _client
        .from('student_saved_jobs')
        .select('id')
        .eq('student_id', _studentId)
        .eq('job_id', jobId)
        .maybeSingle();

    return data != null;
  }

  /// Saves a job for the current student.
  Future<void> saveJob(String jobId) async {
    await _client.from('student_saved_jobs').upsert(
      {
        'student_id': _studentId,
        'job_id': jobId,
      },
      onConflict: 'student_id,job_id',
      ignoreDuplicates: true,
    );
  }

  /// Removes a saved job.
  Future<void> removeSavedJob(String jobId) async {
    await _client
        .from('student_saved_jobs')
        .delete()
        .eq('student_id', _studentId)
        .eq('job_id', jobId);
  }
}
