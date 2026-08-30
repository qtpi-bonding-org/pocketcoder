import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/infrastructure/agent_config/agent_config_daos.dart';

void main() {
  group('PocoConfigDao', () {
    test('wires the given PocketBase instance', () {
      final pb = PocketBase('http://unused.local');
      final dao = PocoConfigDao(pb);
      expect(dao.pb, same(pb));
    });
  });

  group('PromptDao', () {
    test('wires the given PocketBase instance', () {
      final pb = PocketBase('http://unused.local');
      final dao = PromptDao(pb);
      expect(dao.pb, same(pb));
    });
  });

  group('PermissionModeDao', () {
    test('wires the given PocketBase instance', () {
      final pb = PocketBase('http://unused.local');
      final dao = PermissionModeDao(pb);
      expect(dao.pb, same(pb));
    });
  });
}
