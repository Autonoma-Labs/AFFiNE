import fs from 'node:fs';
import { spawn } from 'node:child_process';
import process from 'node:process';

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function applyRenderDefaults(env) {
  if (!env.AFFINE_SERVER_EXTERNAL_URL && env.RENDER_EXTERNAL_URL) {
    env.AFFINE_SERVER_EXTERNAL_URL = env.RENDER_EXTERNAL_URL;
  }

  if (!env.REDIS_SERVER_HOST && env.REDIS_URL) {
    const redis = new URL(env.REDIS_URL);
    env.REDIS_SERVER_HOST = redis.hostname;
    env.REDIS_SERVER_PORT = redis.port || '6379';
    env.REDIS_SERVER_USERNAME = decodeURIComponent(redis.username || '');
    env.REDIS_SERVER_PASSWORD = decodeURIComponent(redis.password || '');
  }
}

function run(command, args) {
  const child = spawn(command, args, {
    env: process.env,
    stdio: 'inherit',
  });

  child.on('exit', (code, signal) => {
    if (signal) {
      process.kill(process.pid, signal);
      return;
    }

    process.exit(code ?? 0);
  });
}

const mode = process.argv[2] ?? 'start';
const home = process.env.HOME || '/root';
const affineHome = `${home}/.affine`;

ensureDir(`${affineHome}/config`);
ensureDir(`${affineHome}/storage`);
applyRenderDefaults(process.env);

if (mode === 'predeploy') {
  run('node', ['./scripts/self-host-predeploy.js']);
} else if (mode === 'start') {
  run('node', ['./dist/main.js']);
} else {
  run(mode, process.argv.slice(3));
}
