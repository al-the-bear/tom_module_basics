/// Walker for analyzing code metrics
library;

import 'dart:io';

void main(List<String> args) async {
  final path = args.isNotEmpty ? args[0] : 'lib';
  final walker = CodeMetricsWalker();
  await walker.analyze(path);
}

class CodeMetricsWalker {
  int totalLines = 0;
  int codeLines = 0;
  int commentLines = 0;
  int blankLines = 0;
  
  Future<void> analyze(String path) async {
    final dir = Directory(path);
    
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        await _analyzeFile(entity.path);
      }
    }
    
    print('Code Metrics:');
    print('  Total lines: $totalLines');
    print('  Code lines: $codeLines');
    print('  Comment lines: $commentLines');
    print('  Blank lines: $blankLines');
  }
  
  Future<void> _analyzeFile(String path) async {
    final content = await File(path).readAsString();
    final lines = content.split('\n');
    
    for (final line in lines) {
      totalLines++;
      
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        blankLines++;
      } else if (trimmed.startsWith('//') || trimmed.startsWith('/*')) {
        commentLines++;
      } else {
        codeLines++;
      }
    }
  }
}

class CodeMetrics {
  final int lines;
  final int files;
  final double averageLinesPerFile;
  
  CodeMetrics({
    required this.lines,
    required this.files,
  }) : averageLinesPerFile = files > 0 ? lines / files : 0;
  
  @override
  String toString() {
    return 'CodeMetrics(lines: $lines, files: $files, avg: ${averageLinesPerFile.toStringAsFixed(2)})';
  }
}
