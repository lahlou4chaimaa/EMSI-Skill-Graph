class Job {
  final String id;
  final String title;
  final String? company;
  final String? description;

  const Job({
    required this.id,
    required this.title,
    this.company,
    this.description,
  });

  factory Job.fromMap(Map<String, dynamic> map) {
    return Job(
      id: map['id'] as String,
      title: map['title'] as String,
      company: map['company'] as String?,
      description: map['description'] as String?,
    );
  }
}