const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '..');
const academicOSDir = path.join(rootDir, 'AcademicOS');

// Find all swift files recursively
function getSwiftFiles(dir, baseDir = dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  for (const file of list) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat && stat.isDirectory()) {
      if (file !== 'Assets.xcassets' && file !== 'Documentation') {
        results = results.concat(getSwiftFiles(filePath, baseDir));
      }
    } else if (file.endsWith('.swift')) {
      const relPath = path.relative(baseDir, filePath).replace(/\\/g, '/');
      results.push({
        fileName: file,
        relPath: relPath,
        fullPath: filePath
      });
    }
  }
  return results;
}

const swiftFiles = getSwiftFiles(academicOSDir);
console.log(`Found ${swiftFiles.length} Swift files in AcademicOS.`);

// Assign deterministic IDs
let idCounter = 10000;
function getNextId() {
  idCounter++;
  return idCounter.toString(16).toUpperCase().padStart(24, '0');
}

// Frameworks to link
const frameworks = [
  { name: 'WebKit.framework', path: 'System/Library/Frameworks/WebKit.framework' },
  { name: 'Speech.framework', path: 'System/Library/Frameworks/Speech.framework' },
  { name: 'AVFoundation.framework', path: 'System/Library/Frameworks/AVFoundation.framework' },
  { name: 'AVFAudio.framework', path: 'System/Library/Frameworks/AVFAudio.framework' },
  { name: 'BackgroundTasks.framework', path: 'System/Library/Frameworks/BackgroundTasks.framework' },
  { name: 'UserNotifications.framework', path: 'System/Library/Frameworks/UserNotifications.framework' },
  { name: 'LocalAuthentication.framework', path: 'System/Library/Frameworks/LocalAuthentication.framework' },
  { name: 'CryptoKit.framework', path: 'System/Library/Frameworks/CryptoKit.framework' },
  { name: 'libsqlite3.tbd', path: 'usr/lib/libsqlite3.tbd' }
];

const frameworkRefs = frameworks.map(fw => {
  return {
    ...fw,
    fileRefId: getNextId(),
    buildFileId: getNextId()
  };
});

// Create build files and file references for Swift files
const swiftItems = swiftFiles.map(sf => {
  return {
    ...sf,
    fileRefId: getNextId(),
    buildFileId: getNextId()
  };
});

const appRefId = '000000000000000000000001';
const assetsFileRefId = getNextId();
const assetsBuildFileId = getNextId();
const infoPlistRefId = getNextId();

const frameworksBuildPhaseId = '000000000000000000005001';
const sourcesBuildPhaseId = '000000000000000000005002';
const resourcesBuildPhaseId = '000000000000000000005003';

const mainGroupId = '000000000000000000000002';
const academicOSGroupId = '000000000000000000000003';
const productsGroupId = '000000000000000000000004';
const frameworksGroupId = getNextId();

const targetId = '000000000000000000003001';
const projectId = '000000000000000000000000';

const targetDebugConfigId = '000000000000000000006001';
const targetReleaseConfigId = '000000000000000000006002';
const projectDebugConfigId = '000000000000000000006003';
const projectReleaseConfigId = '000000000000000000006004';

const targetConfigListId = '000000000000000000004001';
const projectConfigListId = '000000000000000000004002';

// Group Swift files hierarchically
// Build tree from relPath
const rootGroupChildren = {};

function addPathToTree(tree, parts, item) {
  const current = parts[0];
  if (parts.length === 1) {
    if (!tree.files) tree.files = [];
    tree.files.push(item);
  } else {
    if (!tree.dirs) tree.dirs = {};
    if (!tree.dirs[current]) {
      tree.dirs[current] = { groupId: getNextId(), dirs: {}, files: [] };
    }
    addPathToTree(tree.dirs[current], parts.slice(1), item);
  }
}

const dirTree = { dirs: {}, files: [] };
for (const item of swiftItems) {
  const parts = item.relPath.split('/');
  addPathToTree(dirTree, parts, item);
}

