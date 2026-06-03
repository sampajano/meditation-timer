import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const failures = [];

const widget = readFileSync(
  join(root, 'ios/App/MeditationLiveActivityExtension/MeditationLiveActivityWidget.swift'),
  'utf8',
);
const appDelegate = readFileSync(join(root, 'ios/App/App/AppDelegate.swift'), 'utf8');

if (!/compactLeading:\s*\{\s*Image\(systemName:\s*"bell\.fill"\)/s.test(widget)) {
  failures.push('Dynamic Island compact leading region should show the bell icon instead of rendering empty black space.');
}

if (!/compactTrailing:\s*\{\s*Text\(context\.state\.compactTimeText\)/s.test(widget)) {
  failures.push('Dynamic Island compact trailing region should show compactTimeText instead of rendering empty black space.');
}

if (!/private let intervalGongVolume:\s*Float\s*=\s*0\.12\b/.test(appDelegate)) {
  failures.push('Interval gong volume should be lowered to 0.12, 40% below the previous 0.20 setting.');
}

if (failures.length > 0) {
  console.error(failures.join('\n'));
  process.exit(1);
}

console.log('Live Activity widget and interval bell settings are valid.');
