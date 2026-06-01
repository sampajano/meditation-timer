import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();

const requiredFiles = [
  'shared/audio/start.mp3',
  'shared/audio/interval-bell.mp3',
  'shared/audio/SOURCES.md',
];

const forbiddenFiles = [
  'web/public/start.mp3',
  'web/public/interval-bell.mp3',
];

const failures = [];

for (const file of requiredFiles) {
  if (!existsSync(join(root, file))) {
    failures.push(`Missing required shared audio file: ${file}`);
  }
}

for (const file of forbiddenFiles) {
  if (existsSync(join(root, file))) {
    failures.push(`Audio file should not live in web/public: ${file}`);
  }
}

const appDelegate = readFileSync(join(root, 'ios/App/App/AppDelegate.swift'), 'utf8');
for (const resource of ['start', 'interval-bell']) {
  const expected = `Bundle.main.path(forResource: "${resource}", ofType: "mp3", inDirectory: "audio")`;
  if (!appDelegate.includes(expected)) {
    failures.push(`AppDelegate should load ${resource}.mp3 from the audio bundle directory`);
  }
}

const xcodeProject = readFileSync(join(root, 'ios/App/App.xcodeproj/project.pbxproj'), 'utf8');
if (!xcodeProject.includes('/* shared-audio in Resources */')) {
  failures.push('Xcode project should bundle shared-audio in Resources');
}
if (!xcodeProject.includes('path = ../../shared/audio;')) {
  failures.push('Xcode project should point shared-audio at ../../shared/audio');
}

const webApp = readFileSync(join(root, 'web/src/App.jsx'), 'utf8');
if (!webApp.includes("../../shared/audio/start.mp3?url")) {
  failures.push('Web app should import start.mp3 from shared/audio');
}
if (!webApp.includes("../../shared/audio/interval-bell.mp3?url")) {
  failures.push('Web app should import interval-bell.mp3 from shared/audio');
}
for (const oldPath of ["'/start.mp3'", "'/interval-bell.mp3'", "'/tingsha3.mp3'"]) {
  if (webApp.includes(oldPath)) {
    failures.push(`Web app should not hardcode legacy public audio path ${oldPath}`);
  }
}

if (failures.length > 0) {
  console.error(failures.join('\n'));
  process.exit(1);
}

console.log('Shared audio asset layout is valid.');
