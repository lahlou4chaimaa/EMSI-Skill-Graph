class StudentProfile {
  final String id;
  final String? fullName;
  final String? email;
  final String? campus;
  final String? branch;
  final int? studyYear;
  final String? targetRole;
  final String? bio;

  const StudentProfile({
    required this.id,
    this.fullName,
    this.email,
    this.campus,
    this.branch,
    this.studyYear,
    this.targetRole,
    this.bio,
  });

  factory StudentProfile.fromMap(Map<String, dynamic> map) {
    return StudentProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      email: map['email'] as String?,
      campus: map['campus'] as String?,
      branch: map['branch'] as String?,
      studyYear: map['study_year'] as int?,
      targetRole: map['target_role'] as String?,
      bio: map['bio'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'campus': campus,
      'branch': branch,
      'study_year': studyYear,
      'target_role': targetRole,
      'bio': bio,
    };
  }
}