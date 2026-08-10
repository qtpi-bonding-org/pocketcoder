import 'package:pocketcoder_pro/domain/deployment/poco_code_section.dart';

/// Extracts teaching excerpts from comments embedded in executable source.
///
/// Markers use `# POCO:BEGIN section-id` and `# POCO:END section-id`, which
/// are valid comments in Nix, YAML, and shell files. Marker lines themselves
/// are omitted from the returned code.
class PocoCodeSectionParser {
  static final _marker = RegExp(
    r'^\s*#\s*POCO:(BEGIN|END)\s+([a-z0-9][a-z0-9-]*)\s*$',
  );

  List<PocoCodeSection> parse(String source) {
    final sections = <PocoCodeSection>[];
    final seenIds = <String>{};
    final lines = source.split('\n');
    String? activeId;
    int? startLine;
    var activeLines = <String>[];

    for (var index = 0; index < lines.length; index += 1) {
      final lineNumber = index + 1;
      final match = _marker.firstMatch(lines[index]);
      if (match == null) {
        if (activeId != null) activeLines.add(lines[index]);
        continue;
      }

      final markerKind = match.group(1);
      final markerId = match.group(2) ?? '';
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

      sections.add(PocoCodeSection(
        id: activeId,
        code: activeLines.join('\n'),
        startLine: startLine ?? lineNumber,
        endLine: lineNumber - 1,
      ));
      activeId = null;
      startLine = null;
      activeLines = <String>[];
    }

    if (activeId != null) {
      throw FormatException('Poco section $activeId is never closed');
    }
    return List<PocoCodeSection>.unmodifiable(sections);
  }
}
