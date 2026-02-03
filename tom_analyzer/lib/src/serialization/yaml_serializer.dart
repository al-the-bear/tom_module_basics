import '../model/model.dart';
import 'json_serializer.dart';

/// Serializes analysis results to a YAML representation.
class YamlSerializer {
  static String encode(AnalysisResult result) {
    final map = JsonSerializer.toMap(result);
    return _YamlEmitter().emit(map);
  }
}

class _YamlEmitter {
  String emit(Object? value, {int indent = 0}) {
    if (value == null) {
      return 'null';
    }
    if (value is Map) {
      return _emitMap(value.cast<String, Object?>(), indent);
    }
    if (value is List) {
      return _emitList(value, indent);
    }
    if (value is String) {
      return _escapeString(value);
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return _escapeString(value.toString());
  }

  String _emitMap(Map<String, Object?> map, int indent) {
    final buffer = StringBuffer();
    final pad = ' ' * indent;
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is Map || value is List) {
        buffer.writeln('$pad$key:');
        buffer.writeln(emit(value, indent: indent + 2));
      } else {
        buffer.writeln('$pad$key: ${emit(value)}');
      }
    }
    return buffer.toString().trimRight();
  }

  String _emitList(List values, int indent) {
    final buffer = StringBuffer();
    final pad = ' ' * indent;
    for (final value in values) {
      if (value is Map || value is List) {
        buffer.writeln('$pad-');
        buffer.writeln(emit(value, indent: indent + 2));
      } else {
        buffer.writeln('$pad- ${emit(value)}');
      }
    }
    return buffer.toString().trimRight();
  }

  String _escapeString(String value) {
    final escaped = value.replaceAll('"', '\\"');
    if (escaped.contains('\n') || escaped.contains(':') || escaped.contains('#')) {
      return '"$escaped"';
    }
    return escaped;
  }
}
