import 'dart:convert';

import '../model/model.dart';

/// Serializes analysis results to JSON format.
class JsonSerializer {
  static String encode(AnalysisResult result) {
    final map = _JsonWriter().toMap(result);
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static Map<String, dynamic> toMap(AnalysisResult result) {
    return _JsonWriter().toMap(result);
  }
}

class _JsonWriter {
  Map<String, dynamic> toMap(AnalysisResult result) {
    return {
      'id': result.id,
      'timestamp': result.timestamp.toIso8601String(),
      'dartSdkVersion': result.dartSdkVersion,
      'analyzerVersion': result.analyzerVersion,
      'schemaVersion': result.schemaVersion,
      'rootPackage': _package(result.rootPackage),
      'packages': result.packages.values.map(_package).toList(),
      'libraries': result.libraries.values.map(_library).toList(),
      'files': result.files.values.map(_file).toList(),
      'errors': result.errors.map(_error).toList(),
      'metadata': result.metadata,
    };
  }

  Map<String, dynamic> _package(PackageInfo pkg) {
    return {
      'id': pkg.id,
      'name': pkg.name,
      'version': pkg.version,
      'rootPath': pkg.rootPath,
      'isRoot': pkg.isRoot,
      'libraries': pkg.libraries.map((l) => l.id).toList(),
      'dependencies': pkg.dependencies.keys.toList(),
      'devDependencies': pkg.devDependencies.keys.toList(),
    };
  }

  Map<String, dynamic> _library(LibraryInfo lib) {
    return {
      'id': lib.id,
      'name': lib.name,
      'uri': lib.uri.toString(),
      'packageId': lib.package.id,
      'mainSourceFileId': lib.mainSourceFile.id,
      'partFileIds': lib.partFiles.map((f) => f.id).toList(),
      'classes': lib.classes.map((c) => c.id).toList(),
      'enums': lib.enums.map((e) => e.id).toList(),
      'mixins': lib.mixins.map((m) => m.id).toList(),
      'extensions': lib.extensions.map((e) => e.id).toList(),
      'extensionTypes': lib.extensionTypes.map((e) => e.id).toList(),
      'typeAliases': lib.typeAliases.map((t) => t.id).toList(),
      'functions': lib.functions.map((f) => f.id).toList(),
      'variables': lib.variables.map((v) => v.id).toList(),
      'getters': lib.getters.map((g) => g.id).toList(),
      'setters': lib.setters.map((s) => s.id).toList(),
    };
  }

  Map<String, dynamic> _file(FileInfo file) {
    return {
      'id': file.id,
      'path': file.path,
      'packageId': file.package.id,
      'libraryId': file.library?.id,
      'isPart': file.isPart,
      'partOfDirective': file.partOfDirective,
      'lines': file.lines,
      'contentHash': file.contentHash,
      'modified': file.modified.toIso8601String(),
    };
  }

  Map<String, dynamic> _error(AnalysisError error) {
    return {
      'message': error.message,
      'severity': error.severity.name,
      'location': error.location != null
          ? {
              'line': error.location!.line,
              'column': error.location!.column,
              'offset': error.location!.offset,
              'length': error.location!.length,
            }
          : null,
      'code': error.code,
    };
  }
}