// Generate PBXGroup sections
let pbxGroupsContent = '';

function generateGroupDefinitions(groupName, treeNode, pathName = null) {
  const childIds = [];
  
  if (treeNode.dirs) {
    for (const subDirName of Object.keys(treeNode.dirs).sort()) {
      const subNode = treeNode.dirs[subDirName];
      childIds.push(`${subNode.groupId} /* ${subDirName} */`);
      generateGroupDefinitions(subDirName, subNode, subDirName);
    }
  }

  if (treeNode.files) {
    for (const fileItem of treeNode.files) {
      childIds.push(`${fileItem.fileRefId} /* ${fileItem.fileName} */`);
    }
  }

  if (groupName === 'AcademicOS') {
    childIds.push(`${assetsFileRefId} /* Assets.xcassets */`);
    childIds.push(`${infoPlistRefId} /* Info.plist */`);
  }

  const p = pathName ? `path = "${pathName}"; ` : '';
  pbxGroupsContent += `\t\t${treeNode.groupId || academicOSGroupId} /* ${groupName} */ = {\n`;
  pbxGroupsContent += `\t\t\tisa = PBXGroup;\n`;
  pbxGroupsContent += `\t\t\tchildren = (\n`;
  for (const cid of childIds) {
    pbxGroupsContent += `\t\t\t\t${cid},\n`;
  }
  pbxGroupsContent += `\t\t\t);\n`;
  if (pathName) {
    pbxGroupsContent += `\t\t\t${p}sourceTree = "<group>";\n`;
  } else {
    pbxGroupsContent += `\t\t\tpath = AcademicOS;\n`;
    pbxGroupsContent += `\t\t\tsourceTree = "<group>";\n`;
  }
  pbxGroupsContent += `\t\t};\n`;
}

generateGroupDefinitions('AcademicOS', dirTree);

// PBXBuildFile section
let buildFilesSection = '';
for (const item of swiftItems) {
  buildFilesSection += `\t\t${item.buildFileId} /* ${item.fileName} in Sources */ = {isa = PBXBuildFile; fileRef = ${item.fileRefId} /* ${item.fileName} */; };\n`;
}
buildFilesSection += `\t\t${assetsBuildFileId} /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = ${assetsFileRefId} /* Assets.xcassets */; };\n`;
for (const fw of frameworkRefs) {
  buildFilesSection += `\t\t${fw.buildFileId} /* ${fw.name} in Frameworks */ = {isa = PBXBuildFile; fileRef = ${fw.fileRefId} /* ${fw.name} */; };\n`;
}

// PBXFileReference section
let fileRefsSection = '';
fileRefsSection += `\t\t${appRefId} /* AcademicOS.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AcademicOS.app; sourceTree = BUILT_PRODUCTS_DIR; };\n`;
fileRefsSection += `\t\t${assetsFileRefId} /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };\n`;
fileRefsSection += `\t\t${infoPlistRefId} /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };\n`;

for (const item of swiftItems) {
  fileRefsSection += `\t\t${item.fileRefId} /* ${item.fileName} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "${item.fileName}"; sourceTree = "<group>"; };\n`;
}
for (const fw of frameworkRefs) {
  const isTbd = fw.name.endsWith('.tbd');
  fileRefsSection += `\t\t${fw.fileRefId} /* ${fw.name} */ = {isa = PBXFileReference; lastKnownFileType = "${isTbd ? 'sourcecode.text-based-dylib-definition' : 'wrapper.framework'}"; name = "${fw.name}"; path = "${fw.path}"; sourceTree = SDKROOT; };\n`;
}

// PBXFrameworksBuildPhase
let frameworksBuildPhase = `\t\t${frameworksBuildPhaseId} /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n`;
for (const fw of frameworkRefs) {
  frameworksBuildPhase += `\t\t\t\t${fw.buildFileId} /* ${fw.name} in Frameworks */,\n`;
}
frameworksBuildPhase += `\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n`;

