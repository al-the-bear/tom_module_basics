import 'dart:convert';

import '../model/model.dart';

/// Deserializes analysis results from JSON format.
class JsonDeserializer {
  static AnalysisResult decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Invalid JSON: expected a map at the root.');
    }
    return fromMap(decoded.cast<String, dynamic>());
  }

  static AnalysisResult fromMap(Map<String, dynamic> data) {
    return _JsonReader().read(data);
  }
}

class _JsonReader {
  AnalysisResult read(Map<String, dynamic> data) {
    final rootPackageData = _requireMap(data['rootPackage'], 'rootPackage');
    final packageRecords = <String, _PackageRecord>{};

    _addPackageRecord(packageRecords, rootPackageData, isRootOverride: true);

    final packagesData = _requireList(data['packages'], 'packages');
    for (final entry in packagesData) {
      if (entry is! Map) {
        throw const FormatException('Invalid package entry in packages list.');
      }
      _addPackageRecord(packageRecords, entry.cast<String, dynamic>());
    }

    final packageById = <String, PackageInfo>{};
    for (final record in packageRecords.values) {
      packageById[record.package.id] = record.package;
    }

    final filesData = _requireList(data['files'], 'files');
    final filesById = <String, FileInfo>{};
    final filesByPath = <String, FileInfo>{};

    for (final entry in filesData) {
      if (entry is! Map) {
        throw const FormatException('Invalid file entry in files list.');
      }
      final file = _readFile(entry.cast<String, dynamic>(), packageById);
      filesById[file.id] = file;
      filesByPath[file.path] = file;
    }

    final librariesData = _requireList(data['libraries'], 'libraries');
    final librariesByUri = <Uri, LibraryInfo>{};
    for (final entry in librariesData) {
      if (entry is! Map) {
        throw const FormatException('Invalid library entry in libraries list.');
      }
      final library = _readLibrary(
        entry.cast<String, dynamic>(),
        packageById,
        filesById,
      );
      librariesByUri[library.uri] = library;
      library.package.libraries.add(library);
    }

    final errors = _readErrors(data['errors']);

    final analysisResult = AnalysisResult(
      id: _requireString(data['id'], 'id'),
      timestamp: _readDateTime(data['timestamp'], 'timestamp'),
      dartSdkVersion: _requireString(data['dartSdkVersion'], 'dartSdkVersion'),
      analyzerVersion: _requireString(data['analyzerVersion'], 'analyzerVersion'),
      schemaVersion: _requireString(data['schemaVersion'], 'schemaVersion'),
      rootPackage: packageRecords.values.firstWhere((p) => p.package.isRoot).package,
      packages: {
        for (final record in packageRecords.values) record.package.name: record.package,
      },
      libraries: librariesByUri,
      files: filesByPath,
      errors: errors,
      metadata: _readMetadata(data['metadata']),
    );

    for (final record in packageRecords.values) {
      record.package.attachAnalysisResult(analysisResult);
    }

    _attachDependencies(packageRecords);

    return analysisResult;
  }

  void _addPackageRecord(
    Map<String, _PackageRecord> records,
    Map<String, dynamic> data, {
    bool isRootOverride = false,
  }) {
    final name = _requireString(data['name'], 'name');
    if (records.containsKey(name)) {
      return;
    }
    final id = _requireString(data['id'], 'id');
    final rootPath = _requireString(data['rootPath'], 'rootPath');
    final version = _readOptionalString(data['version']);
    final isRoot = data['isRoot'] as bool? ?? isRootOverride;

    final dependencies = _readStringList(data['dependencies']);
    final devDependencies = _readStringList(data['devDependencies']);

    final record = _PackageRecord(
      package: PackageInfo(
        id: id,
        name: name,
        version: version,
        rootPath: rootPath,
        isRoot: isRoot,
        libraries: <LibraryInfo>[],
        dependencies: <String, PackageInfo>{},
        devDependencies: <String, PackageInfo>{},
      ),
      dependencyNames: dependencies,
      devDependencyNames: devDependencies,
    );

    records[name] = record;
  }

  FileInfo _readFile(Map<String, dynamic> data, Map<String, PackageInfo> packageById) {
    final id = _requireString(data['id'], 'id');
    final path = _requireString(data['path'], 'path');
    final packageId = _requireString(data['packageId'], 'packageId');
    final package = packageById[packageId];
    if (package == null) {
      throw FormatException('Unknown packageId "$packageId" for file "$path".');
    }

    return FileInfo(
      id: id,
      path: path,
      package: package,
      library: null,
      isPart: data['isPart'] as bool? ?? false,
      partOfDirective: _readOptionalString(data['partOfDirective']),
      lines: _readInt(data['lines'], 'lines'),
      contentHash: _requireString(data['contentHash'], 'contentHash'),
      modified: _readDateTime(data['modified'], 'modified'),
    );
  }

