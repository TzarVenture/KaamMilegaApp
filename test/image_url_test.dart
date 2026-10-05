import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_milega/core/constants/api_constants.dart';

void main() {
  group('Image links', () {
    test('own server over http becomes https (Android blocks http)', () {
      expect(
        ApiConstants.resolveImageUrl(
          'http://api.kaammilega.com/api/files/uploads/a.jpg',
        ),
        'https://api.kaammilega.com/api/files/uploads/a.jpg',
      );
      expect(
        ApiConstants.resolveImageUrl('http://kaammilega.com/x.png'),
        'https://kaammilega.com/x.png',
      );
    });

    test('a path from the upload service gets the server address', () {
      expect(
        ApiConstants.resolveImageUrl('/api/files/uploads/a.jpg'),
        'https://api.kaammilega.com/api/files/uploads/a.jpg',
      );
    });

    test('other links and empty values are left as they are', () {
      const other = 'http://example.com/a.jpg';
      expect(ApiConstants.resolveImageUrl(other), other);
      const secure = 'https://cdn.example.com/a.jpg';
      expect(ApiConstants.resolveImageUrl(secure), secure);
      expect(ApiConstants.resolveImageUrl(''), '');
      expect(ApiConstants.resolveImageUrl(null), '');
    });
  });
}
