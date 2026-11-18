import 'package:flutter_beatcraft/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User.fromJson', () {
    test('reads the fields from a DummyJSON login response', () {
      final user = User.fromJson({
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'id': 1,
        'username': 'emilys',
        'email': 'emily.johnson@x.dummyjson.com',
        'firstName': 'Emily',
        'lastName': 'Johnson',
        'gender': 'female',
        'image': 'https://dummyjson.com/icon/emilys/128',
      });

      expect(user.id, 1);
      expect(user.username, 'emilys');
      expect(user.firstName, 'Emily');
      expect(user.lastName, 'Johnson');
      expect(user.image, 'https://dummyjson.com/icon/emilys/128');
      expect(user.fullName, 'Emily Johnson');
    });

    test('throws when a field is missing', () {
      expect(() => User.fromJson({'id': 1, 'username': 'emilys'}), throwsA(isA<TypeError>()));
    });
  });
}
