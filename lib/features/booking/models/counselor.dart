/// A counselor a student can book a session with.
///
/// Stored in the shared `users` collection with `role == 'counselor'`.
class Counselor {
  final String id;
  final String name;
  final String title;
  final String specialization;
  final String about;
  final List<String> languages;

  const Counselor({
    required this.id,
    required this.name,
    this.title = 'Counselor',
    this.specialization = 'General wellbeing',
    this.about = '',
    this.languages = const ['English'],
  });

  String get initials {
    final parts = name
        .replaceAll(RegExp(r'^(Dr\.|Mr\.|Ms\.|Mrs\.)\s*'), '')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory Counselor.fromMap(String id, Map<String, dynamic> map) {
    return Counselor(
      id: id,
      name: (map['name'] as String?) ?? 'Counselor',
      title: (map['title'] as String?) ?? 'Counselor',
      specialization: (map['specialization'] as String?) ?? 'General wellbeing',
      about: (map['about'] as String?) ?? '',
      languages:
          (map['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['English'],
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'title': title,
    'specialization': specialization,
    'about': about,
    'languages': languages,
    'role': 'counselor',
  };
}
