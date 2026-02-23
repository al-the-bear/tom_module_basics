import 'dart:io';

import 'package:path/path.dart' as p;

/// Filename for the workspace-level buildkit configuration.
const kBuildkitMasterYaml = 'buildkit_master.yaml';

/// Filename for the Tom workspace configuration.
const kTomWorkspaceYaml = 'tom_workspace.yaml';

/// Filename for the VS Code workspace file.
const kTomCodeWorkspace = 'tom.code-workspace';

/// Filename for the buildkit skip marker.
const kBuildkitSkipYaml = 'buildkit_skip.yaml';

/// Find the workspace root by traversing upwards looking for workspace markers.
///
/// Returns the directory containing `buildkit_master.yaml`, `tom_workspace.yaml`,
/// or `tom.code-workspace`, or [startPath] if none is found.
String findWorkspaceRoot(String startPath) {
  var current = p.normalize(p.absolute(startPath));
  final root = p.rootPrefix(current);

  while (current != root) {
    if (File(p.join(current, kBuildkitMasterYaml)).existsSync() ||
        File(p.join(current, kTomWorkspaceYaml)).existsSync() ||
        File(p.join(current, kTomCodeWorkspace)).existsSync()) {
      return current;
    }
    current = p.dirname(current);
  }

  return startPath;
}

/// Check if a directory is a workspace boundary (contains buildkit_master.yaml).
///
/// Workspace boundaries are treated similarly to skip markers — they
/// mark directories that should be processed separately.
bool isWorkspaceBoundary(String dirPath) {
  return File(p.join(dirPath, kBuildkitMasterYaml)).existsSync();
}
