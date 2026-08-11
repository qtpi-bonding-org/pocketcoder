class PocoCodeSection {
  const PocoCodeSection({
    required this.id,
    required this.code,
    required this.importantCode,
    required this.startLine,
    required this.endLine,
  });

  final String id;
  final String code;
  final String importantCode;
  final int startLine;
  final int endLine;
}
