import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart';

void main() {
  group('HarnesseDao', () {
    test('wires the given PocketBase instance', () {
      final pb = PocketBase('http://unused.local');
      final dao = HarnesseDao(pb);
      expect(dao.pb, same(pb));
    });
  });

  group('ModelDao', () {
    test('wires the given PocketBase instance', () {
      final pb = PocketBase('http://unused.local');
      final dao = ModelDao(pb);
      expect(dao.pb, same(pb));
    });
  });

  group('HarnessModelDao', () {
    test('wires the given PocketBase instance', () {
      final pb = PocketBase('http://unused.local');
      final dao = HarnessModelDao(pb);
      expect(dao.pb, same(pb));
    });
  });

  group('ProviderKeyDao', () {
    test('wires the given PocketBase instance', () {
      final pb = PocketBase('http://unused.local');
      final dao = ProviderKeyDao(pb);
      expect(dao.pb, same(pb));
    });
  });
}
