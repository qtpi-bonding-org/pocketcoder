import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_result.dart';

abstract interface class IServerControlService {
  Future<String?> readPublicKey({required String instanceId});

  Future<ServerReleaseStatusSnapshot> inspectRelease();

  Future<ServerControlResult> restartPocketCoder({
    required String instanceId,
  });

  Future<ServerControlResult> updatePocketCoder({
    required String instanceId,
  });

  Future<ServerControlResult> restartNixOs({
    required String instanceId,
  });

  Future<ServerControlResult> updateNixOs({
    required String instanceId,
  });

  Future<ServerControlResult> saveBackup({
    required String instanceId,
  });
}
