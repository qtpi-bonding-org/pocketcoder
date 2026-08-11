class PocoCodeSection {
  const PocoCodeSection({
    required this.id,
    required this.code,
    required this.previewCode,
    required this.startLine,
    required this.endLine,
  });

  final String id;
  final String code;
  final String previewCode;
  final int startLine;
  final int endLine;
}
