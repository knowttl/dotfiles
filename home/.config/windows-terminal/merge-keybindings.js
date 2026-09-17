#!/usr/bin/env node
'use strict';

const fs = require('fs');

function stripJsonc(text) {
  let out = '';
  let i = 0;
  let inString = false;
  let stringQuote = '';
  let escaped = false;

  while (i < text.length) {
    const ch = text[i];
    const next = text[i + 1];

    if (inString) {
      out += ch;
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === stringQuote) {
        inString = false;
      }
      i += 1;
      continue;
    }

    if (ch === '"' || ch === "'") {
      inString = true;
      stringQuote = ch;
      out += ch;
      i += 1;
      continue;
    }

    if (ch === '/' && next === '/') {
      i += 2;
      while (i < text.length && text[i] !== '\n') {
        i += 1;
      }
      continue;
    }

    if (ch === '/' && next === '*') {
      i += 2;
      while (i + 1 < text.length && !(text[i] === '*' && text[i + 1] === '/')) {
        i += 1;
      }
      i += 2;
      continue;
    }

    out += ch;
    i += 1;
  }

  return out.replace(/,(\s*[}\]])/g, '$1');
}

function normalizeKeys(keys) {
  if (Array.isArray(keys)) {
    return keys.map((key) => String(key).toLowerCase()).sort().join('\0');
  }
  return String(keys || '').toLowerCase();
}

function main(argv) {
  const fragmentPath = argv[2];
  const settingsPath = argv[3];

  if (!fragmentPath || !settingsPath) {
    console.error('Usage: merge-keybindings.js <fragment.json> <settings.json>');
    process.exit(2);
  }

  const fragment = JSON.parse(fs.readFileSync(fragmentPath, 'utf8'));
  const original = fs.readFileSync(settingsPath, 'utf8');
  const settings = JSON.parse(stripJsonc(original));

  if (!Array.isArray(settings.actions)) {
    settings.actions = [];
  }
  if (!Array.isArray(settings.keybindings)) {
    settings.keybindings = [];
  }

  const fragmentActions = Array.isArray(fragment.actions) ? fragment.actions : [];
  const fragmentKeybindings = Array.isArray(fragment.keybindings)
    ? fragment.keybindings
    : [];

  for (const action of fragmentActions) {
    if (!action || !action.id) {
      continue;
    }
    const index = settings.actions.findIndex((entry) => entry && entry.id === action.id);
    if (index >= 0) {
      settings.actions[index] = action;
    } else {
      settings.actions.push(action);
    }
  }

  for (const binding of fragmentKeybindings) {
    if (!binding || binding.keys === undefined) {
      continue;
    }
    const key = normalizeKeys(binding.keys);
    const index = settings.keybindings.findIndex(
      (entry) => entry && entry.keys !== undefined && normalizeKeys(entry.keys) === key
    );
    if (index >= 0) {
      settings.keybindings[index] = binding;
    } else {
      settings.keybindings.push(binding);
    }
  }

  fs.writeFileSync(settingsPath, `${JSON.stringify(settings, null, 4)}\n`, 'utf8');
}

main(process.argv);