// PBXSourcesBuildPhase
let sourcesBuildPhase = `\t\t${sourcesBuildPhaseId} /* Sources */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n`;
for (const item of swiftItems) {
  sourcesBuildPhase += `\t\t\t\t${item.buildFileId} /* ${item.fileName} in Sources */,\n`;
}
sourcesBuildPhase += `\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n`;

// Full project content
const pbxprojContent = `// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 56;
\tobjects = {

/* Begin PBXBuildFile section */
${buildFilesSection}/* End PBXBuildFile section */

/* Begin PBXFileReference section */
${fileRefsSection}/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
${frameworksBuildPhase}/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t${mainGroupId} = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t${academicOSGroupId} /* AcademicOS */,
\t\t\t\t${frameworksGroupId} /* Frameworks */,
\t\t\t\t${productsGroupId} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
${pbxGroupsContent}
\t\t${frameworksGroupId} /* Frameworks */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
${frameworkRefs.map(fw => `\t\t\t\t${fw.fileRefId} /* ${fw.name} */,`).join('\n')}
\t\t\t);
\t\t\tname = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t${productsGroupId} /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t${appRefId} /* AcademicOS.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t${targetId} /* AcademicOS */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = ${targetConfigListId} /* Build configuration list for PBXNativeTarget "AcademicOS" */;
\t\t\tbuildPhases = (
\t\t\t\t${sourcesBuildPhaseId} /* Sources */,
\t\t\t\t${frameworksBuildPhaseId} /* Frameworks */,
\t\t\t\t${resourcesBuildPhaseId} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = AcademicOS;
\t\t\tproductName = AcademicOS;
\t\t\tproductReference = ${appRefId} /* AcademicOS.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t${projectId} /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tattributes = {
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {
\t\t\t\t\t${targetId} = {
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t};
\t\t\t\t};
\t\t\t};
\t\t\tbuildConfigurationList = ${projectConfigListId} /* Build configuration list for PBXProject "AcademicOS" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = ${mainGroupId};
\t\t\tproductRefGroup = ${productsGroupId} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t${targetId} /* AcademicOS */,
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t${resourcesBuildPhaseId} /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t${assetsBuildFileId} /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
${sourcesBuildPhase}/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t${targetDebugConfigId} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGNING_ALLOWED = NO;
\t\t\t\tCODE_SIGNING_REQUIRED = NO;
\t\t\t\tCODE_SIGN_IDENTITY = "";
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = AcademicOS/AcademicOS.entitlements;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = NO;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = AcademicOS/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tOTHER_LDFLAGS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"-lsqlite3",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.academicos.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t${targetReleaseConfigId} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGNING_ALLOWED = NO;
\t\t\t\tCODE_SIGNING_REQUIRED = NO;
\t\t\t\tCODE_SIGN_IDENTITY = "";
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = AcademicOS/AcademicOS.entitlements;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = NO;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = AcademicOS/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tOTHER_LDFLAGS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"-lsqlite3",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.academicos.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t};
\t\t\tname = Release;
\t\t};
\t\t${projectDebugConfigId} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t${projectReleaseConfigId} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t};
\t\t\tname = Release;
\t\t};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t${targetConfigListId} /* Build configuration list for PBXNativeTarget "AcademicOS" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t${targetDebugConfigId} /* Debug */,
\t\t\t\t${targetReleaseConfigId} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t${projectConfigListId} /* Build configuration list for PBXProject "AcademicOS" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t${projectDebugConfigId} /* Debug */,
\t\t\t\t${projectReleaseConfigId} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */

\t};
\trootObject = ${projectId} /* Project object */;
}
`;

const projectPath = path.join(rootDir, 'AcademicOS.xcodeproj', 'project.pbxproj');
fs.writeFileSync(projectPath, pbxprojContent, 'utf8');
console.log(`Successfully updated ${projectPath} with all ${swiftFiles.length} Swift files, frameworks, and settings!`);
