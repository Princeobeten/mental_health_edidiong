/// A locally-stored user account (for the Login/Register flow in Chapter 4).
class AppUser {
  final int? id;
  final String fullName;
  final String email;
  final bool isAdmin;
  final DateTime createdAt;

  AppUser({
    this.id,
    required this.fullName,
    required this.email,
    this.isAdmin = false,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
        id: map['id'] as int?,
        fullName: map['full_name'] as String,
        email: map['email'] as String,
        isAdmin: (map['is_admin'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
