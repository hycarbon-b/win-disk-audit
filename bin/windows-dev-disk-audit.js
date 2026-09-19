#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const skillName = 'windows-dev-disk-audit';
const source = path.resolve(__dirname, '..', 'skills', skillName);

function fail(message) {
  process.stderr.write(`Error: ${message}\n`);
  process.exitCode = 1;
}

function usage() {
  process.stdout.write(`Windows Developer Disk Audit\n\n` +
    `Install from GitHub:\n` +
    `  npx --yes github:hycarbon-b/windows-dev-disk-audit install --agent codex\n\n` +
    `Commands:\n` +
    `  install [--agent codex|claude|agents] [--target <skills-dir>] [--replace]\n` +
    `  path\n\n` +
    `The installer only copies the skill. It never runs a disk scan or cleanup.\n`);
}

function parseInstallArgs(args) {
  const options = { agent: 'codex', target: null, replace: false };
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === '--agent') {
      options.agent = args[++index];
    } else if (arg === '--target') {
      options.target = args[++index];
    } else if (arg === '--replace') {
      options.replace = true;
    } else {
      throw new Error(`Unknown install option: ${arg}`);
    }
  }
  if (!options.target && !['codex', 'claude', 'agents'].includes(options.agent)) {
    throw new Error('--agent must be codex, claude, or agents.');
  }
  if ((options.target === null && options.agent === undefined) || (options.target !== null && !options.target)) {
    throw new Error('A value is required after --agent or --target.');
  }
  return options;
}

function defaultSkillsDirectory(agent) {
  const home = os.homedir();
  if (agent === 'codex') {
    return process.env.CODEX_HOME
      ? path.join(process.env.CODEX_HOME, 'skills')
      : path.join(home, '.codex', 'skills');
  }
  if (agent === 'claude') return path.join(home, '.claude', 'skills');
  return path.join(home, '.agents', 'skills');
}

function install(options) {
  if (!fs.existsSync(source)) throw new Error(`Bundled skill is missing: ${source}`);

  const skillsDirectory = path.resolve(options.target || defaultSkillsDirectory(options.agent));
  const destination = path.join(skillsDirectory, skillName);
  fs.mkdirSync(skillsDirectory, { recursive: true });

  let backup = null;
  if (fs.existsSync(destination)) {
    if (!options.replace) {
      throw new Error(`${destination} already exists. Re-run with --replace to move it to a timestamped backup.`);
    }
    backup = `${destination}.backup-${new Date().toISOString().replace(/[:.]/g, '-')}`;
    fs.renameSync(destination, backup);
  }

  const staging = path.join(skillsDirectory, `.${skillName}-install-${process.pid}-${Date.now()}`);
  try {
    fs.cpSync(source, staging, { recursive: true, force: false, errorOnExist: true });
    fs.renameSync(staging, destination);
  } catch (error) {
    if (fs.existsSync(staging)) fs.rmSync(staging, { recursive: true, force: true });
    if (backup && !fs.existsSync(destination)) fs.renameSync(backup, destination);
    throw error;
  }

  process.stdout.write(`Installed ${skillName} to ${destination}\n`);
  if (backup) process.stdout.write(`Previous version moved to ${backup}\n`);
  process.stdout.write('Restart Codex or begin a new task to load the installed skill.\n');
}

try {
  const [command, ...args] = process.argv.slice(2);
  if (!command || command === '--help' || command === '-h' || command === 'help') {
    usage();
  } else if (command === 'path') {
    process.stdout.write(`${source}\n`);
  } else if (command === 'install') {
    install(parseInstallArgs(args));
  } else {
    fail(`Unknown command: ${command}`);
    usage();
  }
} catch (error) {
  fail(error.message);
}
