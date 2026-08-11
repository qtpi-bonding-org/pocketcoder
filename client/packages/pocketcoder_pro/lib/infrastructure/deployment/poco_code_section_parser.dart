import 'package:pocketcoder_pro/domain/deployment/poco_code_section.dart';

/// Extracts teaching excerpts from comments embedded in executable source.
///
/// Markers use `# POCO:BEGIN section-id` and `# POCO:END section-id`, which
/// are valid comments in Nix, YAML, and shell files. A section may contain one
/// `# POCO:IMPORTANT:BEGIN` / `# POCO:IMPORTANT:END` pair to select its concise
/// teaching excerpt. Marker lines themselves are omitted from returned code.
class PocoCodeSectionParser {
  static final _sectionMarker = RegExp(
    r'^\s*#\s*POCO:(BEGIN|END)\s+([a-z0-9][a-z0-9-]*)\s*$',
  );
  static final _importantMarker = RegExp(
    r'^\s*#\s*POCO:IMPORTANT:(BEGIN|END)\s*$',
  );

  List<PocoCodeSection> parse(String source) {
    final sections = <PocoCodeSection>[];
    final seenIds = <String>{};
    final lines = source.split('\n');
    String? activeId;
    int? startLine;
    var activeLines = <String>[];
    var importantLines = <String>[];
    var collectingImportant = false;
    var hasImportantExcerpt = false;

    for (var index = 0; index < lines.length; index += 1) {
      final lineNumber = index + 1;
      final sectionMatch = _sectionMarker.firstMatch(lines[index]);
      final importantMatch = _importantMarker.firstMatch(lines[index]);
      if (sectionMatch == null && importantMatch == null) {
        if (activeId != null) {
          activeLines.add(lines[index]);
          if (collectingImportant) importantLines.add(lines[index]);
        }
        continue;
      }

      if (importantMatch != null) {
        if (activeId == null) {
          throw FormatException(
            'Important excerpt marker is outside a Poco section at line $lineNumber',
          );
        }
        final markerKind = importantMatch.group(1);
        if (markerKind == 'BEGIN') {
          if (collectingImportant || hasImportantExcerpt) {
            throw FormatException(
              'Poco section $activeId has multiple important excerpts',
            );
          }
          collectingImportant = true;
          hasImportantExcerpt = true;
        } else {
          if (!collectingImportant) {
            throw FormatException(
              'Poco section $activeId ends an important excerpt without a beginning',
            );
          }
          collectingImportant = false;
        }
        continue;
      }

      final markerKind = sectionMatch?.group(1);
      final markerId = sectionMatch?.group(2) ?? '';
      if (markerKind == 'BEGIN') {
        if (activeId != null) {
          throw FormatException(
            'Poco section $markerId starts inside $activeId at line $lineNumber',
          );
        }
        if (!seenIds.add(markerId)) {
          throw FormatException('Duplicate Poco section $markerId');
        }
        activeId = markerId;
        startLine = lineNumber + 1;
        activeLines = <String>[];
        importantLines = <String>[];
        collectingImportant = false;
        hasImportantExcerpt = false;
        continue;
      }

      if (activeId == null) {
        throw FormatException(
          'Poco section $markerId ends without a beginning at line $lineNumber',
        );
      }
      if (markerId != activeId) {
        throw FormatException(
          'Poco section $activeId is closed by $markerId at line $lineNumber',
        );
      }
      if (collectingImportant) {
        throw FormatException(
          'Poco section $activeId closes before its important excerpt',
        );
      }

      final code = activeLines.join('\n');
      sections.add(PocoCodeSection(
        id: activeId,
        code: code,
        importantCode: hasImportantExcerpt ? importantLines.join('\n') : code,
        startLine: startLine ?? lineNumber,
        endLine: lineNumber - 1,
      ));
      activeId = null;
      startLine = null;
      activeLines = <String>[];
      importantLines = <String>[];
      collectingImportant = false;
      hasImportantExcerpt = false;
    }

    if (activeId != null) {
      throw FormatException('Poco section $activeId is never closed');
    }
    return List<PocoCodeSection>.unmodifiable(sections);
  }
}
