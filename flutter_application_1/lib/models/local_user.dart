class LocalUser {
  const LocalUser({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  factory LocalUser.fromMap(Map<String, Object?> row) {
    final id = row['id'];
    final name = row['name'];
    final email = row['email'];
    final createdAt = row['created_at'];
    if (id is! int ||
        name is! String ||
        email is! String ||
        createdAt is! String) {
      throw const FormatException('User record has invalid fields.');
    }

    return LocalUser(
      id: id.toString(),
      name: name,
      email: email,
      createdAt: DateTime.parse(createdAt),
    );
  }
}
