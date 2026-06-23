#!/usr/bin/env node
// Minimal OpenAI Codex CLI using node >=18 (fetch available)
// Usage examples:
//   OPENAI_API_KEY=sk... codex -p "Write a Python function to reverse a list"
//   OPENAI_API_KEY=sk... echo "print('hi')" | codex
//   OPENAI_API_KEY=sk... codex -f ./script.py

const { spawnSync } = require('child_process');
const fs = require('fs');

function usage() {
  console.error(`Usage: codex [-p "prompt"] [-f file] [--raw]

If no -p or -f is provided, reads prompt from stdin.
Environment variables:
  OPENAI_API_KEY  (required)
  OPENAI_MODEL    (optional, default: code-davinci-002)
  OPENAI_MAX_TOKENS (optional, default: 256)
  OPENAI_TEMPERATURE (optional, default: 0.2)
`);
}

async function main() {
  const argv = process.argv.slice(2);
  let prompt = '';
  let file = '';
  let raw = false;

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '-p' || a === '--prompt') {
      i++;
      prompt = argv[i] || '';
    } else if (a === '-f' || a === '--file') {
      i++;
      file = argv[i] || '';
    } else if (a === '--raw') {
      raw = true;
    } else if (a === '-h' || a === '--help') {
      usage();
      process.exit(0);
    } else {
      console.error('Unknown arg:', a);
      usage();
      process.exit(2);
    }
  }

  if (!process.env.OPENAI_API_KEY) {
    console.error('Missing OPENAI_API_KEY environment variable');
    process.exit(2);
  }

  const model = process.env.OPENAI_MODEL || 'code-davinci-002';
  const max_tokens = Number(process.env.OPENAI_MAX_TOKENS || '256');
  const temperature = Number(process.env.OPENAI_TEMPERATURE || '0.2');

  if (file) {
    try {
      prompt = fs.readFileSync(file, 'utf8');
    } catch (err) {
      console.error('Failed to read file:', err.message);
      process.exit(2);
    }
  }

  if (!prompt) {
    // read stdin if available
    if (process.stdin.isTTY) {
      usage();
      process.exit(2);
    }
    prompt = await new Promise((resolve) => {
      let data = '';
      process.stdin.setEncoding('utf8');
      process.stdin.on('data', chunk => data += chunk);
      process.stdin.on('end', () => resolve(data));
    });
  }

  const payload = {
    model,
    prompt,
    max_tokens,
    temperature
  };

  const res = await fetch('https://api.openai.com/v1/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
    },
    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    const text = await res.text();
    console.error('OpenAI API error:', res.status, res.statusText);
    console.error(text);
    process.exit(2);
  }

  const data = await res.json();
  if (raw) {
    console.log(JSON.stringify(data, null, 2));
    return;
  }

  if (data.choices && data.choices.length > 0) {
    // Print the first completion text
    process.stdout.write(data.choices[0].text || '');
  } else {
    console.log(JSON.stringify(data, null, 2));
  }
}

main().catch(err => {
  console.error('Error:', err && err.stack ? err.stack : err);
  process.exit(2);
});
