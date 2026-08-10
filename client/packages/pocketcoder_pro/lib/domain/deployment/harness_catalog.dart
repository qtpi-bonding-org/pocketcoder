import 'dart:convert';

import 'harness_catalog_data.dart';

class DeploymentHarness {
  const DeploymentHarness({
    required this.id,
    required this.composeService,
    required this.imageRepository,
  });

  final String id;
  final String composeService;
  final String imageRepository;

  factory DeploymentHarness.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        !_hasExactKeys(
          value,
          const {'id', 'composeService', 'imageRepository'},
        )) {
      throw const FormatException('Invalid deployment harness entry');
    }
    final id = value['id'];
    final composeService = value['composeService'];
    final imageRepository = value['imageRepository'];
    if (id is! String ||
        id.isEmpty ||
        composeService is! String ||
        composeService.isEmpty ||
        imageRepository is! String ||
        imageRepository.isEmpty) {
      throw const FormatException('Invalid deployment harness fields');
    }
    return DeploymentHarness(
      id: id,
      composeService: composeService,
      imageRepository: imageRepository,
    );
  }
}

class DeploymentHarnessCatalog {
  DeploymentHarnessCatalog._({
    required this.schemaVersion,
    required this.defaultHarness,
    required List<DeploymentHarness> harnesses,
  }) : harnesses = List.unmodifiable(harnesses);

  final int schemaVersion;
  final String defaultHarness;
  final List<DeploymentHarness> harnesses;

  static final DeploymentHarnessCatalog bundled =
      DeploymentHarnessCatalog.parse(bundledHarnessCatalogJson);

  factory DeploymentHarnessCatalog.parse(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> ||
        !_hasExactKeys(
          value,
          const {'schemaVersion', 'defaultHarness', 'harnesses'},
        )) {
      throw const FormatException('Invalid deployment harness catalog');
    }
    final schemaVersion = value['schemaVersion'];
    final defaultHarness = value['defaultHarness'];
    final rawHarnesses = value['harnesses'];
    if (schemaVersion != 1 ||
        defaultHarness is! String ||
        rawHarnesses is! List ||
        rawHarnesses.isEmpty) {
      throw const FormatException('Unsupported deployment harness catalog');
    }
    final harnesses = rawHarnesses.map(DeploymentHarness.fromJson).toList();
    final ids = harnesses.map((harness) => harness.id).toSet();
    if (ids.length != harnesses.length || !ids.contains(defaultHarness)) {
      throw const FormatException('Invalid deployment harness identity');
    }
    return DeploymentHarnessCatalog._(
      schemaVersion: schemaVersion as int,
      defaultHarness: defaultHarness,
      harnesses: harnesses,
    );
  }

  List<String> get initialSelection => List.unmodifiable([defaultHarness]);

  List<String> canonicalize(Iterable<String> selectedHarnesses) {
    final selected = selectedHarnesses.toList(growable: false);
    if (selected.isEmpty) {
      throw const FormatException('At least one harness must be selected');
    }
    final unique = selected.toSet();
    if (unique.length != selected.length) {
      throw const FormatException('Selected harnesses must be duplicate-free');
    }
    final known = harnesses.map((harness) => harness.id).toSet();
    if (!known.containsAll(unique)) {
      throw const FormatException('Unknown deployment harness');
    }
    return List.unmodifiable([
      for (final harness in harnesses)
        if (unique.contains(harness.id)) harness.id,
    ]);
  }
}

bool _hasExactKeys(Map<String, dynamic> value, Set<String> expected) =>
    value.keys.toSet().containsAll(expected) &&
    expected.containsAll(value.keys);
