
class StudentProfile {
  final String id;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? studentNumber;
  final String? email;
  final String? city;
  final String? campus;
  final String? branch;
  final int? studyYear;
  final String? targetRole;
  final String? bio;
  final bool showOnMap;

  const StudentProfile({
    required this.id,
    this.fullName,
    this.firstName,
    this.lastName,
    this.studentNumber,
    this.email,
    this.city,
    this.campus,
    this.branch,
    this.studyYear,
    this.targetRole,
    this.bio,
    this.showOnMap = false,
  });

  factory StudentProfile.fromMap(Map<String, dynamic> map) {
    return StudentProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      studentNumber: map['student_number'] as String?,
      email: map['email'] as String?,
      city: map['city'] as String?,
      campus: map['campus'] as String?,
      branch: map['branch'] as String?,
      studyYear: map['study_year'] as int?,
      targetRole: map['target_role'] as String?,
      bio: map['bio'] as String?,
      showOnMap: map['show_on_map'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'first_name': firstName,
      'last_name': lastName,
      'student_number': studentNumber,
      'email': email,
      'city': city,
      'campus': campus,
      'branch': branch,
      'study_year': studyYear,
      'target_role': targetRole,
      'bio': bio,
      'show_on_map': showOnMap,
    };
  }
}
