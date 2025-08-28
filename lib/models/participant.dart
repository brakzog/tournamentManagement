import 'package:meta/meta.dart';

@immutable
class Participant {
  final String id;
  final String name;
  final String? email;

  const Participant({
    required this.id,
    required this.name,
    this.email,
  });

  factory Participant.fromJson(Map<String, dynamic> json, {required String id}) {
    return Participant(
      id: id,
      name: (json['name'] ?? '') as String,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (email != null) 'email': email,
  };
}
