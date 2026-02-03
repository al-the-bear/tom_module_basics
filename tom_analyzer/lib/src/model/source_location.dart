part of 'model.dart';

class SourceLocation {
  final int line;
  final int column;
  final int offset;
  final int length;

  const SourceLocation({
    required this.line,
    required this.column,
    required this.offset,
    required this.length,
  });
}
