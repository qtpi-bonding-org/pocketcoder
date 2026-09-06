// test/infrastructure/errors/error_code_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/exceptions/chat_list_exception.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/error_code_mapper.dart';

void main() {
  group('PocketCoderErrorCodeMapper.mapError', () {
    test('maps known domain exceptions to stable codes', () {
      expect(
          PocketCoderErrorCodeMapper.mapError(AuthException('x')), 'AUTH_001');
      expect(
          PocketCoderErrorCodeMapper.mapError(ChatException('x')), 'CHAT_001');
      expect(PocketCoderErrorCodeMapper.mapError(ChatListException('x')),
          'CHATLIST_001');
      expect(PocketCoderErrorCodeMapper.mapError(PermissionException('x')),
          'PERM_001');
      expect(PocketCoderErrorCodeMapper.mapError(AiException('x')), 'AI_001');
      expect(PocketCoderErrorCodeMapper.mapError(ToolPermissionsException('x')),
          'TOOLPERM_001');
      expect(PocketCoderErrorCodeMapper.mapError(RepositoryException('x')),
          'REPO_001');
      expect(PocketCoderErrorCodeMapper.mapError(McpException('x')), 'MCP_001');
      expect(PocketCoderErrorCodeMapper.mapError(McpOAuthException('x')),
          'MCP_002');
      expect(PocketCoderErrorCodeMapper.mapError(ObservabilityException('x')),
          'OBS_001');
      expect(PocketCoderErrorCodeMapper.mapError(SkillsException('x')),
          'SKILLS_001');
      expect(PocketCoderErrorCodeMapper.mapError(SchedulerException('x')),
          'SCHED_001');
      expect(PocketCoderErrorCodeMapper.mapError(FilesException('x')),
          'FILES_001');
    });

    test('falls back to ERR_<Type> for unmapped exception types', () {
      expect(PocketCoderErrorCodeMapper.mapError(FormatException('x')),
          'ERR_FormatException');
      expect(PocketCoderErrorCodeMapper.mapError(StateError('x')),
          'ERR_StateError');
    });
  });
}
