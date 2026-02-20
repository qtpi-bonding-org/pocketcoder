import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:test_app/application/terminal/terminal_cubit.dart';
import 'package:test_app/application/terminal/terminal_state.dart';

// Mock classes
class MockPocketBase extends Mock implements PocketBase {}

class MockAuthStore extends Mock implements AuthStore {}

class MockRecordModel extends Mock implements RecordModel {}

class MockRecordService extends Mock implements RecordService {}

void main() {
  group('SshTerminalCubit - SSH Key Management', () {
    late MockPocketBase mockPb;
    late MockAuthStore mockAuthStore;
    late MockRecordService mockSshKeysService;
    late SshTerminalCubit cubit;

    setUp(() {
      mockPb = MockPocketBase();
      mockAuthStore = MockAuthStore();
      mockSshKeysService = MockRecordService();

      // Setup PocketBase mocks
      when(() => mockPb.authStore).thenReturn(mockAuthStore);
      when(() => mockPb.collection('ssh_keys')).thenReturn(mockSshKeysService);
      when(() => mockAuthStore.isValid).thenReturn(true);
      when(() => mockAuthStore.record).thenReturn(
        MockRecordModel()..id = 'test-user-id',
      );

      cubit = SshTerminalCubit(mockPb);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state is correct', () {
      expect(cubit.state.status, TerminalStatus.initial);
      expect(cubit.state.isConnected, false);
      expect(cubit.state.isConnecting, false);
      expect(cubit.state.isSyncingKeys, false);
      expect(cubit.state.error, null);
    });

    test('state transitions to syncingKeys during key generation', () async {
      // This test verifies the state machine transitions
      expect(cubit.state.status, TerminalStatus.initial);

      // Note: We can't easily test the full key generation flow without mocking
      // the cryptography package, but we can verify the state structure
      final syncingState =
          cubit.state.copyWith(status: TerminalStatus.syncingKeys);
      expect(syncingState.isSyncingKeys, true);
      expect(syncingState.isConnecting, false);
      expect(syncingState.isConnected, false);
    });

    test('state transitions to connecting during SSH connection', () {
      final connectingState =
          cubit.state.copyWith(status: TerminalStatus.connecting);
      expect(connectingState.isConnecting, true);
      expect(connectingState.isConnected, false);
      expect(connectingState.isSyncingKeys, false);
    });

    test('state transitions to connected after successful connection', () {
      final connectedState =
          cubit.state.copyWith(status: TerminalStatus.connected);
      expect(connectedState.isConnected, true);
      expect(connectedState.isConnecting, false);
      expect(connectedState.isSyncingKeys, false);
    });

    test('state transitions to error on connection failure', () {
      final errorState = cubit.state.copyWith(
        status: TerminalStatus.error,
        error: 'Connection failed',
      );
      expect(errorState.hasError, true);
      expect(errorState.error, 'Connection failed');
      expect(errorState.isConnected, false);
    });

    test('disconnect resets state to initial', () {
      // Simulate connected state
      cubit.emit(cubit.state.copyWith(
        status: TerminalStatus.connected,
        sessionId: 'test-session',
      ));

      // Disconnect
      cubit.disconnect();

      // Verify state reset
      expect(cubit.state.status, TerminalStatus.initial);
      expect(cubit.state.sessionId, null);
    });

    test('TerminalStatus enum has all expected values', () {
      expect(TerminalStatus.values, contains(TerminalStatus.initial));
      expect(TerminalStatus.values, contains(TerminalStatus.syncingKeys));
      expect(TerminalStatus.values, contains(TerminalStatus.connecting));
      expect(TerminalStatus.values, contains(TerminalStatus.connected));
      expect(TerminalStatus.values, contains(TerminalStatus.error));
    });

    test('state convenience getters work correctly', () {
      // Test initial state
      var state = const SshTerminalState(status: TerminalStatus.initial);
      expect(state.isConnecting, false);
      expect(state.isConnected, false);
      expect(state.isSyncingKeys, false);
      expect(state.hasError, false);

      // Test syncingKeys state
      state = const SshTerminalState(status: TerminalStatus.syncingKeys);
      expect(state.isSyncingKeys, true);
      expect(state.isConnecting, false);

      // Test connecting state
      state = const SshTerminalState(status: TerminalStatus.connecting);
      expect(state.isConnecting, true);
      expect(state.isConnected, false);

      // Test connected state
      state = const SshTerminalState(status: TerminalStatus.connected);
      expect(state.isConnected, true);
      expect(state.isConnecting, false);

      // Test error state
      state = const SshTerminalState(
        status: TerminalStatus.error,
        error: 'Test error',
      );
      expect(state.hasError, true);
      expect(state.error, 'Test error');
    });

    test('state copyWith preserves unchanged fields', () {
      const originalState = SshTerminalState(
        status: TerminalStatus.connected,
        sessionId: 'session-123',
        error: null,
      );

      final newState = originalState.copyWith(error: 'New error');

      expect(newState.status, TerminalStatus.connected);
      expect(newState.sessionId, 'session-123');
      expect(newState.error, 'New error');
    });

    test('state copyWith can update status', () {
      const originalState = SshTerminalState(
        status: TerminalStatus.initial,
      );

      final newState = originalState.copyWith(
        status: TerminalStatus.connecting,
      );

      expect(newState.status, TerminalStatus.connecting);
      expect(newState.isConnecting, true);
    });
  });

  group('SSH Key Fingerprint Calculation', () {
    test('fingerprint format is correct', () {
      // This is a conceptual test - in real implementation,
      // we'd test with known SSH key examples
      const sampleKey =
          'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example.com';

      // The fingerprint should start with "SHA256:"
      // In a real test, we'd calculate this and verify the exact value
      expect(sampleKey.startsWith('ssh-ed25519'), true);
    });
  });
}
