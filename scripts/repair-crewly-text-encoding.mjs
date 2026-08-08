#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import Database from 'better-sqlite3';
import {
  hasEncodingDamage,
  repairTextEncoding,
} from '../dist/backend/backend/src/utils/text-encoding.js';

const apply = process.argv.includes('--apply');
const crewlyHome = process.env.CREWLY_HOME || path.join(os.homedir(), '.crewly');
const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
const backupRoot = path.join(crewlyHome, 'backups', `text-encoding-${timestamp}`);

function repairValue(value) {
  if (typeof value === 'string') return repairTextEncoding(value);
  if (Array.isArray(value)) return value.map(repairValue);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, repairValue(child)]));
  }
  return value;
}

function collectJsonFiles(root) {
  const found = [];
  const visit = (current) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      if (entry.name === 'backups' || entry.name === 'logs') continue;
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) visit(absolute);
      else if (entry.name.endsWith('.json')) found.push(absolute);
    }
  };
  visit(root);
  return found;
}

function backupFile(file) {
  const relative = path.relative(crewlyHome, file);
  const target = path.join(backupRoot, relative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(file, target);
}

const report = {
  mode: apply ? 'apply' : 'dry-run',
  chatMessagesChanged: 0,
  chatFieldsChanged: 0,
  jsonFilesChanged: 0,
  jsonStringsChanged: 0,
  unresolvedStrings: 0,
  backupRoot: apply ? backupRoot : null,
};

const chatPath = path.join(crewlyHome, 'chat.db');
if (fs.existsSync(chatPath)) {
  const db = new Database(chatPath, apply ? {} : { readonly: true });
  const repairableColumns = ['content', 'sender_id', 'metadata', 'mentions'];
  const rows = db.prepare(`SELECT id, ${repairableColumns.join(', ')} FROM chat_messages`).all();
  const changes = rows
    .map((row) => {
      const repaired = Object.fromEntries(
        repairableColumns.map((column) => [
          column,
          typeof row[column] === 'string' ? repairTextEncoding(row[column]) : row[column],
        ]),
      );
      const changedColumns = repairableColumns.filter((column) => repaired[column] !== row[column]);
      return { ...row, repaired, changedColumns };
    })
    .filter((row) => row.changedColumns.length > 0);
  report.chatMessagesChanged = changes.length;
  report.chatFieldsChanged = changes.reduce((total, row) => total + row.changedColumns.length, 0);
  report.unresolvedStrings += changes.reduce(
    (total, row) => total + repairableColumns.filter(
      (column) => typeof row.repaired[column] === 'string' && hasEncodingDamage(row.repaired[column]),
    ).length,
    0,
  );
  if (apply && changes.length > 0) {
    backupFile(chatPath);
    for (const suffix of ['-wal', '-shm']) {
      if (fs.existsSync(`${chatPath}${suffix}`)) backupFile(`${chatPath}${suffix}`);
    }
    const update = db.prepare(
      'UPDATE chat_messages SET content = ?, sender_id = ?, metadata = ?, mentions = ? WHERE id = ?',
    );
    db.transaction(() => {
      for (const row of changes) {
        update.run(
          row.repaired.content,
          row.repaired.sender_id,
          row.repaired.metadata,
          row.repaired.mentions,
          row.id,
        );
      }
    })();
  }
  db.close();
}

for (const file of collectJsonFiles(crewlyHome)) {
  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    continue;
  }
  const repaired = repairValue(parsed);
  const before = JSON.stringify(parsed);
  const after = JSON.stringify(repaired);
  if (before === after) continue;
  report.jsonFilesChanged += 1;
  const countStrings = (value) => {
    if (typeof value === 'string') {
      if (repairTextEncoding(value) !== value) report.jsonStringsChanged += 1;
      if (hasEncodingDamage(repairTextEncoding(value))) report.unresolvedStrings += 1;
      return;
    }
    if (Array.isArray(value)) value.forEach(countStrings);
    else if (value && typeof value === 'object') Object.values(value).forEach(countStrings);
  };
  countStrings(parsed);
  if (apply) {
    backupFile(file);
    fs.writeFileSync(file, `${JSON.stringify(repaired, null, 2)}\n`, 'utf8');
  }
}

console.log(JSON.stringify(report, null, 2));
