class PocoCodeSection {
  const PocoCodeSection({
    required this.id,
    required this.code,
    required this.startLine,
    required this.endLine,
  });

  final String id;
  final String code;
  final int startLine;
  final int endLine;
}
