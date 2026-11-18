
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/job.dart';

class CareerService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Retrieve all jobs with their required skills.
  Future<List<Job>> getJobs() async {
    final data = await _client
        .from('jobs')
        .select('''
          id,
          title,
          sector,
          description,
          job_skills (
            id,
            job_id,
            skill_id,
            required_level,
            skills (
              id,
              name,
              category,
              description
            )
          )
        ''')
        .order('title');

    return data.map<Job>((item) {
      return Job.fromMap(
        Map<String, dynamic>.from(item),
      );
    }).toList();
  }

  /// Retrieve one job by its ID.
  Future<Job> getJobById(String jobId) async {
    final data = await _client
        .from('jobs')
        .select('''
          id,
          title,
          sector,
          description,
          job_skills (
            id,
            job_id,
            skill_id,
            required_level,
            skills (
              id,
              name,
              category,
              description
            )
          )
        ''')
        .eq('id', jobId)
        .single();

    return Job.fromMap(
      Map<String, dynamic>.from(data),
    );
  }
}
