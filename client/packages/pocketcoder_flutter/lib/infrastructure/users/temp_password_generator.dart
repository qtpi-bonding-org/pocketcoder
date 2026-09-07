import 'dart:math';

// Excludes visually ambiguous characters (0/O, 1/l/I) -- an admin may
// need to read this aloud or retype it if copy/paste isn't available.
const _unambiguousCharset =
    'ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';

// 8 is PocketBase's users.password field minimum.
String generateTempPassword() {
  final random = Random.secure();
  return List.generate(
    8,
    (_) => _unambiguousCharset[random.nextInt(_unambiguousCharset.length)],
  ).join();
}
