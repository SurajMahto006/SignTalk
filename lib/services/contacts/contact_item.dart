import 'dart:convert';

/// Represents a contact in SignTalk with their profile and status.
class ContactItem {
  const ContactItem({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.isOnline = false,
    this.bio = '',
    required this.addedAt,
  });

  final String id;
  final String username;
  final String name;
  final String role;
  final bool isOnline;
  final String bio;
  final DateTime addedAt;

  String get displayHandle => username.startsWith('@') ? username : '@$username';

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'name': name,
        'role': role,
        'isOnline': isOnline,
        'bio': bio,
        'addedAt': addedAt.toIso8601String(),
      };

  factory ContactItem.fromMap(Map<String, dynamic> map) {
    return ContactItem(
      id: map['id'] as String? ?? '',
      username: map['username'] as String? ?? '',
      name: map['name'] as String? ?? 'User',
      role: map['role'] as String? ?? 'ISL Communicator',
      isOnline: map['isOnline'] as bool? ?? false,
      bio: map['bio'] as String? ?? '',
      addedAt: map['addedAt'] != null
          ? DateTime.tryParse(map['addedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ContactItem.fromJson(String source) =>
      ContactItem.fromMap(jsonDecode(source) as Map<String, dynamic>);

  ContactItem copyWith({
    String? id,
    String? username,
    String? name,
    String? role,
    bool? isOnline,
    String? bio,
    DateTime? addedAt,
  }) {
    return ContactItem(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      bio: bio ?? this.bio,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

enum ContactRequestStatus { pending, accepted, rejected }

/// Represents a friend / contact connection request.
class ContactRequest {
  const ContactRequest({
    required this.id,
    required this.user,
    required this.isIncoming,
    this.status = ContactRequestStatus.pending,
    required this.createdAt,
  });

  final String id;
  final ContactItem user;
  final bool isIncoming;
  final ContactRequestStatus status;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'user': user.toMap(),
        'isIncoming': isIncoming,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  String toJson() => jsonEncode(toMap());

  factory ContactRequest.fromJson(String source) =>
      ContactRequest.fromMap(jsonDecode(source) as Map<String, dynamic>);

  factory ContactRequest.fromMap(Map<String, dynamic> map) {
    return ContactRequest(
      id: map['id'] as String? ?? '',
      user: ContactItem.fromMap(map['user'] as Map<String, dynamic>? ?? {}),
      isIncoming: map['isIncoming'] as bool? ?? true,
      status: ContactRequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ContactRequestStatus.pending,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ContactRequest copyWith({
    String? id,
    ContactItem? user,
    bool? isIncoming,
    ContactRequestStatus? status,
    DateTime? createdAt,
  }) {
    return ContactRequest(
      id: id ?? this.id,
      user: user ?? this.user,
      isIncoming: isIncoming ?? this.isIncoming,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
