import 'dart:convert';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final DateTime createdAt;
  final bool isAnonymous;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.createdAt,
    this.isAnonymous = false,
  });

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    DateTime? createdAt,
    bool? isAnonymous,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  Map<String, dynamic> toMap({bool includePassword = true}) {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': includePassword ? password : '',
      'createdAt': createdAt.toIso8601String(),
      'isAnonymous': isAnonymous,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      password: (map['password'] as String?) ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      isAnonymous: (map['isAnonymous'] as bool?) ?? false,
    );
  }

  String toJson({bool includePassword = true}) =>
      json.encode(toMap(includePassword: includePassword));

  String toSessionJson() => toJson(includePassword: false);

  factory AppUser.fromJson(String source) =>
      AppUser.fromMap(json.decode(source) as Map<String, dynamic>);
}
