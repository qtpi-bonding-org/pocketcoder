import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';

class FossServerConnectionDetailsProvider
    implements IServerConnectionDetailsProvider {
  const FossServerConnectionDetailsProvider();

  @override
  bool get isAvailable => false;

  @override
  String? get ipAddress => null;

  @override
  String? get httpsEndpoint => null;

  @override
  String? get adminIdentity => null;

  @override
  String? get adminPassword => null;
}