  LibraryInfo _readLibrary(
    Map<String, dynamic> data,
    Map<String, PackageInfo> packageById,
    Map<String, FileInfo> filesById,
  ) {
    final id = _requireString(data['id'], 'id');
    final name = _requireString(data['name'], 'name');
    final uri = Uri.parse(_requireString(data['uri'], 'uri'));
    final packageId = _requireString(data['packageId'], 'packageId');
    final package = packageById[packageId];
    if (package == null) {
      throw FormatException('Unknown packageId "$packageId" for library "$name".');
    }

    final mainSourceFileId = _requireString(data['mainSourceFileId'], 'mainSourceFileId');
    final mainSourceFile = filesById[mainSourceFileId];
    if (mainSourceFile == null) {
      throw FormatException('Unknown mainSourceFileId "$mainSourceFileId" for library "$name".');
    }

    final partFileIds = _readStringList(data['partFileIds']);
    final partFiles = <FileInfo>[];
    for (final partId in partFileIds) {
      final file = filesById[partId];
      if (file != null) {
        partFiles.add(file);
      }
    }

    return LibraryInfo(
      id: id,
      name: name,
      uri: uri,
      package: package,
      mainSourceFile: mainSourceFile,
      partFiles: partFiles,
      classes: const [],
      enums: const [],
      mixins: const [],
      extensions: const [],
      extensionTypes: const [],
      typeAliases: const [],
      functions: const [],
      variables: const [],
      getters: const [],
      setters: const [],
      exports: const [],
      imports: const [],
    );
  }

  List<AnalysisError> _readErrors(Object? raw) {
    if (raw == null) {
      return const [];
    }
    if (raw is! List) {
      throw const FormatException('Invalid errors list.');
    }
    return raw.map((entry) {
      if (entry is! Map) {
        throw const FormatException('Invalid error entry.');
      }
      final map = entry.cast<String, dynamic>();
      return AnalysisError(
        message: _requireString(map['message'], 'message'),
        severity: AnalysisErrorSeverity.values.firstWhere(
          (value) => value.name == _requireString(map['severity'], 'severity'),
          orElse: () => AnalysisErrorSeverity.info,
        ),
        location: _readLocation(map['location']),
        code: _readOptionalString(map['code']),
      );
    }).toList();
  }

  SourceLocation? _readLocation(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is! Map) {
      throw const FormatException('Invalid location entry.');
    }
    final map = raw.cast<String, dynamic>();
    return SourceLocation(
      line: _readInt(map['line'], 'line'),
      column: _readInt(map['column'], 'column'),
      offset: _readInt(map['offset'], 'offset'),
      length: _readInt(map['length'], 'length'),
    );
  }

  Map<String, dynamic> _readMetadata(Object? raw) {
    if (raw == null) {
      return const {};
    }
    if (raw is! Map) {
      throw const FormatException('Invalid metadata entry.');
    }
    return raw.cast<String, dynamic>();
  }

  void _attachDependencies(Map<String, _PackageRecord> records) {
    final byName = {
      for (final record in records.values) record.package.name: record.package,
    };

    for (final record in records.values) {
      for (final depName in record.dependencyNames) {
        final dep = byName[depName];
        if (dep != null) {
          record.package.dependencies[depName] = dep;
        }
      }
      for (final depName in record.devDependencyNames) {
        final dep = byName[depName];
        if (dep != null) {
          record.package.devDependencies[depName] = dep;
        }
      }
    }
  }

  Map<String, dynamic> _requireMap(Object? value, String field) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw FormatException('Invalid "$field": expected map.');
  }

  List _requireList(Object? value, String field) {
    if (value is List) {
      return value;
    }
    throw FormatException('Invalid "$field": expected list.');
  }

  String _requireString(Object? value, String field) {
    if (value is String) {
      return value;
    }
    throw FormatException('Invalid "$field": expected string.');
  }

  String? _readOptionalString(Object? value) {
    return value is String ? value : null;
  }

  List<String> _readStringList(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is List) {
      return value.whereType<String>().toList();
    }
    throw const FormatException('Invalid list value.');
  }

  int _readInt(Object? value, String field) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw FormatException('Invalid "$field": expected int.');
  }

  DateTime _readDateTime(Object? value, String field) {
    final raw = _requireString(value, field);
    return DateTime.parse(raw);
  }
}

class _PackageRecord {
  final PackageInfo package;
  final List<String> dependencyNames;
  final List<String> devDependencyNames;

  _PackageRecord({
    required this.package,
    required this.dependencyNames,
    required this.devDependencyNames,
  });
}
