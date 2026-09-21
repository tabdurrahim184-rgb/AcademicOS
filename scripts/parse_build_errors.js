const fs = require('fs');
const path = require('path');

const logPath = path.resolve('xcodebuild.log');
const log = fs.existsSync(logPath) ? fs.readFileSync(logPath, 'utf8') : '';

const categories = {
  'Firebase': [],
  'FoundationModels': [],
  'WebKit': [],
  'SQLite': [],
  'Swift concurrency': [],
  'missing files': [],
  'target membership': [],
  'Info.plist': [],
  'entitlements': [],
  'other': []
};

const lines = log.split('\n');
for (const line of lines) {
  if (line.includes('error:')) {
    let matched = false;
    if (/firebase/i.test(line)) {
      categories['Firebase'].push(line.trim());
      matched = true;
    } else if (/foundationmodels|applefoundationmodel|languagemodel/i.test(line)) {
      categories['FoundationModels'].push(line.trim());
      matched = true;
    } else if (/webkit/i.test(line)) {
      categories['WebKit'].push(line.trim());
      matched = true;
    } else if (/sqlite/i.test(line)) {
      categories['SQLite'].push(line.trim());
      matched = true;
    } else if (/concurrency|sendable|actor|isolated/i.test(line)) {
      categories['Swift concurrency'].push(line.trim());
      matched = true;
    } else if (/no such file|file not found/i.test(line)) {
      categories['missing files'].push(line.trim());
      matched = true;
    } else if (/undefined symbol|target/i.test(line)) {
      categories['target membership'].push(line.trim());
      matched = true;
    } else if (/info\.plist/i.test(line)) {
      categories['Info.plist'].push(line.trim());
      matched = true;
    } else if (/entitlement/i.test(line)) {
      categories['entitlements'].push(line.trim());
      matched = true;
    }
    if (!matched) {
      categories['other'].push(line.trim());
    }
  }
}

let report = `# AcademicOS iOS Build Failure Report\n\n`;
report += `- **Date/Time:** ${new Date().toISOString()}\n`;
report += `- **Build Target:** AcademicOS (\`iphoneos\` physical device)\n`;
report += `- **Configuration:** Release (Unsigned)\n\n`;
report += `## Summary of Compiler Errors by Category\n\n`;

for (const [cat, errors] of Object.entries(categories)) {
  report += `### ${cat} (${errors.length})\n`;
  if (errors.length === 0) {
    report += `*No errors recorded in this category.*\n\n`;
  } else {
    report += '```text\n' + errors.slice(0, 50).join('\n') + '\n```\n\n';
  }
}

fs.writeFileSync('BUILD_FAILURE_REPORT.md', report, 'utf8');
console.log('BUILD_FAILURE_REPORT.md generated successfully.');
