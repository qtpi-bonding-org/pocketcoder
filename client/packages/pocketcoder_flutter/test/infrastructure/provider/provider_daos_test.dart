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

    test('uses a longer getFullList timeout than the 10s default', () {
      final dao = ModelDao(PocketBase('http://unused.local'));
      expect(dao.getFullListTimeout, greaterThan(const Duration(seconds: 10)));
    });
  });

  group('HarnessModelDao', () {
    test('wires the given PocketBase instance', () {
      final pb = PocketBase('http://unused.local');
      final dao = HarnessModelDao(pb);
      expect(dao.pb, same(pb));
    });

    test('uses a longer getFullList timeout than the 10s default', () {
      final dao = HarnessModelDao(PocketBase('http://unused.local'));
      expect(dao.getFullListTimeout, greaterThan(const Duration(seconds: 10)));
    });
  });

  group('ProviderAPIKeyDao', () {
    test('wires the given PocketBase instance', () {
      final pb = PocketBase('http://unused.local');
      final dao = ProviderAPIKeyDao(pb);
      expect(dao.pb, same(pb));
    });
  });

  group('HarnessProviderDao', () {
    test('wires the given PocketBase instance', () {
      final pb = PocketBase('http://unused.local');
      final dao = HarnessProviderDao(pb);
      expect(dao.pb, same(pb));
    });
  });
}
