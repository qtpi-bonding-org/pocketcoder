import 'package:pocketcoder_pro/domain/deployment/poco_code_section.dart';

/// Extracts displayable code from source sections annotated for a walkthrough.
///
/// Markers use `# POCO:BEGIN section-id` and `# POCO:END section-id`, which
/// are valid comments in Nix, YAML, and shell files. Marker and source-comment
/// lines are never displayed. The concise view is the first [previewLineCount]
/// non-empty cleaned code lines; the expanded view is the complete cleaned
/// section.
class PocoCodeSectionParser {
  PocoCodeSectionParser({this.previewLineCount = 8})
      : assert(previewLineCount > 0);

  static final _sectionMarker = RegExp(
    r'^\s*#\s*POCO:(BEGIN|END)\s+([a-z0-9][a-z0-9-]*)\s*$',
  );
  final int previewLineCount;

  List<PocoCodeSection> parse(String source) {
    final sections = <PocoCodeSection>[];
    final seenIds = <String>{};
    final lines = source.split('\n');
    String? activeId;
    int? startLine;
    var activeLines = <String>[];

    for (var index = 0; index < lines.length; index += 1) {
      final lineNumber = index + 1;
      final sectionMatch = _sectionMarker.firstMatch(lines[index]);
      if (sectionMatch == null) {
        if (activeId != null) {
          activeLines.add(lines[index]);
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
      final cleanedLines = _trimBlankEdges(
        activeLines.map(_stripComment).toList(growable: false),
      );
      if (cleanedLines.isEmpty) {
        throw FormatException(
          'Poco section $activeId contains no displayable code',
        );
      }
      final code = cleanedLines.join('\n');
      sections.add(PocoCodeSection(
        id: activeId,
        code: code,
        previewCode: cleanedLines
            .where((line) => line.trim().isNotEmpty)
            .take(previewLineCount)
            .join('\n'),
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

  static List<String> _trimBlankEdges(List<String> lines) {
    var first = 0;
    var last = lines.length;
    while (first < last && lines[first].trim().isEmpty) {
      first += 1;
    }
    while (last > first && lines[last - 1].trim().isEmpty) {
      last -= 1;
    }
    return lines.sublist(first, last);
  }

  /// Removes shell, Nix, and YAML comments without treating a hash inside a
  /// quoted string as a comment. A hash begins a comment only at the start of
  /// a line or after whitespace, matching the source formats used here.
  static String _stripComment(String line) {
    var inSingleQuote = false;
    var inDoubleQuote = false;
    var escaped = false;

    for (var index = 0; index < line.length; index += 1) {
      final character = line[index];
      if (inDoubleQuote) {
        if (escaped) {
          escaped = false;
        } else if (character == r'\') {
          escaped = true;
        } else if (character == '"') {
          inDoubleQuote = false;
        }
        continue;
      }
      if (inSingleQuote) {
        if (character == "'") inSingleQuote = false;
        continue;
      }
      if (character == '"') {
        inDoubleQuote = true;
        continue;
      }
      if (character == "'") {
        inSingleQuote = true;
        continue;
      }
      if (character == '#' && (index == 0 || _isWhitespace(line[index - 1]))) {
        return line.substring(0, index).trimRight();
      }
    }
    return line.trimRight();
  }

  static bool _isWhitespace(String value) =>
      value == ' ' || value == '\t' || value == '\r';
}
