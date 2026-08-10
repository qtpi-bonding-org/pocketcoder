import 'package:http/http.dart' as http;
import 'package:pocketcoder_pro/domain/deployment/poco_code_section.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/poco_code_section_parser.dart';

enum ProvisioningSourceFile {
  hostConfiguration('deploy/nixos/configuration.nix'),
  hostBootstrap('deploy/nixos/bootstrap.sh'),
  dockerCompose('docker-compose.yml');

  const ProvisioningSourceFile(this.path);
  final String path;
}

/// Loads the inspectable provisioning source for the exact deployed release.
class GithubProvisioningSourceService {
  GithubProvisioningSourceService({
    required http.Client client,
    PocoCodeSectionParser? parser,
  })  : _client = client,
        _parser = parser ?? PocoCodeSectionParser();

  static final _immutableCommit = RegExp(r'^[a-fA-F0-9]{7,64}$');
  final http.Client _client;
  final PocoCodeSectionParser _parser;
  final Map<String, Future<List<PocoCodeSection>>> _cache = {};

  bool isImmutableCommit(String value) => _immutableCommit.hasMatch(value);

  Future<List<PocoCodeSection>> fetchSections({
    required String sourceCommit,
    required ProvisioningSourceFile file,
  }) async {
    if (!isImmutableCommit(sourceCommit)) {
      throw FormatException('Invalid PocketCoder source commit');
    }
    final cacheKey = '$sourceCommit:${file.path}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    final request = _fetchSections(sourceCommit: sourceCommit, file: file);
    _cache[cacheKey] = request;
    try {
      return await request;
    } on Object {
      if (identical(_cache[cacheKey], request)) _cache.remove(cacheKey);
      rethrow;
    }
  }

  Future<List<PocoCodeSection>> _fetchSections({
    required String sourceCommit,
    required ProvisioningSourceFile file,
  }) async {
    final uri = Uri.https(
      'raw.githubusercontent.com',
      '/qtpi-bonding-org/pocketcoder/$sourceCommit/${file.path}',
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw ProvisioningSourceException(
        'Could not load ${file.path} at $sourceCommit',
        uri: uri,
      );
    }
    return _parser.parse(response.body);
  }
}

class ProvisioningSourceException implements Exception {
  const ProvisioningSourceException(this.message, {required this.uri});
  final String message;
  final Uri uri;

  @override
  String toString() => message;
}
