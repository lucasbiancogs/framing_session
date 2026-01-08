import 'package:whiteboard/domain/entities/user.dart';

class UserDto {
  const UserDto({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final String color;

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
    );
  }

  factory UserDto.fromEntity(User entity) =>
      UserDto(id: entity.id, name: entity.name, color: entity.color);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  User toEntity() => User(id: id, name: name, color: color);
}
