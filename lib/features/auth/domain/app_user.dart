enum UserRole {
  user,
  teacher,
  admin;

  static UserRole parse(String? v) =>
      UserRole.values.firstWhere((e) => e.name == v, orElse: () => UserRole.user);

  bool get canManageContent => this == teacher || this == admin;
}

class AppUser {
  const AppUser({required this.uid, this.email, this.displayName, this.photoUrl, this.role = UserRole.user});
  final String uid;
  final String? email, displayName, photoUrl;
  final UserRole role; // procedente de Custom Claims, nunca de un campo editable
}
