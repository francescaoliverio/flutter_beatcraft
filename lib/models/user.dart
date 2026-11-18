/// A DummyJSON user, reduced to the fields the app shows.
class User {
  const User({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.image,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      image: json['image'] as String,
    );
  }

  final int id;
  final String username;
  final String firstName;
  final String lastName;

  /// Avatar URL.
  final String image;

  String get fullName => '$firstName $lastName';
}
