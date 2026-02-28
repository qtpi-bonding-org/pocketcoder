import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';
import "package:flutter_aeroform/support/extensions/cubit_ui_flow_extension.dart";
import 'terminal_state.dart';
import "package:flutter_aeroform/infrastructure/core/collections.dart";
import "package:flutter_aeroform/infrastructure/core/logger.dart";

@injectable
class SshTerminalCubit extends AppCubit<SshTerminalState> {
  SSHClient? _client;
  SSHSession? _session;
  final Terminal terminal = Terminal(maxLines: 10000);

  final PocketBase _pb;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  SshTerminalCubit(this._pb) : super(SshTerminalState.initial());

  Future<void> connect({
    required String host,
    required int port,
    required String username,
    String? sessionId,
  }) async {
    if (state.isConnected) return;

    return tryOperation(() async {
      emit(state.copyWith(sessionId: sessionId));

      final keys = await _getOrCreateKeyPair();

      // Auto-sync public key if logged in
      if (_pb.authStore.isValid) {
        await _syncPublicKey(keys.publicKeyStr);
      }

      logInfo(
          '🌐 [Terminal] Connecting to $host:$port as $username (via Key)...');
      final socket = await SSHSocket.connect(host, port);

      _client = SSHClient(
        socket,
        username: username,
        identities: [keys.privateKey],
      );

      await _client!.authenticated;
      logInfo('🔓 [Terminal] SSH Authenticated.');

      _session = await _client!.shell(
        pty: SSHPtyConfig(
            width: terminal.viewWidth, height: terminal.viewHeight),
      );

      // Pipe SSH -> XTerm
      _session!.stdout.listen((data) {
        terminal.write(utf8.decode(data));
      });
      _session!.stderr.listen((data) {
        terminal.write(utf8.decode(data));
      });

      // Send initial attach command if requested
      if (sessionId != null) {
        final initialCommand =
            'tmux -S /tmp/tmux/pocketcoder attach -t pc_$sessionId || tmux -S /tmp/tmux/pocketcoder new-session -s pc_$sessionId';
        _session!.stdin.add(utf8.encode('$initialCommand\n'));
      }

      // Pipe XTerm -> SSH
      terminal.onOutput = (data) {
        _session!.stdin.add(utf8.encode(data));
      };

      return createSuccessState();
    });
  }

  Future<({SSHKeyPair privateKey, String publicKeyStr})>
      _getOrCreateKeyPair() async {
    final storedPriv = await _storage.read(key: 'ssh_private_key');
    final storedPub = await _storage.read(key: 'ssh_public_key');

    if (storedPriv != null && storedPub != null) {
      // Load existing key
      final keyPairs = SSHKeyPair.fromPem(storedPriv);
      if (keyPairs.isNotEmpty) {
        return (
          privateKey: keyPairs.first,
          publicKeyStr: storedPub,
        );
      }
    }

    emit(state.copyWith(isSyncingKeys: true));

    // Generate new Ed25519 key pair using cryptography package
    final algorithm = crypto.Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final privateKeyData = await keyPair.extractPrivateKeyBytes();
    final publicKeyData = await keyPair.extractPublicKey();

    // Create OpenSSHEd25519KeyPair (dartssh2's Ed25519 implementation)
    // Constructor signature: OpenSSHEd25519KeyPair(publicKey, privateKey, comment)
    final sshKey = OpenSSHEd25519KeyPair(
      Uint8List.fromList(publicKeyData.bytes),
      Uint8List.fromList(privateKeyData),
      'pocketcoder-device',
    );

    final privPem = sshKey.toPem();
    // Use the built-in serialization from dartssh2
    final pubKeyStr = sshKey.toPublicKey().toString();
    final fingerprint = await _calculateFingerprint(pubKeyStr);

    await _storage.write(key: 'ssh_private_key', value: privPem);
    await _storage.write(key: 'ssh_public_key', value: pubKeyStr);
    await _storage.write(
        key: 'ssh_private_seed', value: base64.encode(privateKeyData));
    await _storage.write(key: 'ssh_fingerprint', value: fingerprint);

    emit(state.copyWith(isSyncingKeys: false));

    return (privateKey: sshKey, publicKeyStr: pubKeyStr);
  }

  Future<void> _syncPublicKey(String publicKey) async {
    final userId = _pb.authStore.record?.id;
    if (userId == null) return;

    // Calculate fingerprint (SHA256 of the public key)
    final fingerprint = await _calculateFingerprint(publicKey);

    // Get device name (you can enhance this with device_info_plus package)
    const deviceName = 'Flutter Device'; // TODO: Get actual device name

    try {
      // Check if this key already exists for this user
      final existingKeys =
          await _pb.collection(Collections.sshKeys).getFullList(
                filter: 'user = "$userId" && fingerprint = "$fingerprint"',
              );

      if (existingKeys.isEmpty) {
        // Create new SSH key record
        logInfo('🔄 [Terminal] Registering new SSH key to PocketBase...');
        await _pb.collection(Collections.sshKeys).create(body: {
          'user': userId,
          'public_key': publicKey,
          'device_name': deviceName,
          'fingerprint': fingerprint,
          'is_active': true,
        });
      } else {
        // Update last_used timestamp
        final keyRecord = existingKeys.first;
        await _pb.collection(Collections.sshKeys).update(keyRecord.id, body: {
          'last_used': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      logWarning('⚠️ [Terminal] Failed to sync SSH key', e);
      // Don't fail the connection if key sync fails
    }
  }

  Future<String> _calculateFingerprint(String publicKey) async {
    // Extract the base64 part (between "ssh-ed25519 " and optional comment)
    final parts = publicKey.split(' ');
    if (parts.length < 2) return '';

    final keyData = parts[1];
    final bytes = base64.decode(keyData);

    // Calculate SHA256 hash using cryptography package
    final algorithm = crypto.Sha256();
    final hash = await algorithm.hash(bytes);

    // Format as SHA256:base64
    return 'SHA256:${base64.encode(hash.bytes)}';
  }

  void disconnect() {
    _session?.close();
    _client?.close();
    emit(SshTerminalState.initial());
  }

  @override
  Future<void> close() {
    disconnect();
    return super.close();
  }
}
