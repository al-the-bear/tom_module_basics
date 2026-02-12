a) I think even if the tools reject the navigation parameters I think there should be ways to --project and --exclude individual project from a tool, e.g. to build all tools but skip some steps in some projects. --project/--include would mean: when traversing through the globally specified project, this command is only run in these projects. And --exclude means, if these projects are traversed by the global navigation, skip them.

Please add support for this in the tom_build_base, so commands can be skip automatically in the traversal loop. Every command must indicate if it supports these flags and the tom_build_base must reject them with error if they are specified anyway.

b) Verify that we have in/Add in tom_build_base

- support for the version output (version,-version, --version, -v), of course inclusion of version.g.dart must remain in the tools
- support for the help (help, -help, --help, -h) output
- support for commands to describe themselves (for usage help)
- support for tools and commands to indicate their options and their meaning/description, so usage help can be generated automatically for all tools and their commands
- support for a --test flag which includes zom_ project and --test-only to only run only on projects with a zom_* prefix

Command standalone mode (separate executable for a command):

- support for commands to optionally indicate different allowed global navigation options if run standalone
- support for the case that if a command runs standalone, all options can be specified directly
- support standalone mode as a command:

Please note: if we need additional traversal options/algorithms this MUST be added in tom_build_base to guarantee new developments can be used in all tools easily (just switch the new features on in the tool's NavigationOptions).

c) Good through the options of all commands (and the standalone command scripts in build_kit) in build_kit, test_kit, d4rtgen and astgen and analyze for common patterns, which can be supported in tom_tool_base.

d) Add support for project ids (that are very short mnemonics for projects like BB for tom_build_base or D4 for tom_d4rt, D4G for tom_d4rt_generator). They can be used just like project names whereever project names are allowed and mixed use is allowe. These project ids will be defined in buildkit.yaml. 

project-id: D4G

When we run through the projects of the workspace to determine the traversal tree and build-order and identify git folders we can extract these ids, too. I suggest we define a class to represent folders during the scan (FsFolder for filesystem folder) and another for folders we process (RunFolder) so we can add common features of folders and projects in a single place. There are the following types of RunFolder for now: RootFolder, GitFolder, VsCodeExtensionFolder, DartProjectFolder (with subclasses for FlutterFolder, DartConsoleFolder and DartPackageFolder). A FsFolder can be multiple RunFolders, detect based on key files or content in the files. The commands get passed all "natures" of the folder that is currently processed and can access the required information. Typically a git command would get the GitFolder nature of a folder and work with this. Command may be able to operate on multiple types of RunFolder subclasses or even use multiple natures of the same folder. So a command gets passed the FsFolder and the list of RunFolder natures of the project it is processing at the moment. "Natures" means: if a folder is a Git Folder, a TypeScript project and a Vs Code Extension project, it will have three natures. A command can get the required nature

CommandContext.getFolderNature<GitFolder>() 

Please look in the Tom Workspace Analyzer for projects types and the scanning conditions to complete the list of folder natures.

d) Create a document cli_tool_design.md in tom_build_base/doc which describes which types of tools can be well supported with tom_build_base and what parts of the scaffolding are handled how. tom_build_base has the goal to unify our tools, so they can have certain classes of features (like project traversal or git-traversal or use of a command-pipeline on the commandline) but use of these features is mostly optional to not restrict what tools we can build too much. Let's define what is a tool, a command, a command-pipeline. Consider how our REPL tools (dcli, d4rt, tom) and the guide mode fits in here. There is also an experimental TUI mode in testkit, which I want to support in our tools and which has different requirement for using the tom_build_base (in this case the TUI will probably use tom_build_base in two ways: for starting the tool and standard option parsing, but later actively trigger the traversal logic, potentially multiple times with different settings, as a TUI is an interactive tool which may be used for various purposes). DCLI, D4RT and TOM also have "stdin"-mode to process input on stdin (in this case D4rt scripts), but currently I don't how we can suppport this except for the initial tool start and handling of the basic help and version features. However, we must think about how we will integrate this in the usage, so a tool must be able to indicate it supports stdin mode and provide usage/help info on this, too, so it can be integrated into the help text. So we'll probably need ToolDefinition and CommandDefinition classes to specify. Let's create a
