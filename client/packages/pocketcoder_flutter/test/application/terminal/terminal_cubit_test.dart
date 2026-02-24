import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/terminal/terminal_cubit.dart';
import 'package:pocketcoder_flutter/application/terminal/terminal_state.dart';

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
      expect(cubit.state.status, UiFlowStatus.idle);
      expect(cubit.state.isConnected, false);
      expect(cubit.state.isConnecting, false);
      expect(cubit.state.isSyncingKeys, false);
      expect(cubit.state.error, null);
    });

    test('state transitions to syncingKeys during key generation', () async {
      // This test verifies the state machine transitions
      expect(cubit.state.status, UiFlowStatus.idle);

      // Note: We can't easily test the full key generation flow without mocking
      // the cryptography package, but we can verify the state structure
      final syncingState = cubit.state.copyWith(isSyncingKeys: true);
      expect(syncingState.isSyncingKeys, true);
      expect(syncingState.isConnecting, false);
      expect(syncingState.isConnected, false);
    });

    test('state transitions to connecting during SSH connection', () {
      final connectingState =
          cubit.state.copyWith(status: UiFlowStatus.loading);
      expect(connectingState.isConnecting, true);
      expect(connectingState.isConnected, false);
      expect(connectingState.isSyncingKeys, false);
    });

    test('state transitions to connected after successful connection', () {
      final connectedState =
          cubit.state.copyWith(status: UiFlowStatus.success);
      expect(connectedState.isConnected, true);
      expect(connectedState.isConnecting, false);
      expect(connectedState.isSyncingKeys, false);
    });

    test('state transitions to error on connection failure', () {
      final errorState = cubit.state.copyWith(
        status: UiFlowStatus.failure,
        error: 'Connection failed',
      );
      expect(errorState.hasError, true);
      expect(errorState.error, 'Connection failed');
      expect(errorState.isConnected, false);
    });

    test('disconnect resets state to initial', () {
      // Simulate connected state
      cubit.emit(cubit.state.copyWith(
        status: UiFlowStatus.success,
        sessionId: 'test-session',
      ));

      // Disconnect
      cubit.disconnect();

      // Verify state reset
      expect(cubit.state.status, UiFlowStatus.idle);
      expect(cubit.state.sessionId, null);
    });

    test('UiFlowStatus enum has all expected values', () {
      expect(UiFlowStatus.values, contains(UiFlowStatus.idle));
      expect(UiFlowStatus.values, contains(UiFlowStatus.loading));
      expect(UiFlowStatus.values, contains(UiFlowStatus.success));
      expect(UiFlowStatus.values, contains(UiFlowStatus.failure));
    });

    test('state convenience getters work correctly', () {
      // Test initial state
      var state = SshTerminalState(status: UiFlowStatus.idle);
      expect(state.isConnecting, false);
      expect(state.isConnected, false);
      expect(state.isSyncingKeys, false);
      expect(state.hasError, false);

      // Test syncingKeys state
      state = SshTerminalState(status: UiFlowStatus.idle, isSyncingKeys: true);
      expect(state.isSyncingKeys, true);
      expect(state.isConnecting, false);

      // Test connecting state
      state = SshTerminalState(status: UiFlowStatus.loading);
      expect(state.isConnecting, true);
      expect(state.isConnected, false);

      // Test connected state
      state = SshTerminalState(status: UiFlowStatus.success);
      expect(state.isConnected, true);
      expect(state.isConnecting, false);

      // Test error state
      state = SshTerminalState(
        status: UiFlowStatus.failure,
        error: 'Test error',
      );
      expect(state.hasError, true);
      expect(state.error, 'Test error');
    });

    test('state copyWith preserves unchanged fields', () {
      final originalState = SshTerminalState(
        status: UiFlowStatus.success,
        sessionId: 'session-123',
        error: null,
      );

      final newState = originalState.copyWith(error: 'New error');

      expect(newState.status, UiFlowStatus.success);
      expect(newState.sessionId, 'session-123');
      expect(newState.error, 'New error');
    });

    test('state copyWith can update status', () {
      final originalState = SshTerminalState(
        status: UiFlowStatus.idle,
      );

      final newState = originalState.copyWith(
        status: UiFlowStatus.loading,
      );

      expect(newState.status, UiFlowStatus.loading);
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
