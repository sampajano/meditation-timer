import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const failures = [];

const widget = readFileSync(
  join(root, 'ios/App/MeditationLiveActivityExtension/MeditationLiveActivityWidget.swift'),
  'utf8',
);
const appDelegate = readFileSync(join(root, 'ios/App/GoldenMeditationApp/AppDelegate.swift'), 'utf8');
const compactTrailingMatch = widget.match(/compactTrailing:\s*\{([\s\S]*?)\}\s*minimal:/);
const compactTrailingBody = compactTrailingMatch?.[1] ?? '';

if (!/compactLeading:\s*\{\s*Image\(systemName:\s*"bell\.fill"\)/s.test(widget)) {
  failures.push('Dynamic Island compact leading region should show the bell icon instead of rendering empty black space.');
}

if (!/compactTrailing:\s*\{\s*EmptyView\(\)/s.test(widget)) {
  failures.push('Dynamic Island compact trailing region should be empty so the MacBook menu bar shows only the bell.');
}

if (/Text\(/.test(compactTrailingBody)) {
  failures.push('Dynamic Island compact trailing region should not render time text.');
}

if (/private func compactTimerText\(for context:/s.test(widget)) {
  failures.push('Compact timer helper should be removed when compact time is not displayed.');
}

if (/Text\(\s*startedAt\s*,\s*style:\s*\.timer\s*\)/s.test(widget)) {
  failures.push('Overtime Live Activity text should not render a past start date with SwiftUI .timer, which can crash the extension.');
}

if (!/endsAt\.timeIntervalSinceNow\s*>\s*0[\s\S]*?Text\(context\.state\.endsAt,\s*style:\s*\.timer\)/s.test(widget)) {
  failures.push('Countdown Live Activity timer should guard against stale or past end dates before using SwiftUI .timer.');
}

if (/lastRunningLiveActivityCompactTimeText/.test(appDelegate)) {
  failures.push('The app should not keep minute-refresh state when compact time is hidden.');
}

if (/timeLeft\s*=\s*transition\.remaining[\s\S]*?updateRunningLiveActivity\(remaining:\s*timeLeft\)/s.test(appDelegate)) {
  failures.push('Timer ticks should not push hidden compact time updates.');
}

if (!/private let intervalGongVolume:\s*Float\s*=\s*0\.12\b/.test(appDelegate)) {
  failures.push('Interval gong volume should be lowered to 0.12, 40% below the previous 0.20 setting.');
}

if (failures.length > 0) {
  console.error(failures.join('\n'));
  process.exit(1);
}

console.log('Live Activity widget and interval bell settings are valid.');
