/// Walker implementation for file system traversal
library;

import 'dart:io';

void main(List<String> args) async {
  final path = args.isNotEmpty ? args[0] : '.';
  final walker = FileSystemWalker();
  await walker.walk(path);
}

class FileSystemWalker {
  int fileCount = 0;
  int dirCount = 0;
  
  Future<void> walk(String path) async {
    final entity = FileSystemEntity.typeSync(path);
    
    if (entity == FileSystemEntityType.file) {
      _processFile(path);
    } else if (entity == FileSystemEntityType.directory) {
      await _processDirectory(path);
    }
    
    print('Summary: $fileCount files, $dirCount directories');
  }
  
  void _processFile(String path) {
    fileCount++;
    final file = File(path);
    final size = file.lengthSync();
    print('File: $path ($size bytes)');
  }
  
  Future<void> _processDirectory(String path) async {
    dirCount++;
    print('Directory: $path');
    
    final dir = Directory(path);
    await for (final entity in dir.list()) {
      if (entity is File) {
        _processFile(entity.path);
      } else if (entity is Directory) {
        await _processDirectory(entity.path);
      }
    }
  }
}

typedef WalkCallback = void Function(String path);

abstract class Walker {
  Future<void> walk(String path);
  void onFile(String path);
  void onDirectory(String path);
}
