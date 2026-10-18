import 'dart:convert';

/// Representation of a registered SignTalk user account.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'email': email,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? 'User',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'ISL Communicator',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AuthUser.fromJson(String source) =>
      AuthUser.fromMap(jsonDecode(source) as Map<String, dynamic>);

  AuthUser copyWith({
    String? name,
    String? email,
    String? role,
  }) {
    return AuthUser(
      id: id,
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt,
    );
  }
}
