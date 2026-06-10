#!/usr/bin/env node
/* =============================================================================
   BirdNET Live Store Mockup Renderer
   =============================================================================

   No npm packages required. This script launches an installed Chrome, Edge, or
   Chromium in headless mode and screenshots preview.html for each configured
   slide/language.

   Examples:
     node render-mockups.js
     node render-mockups.js --lang en
     node render-mockups.js --lang de --slide live
     node render-mockups.js --all-languages
    node render-mockups.js --device-screenshots
   ============================================================================= */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { applyCopyToConfig, syncCopy } = require('./sync-copy');

const root = __dirname;
const previewPath = path.join(root, 'preview.html');
const configPath = path.join(root, 'mockups.config.js');
const outputRoot = path.join(root, 'output');
const copy = syncCopy();
const config = applyCopyToConfig(loadConfig(configPath), copy);
const args = parseArgs(process.argv.slice(2));
const browser = findBrowser(args.browser);

if (!browser) {
  console.error('Could not find Chrome, Edge, or Chromium. Pass --browser "C:\\Path\\to\\chrome.exe".');
  process.exit(1);
}

const languages = args.deviceScreenshots
  ? ['en']
  : args.allLanguages
  ? Object.keys(config.languages)
  : [args.lang || 'en'];
const slides = config.slides
  .map((slide, index) => ({ slide, index }))
  .filter((entry) => !args.slide || entry.slide.id === args.slide);

if (slides.length === 0) {
  console.error(`Unknown slide: ${args.slide}`);
  process.exit(1);
}

fs.mkdirSync(outputRoot, { recursive: true });
const screenshotOutputDir = path.join(outputRoot, 'screenshots');

if (args.deviceScreenshots) {
  fs.mkdirSync(screenshotOutputDir, { recursive: true });
  if (!args.slide) {
    cleanGeneratedFiles(screenshotOutputDir, null, args.ipad);
  } else {
    for (const entry of slides) {
      cleanGeneratedSlideFiles(screenshotOutputDir, entry, args.ipad);
    }
  }
}

for (const lang of languages) {
  if (!config.languages[lang]) {
    console.error(`Unknown language: ${lang}`);
    process.exit(1);
  }

  const langDir = args.deviceScreenshots
    ? screenshotOutputDir
    : path.join(outputRoot, lang);
  fs.mkdirSync(langDir, { recursive: true });

  if (!args.deviceScreenshots && !args.slide) {
    cleanGeneratedFiles(langDir, null, args.ipad);
  }

  for (const { slide, index } of slides) {
    const number = String(index + 1).padStart(2, '0');
    const prefix = args.ipad ? 'ipad_' : '';
    const fileName = args.deviceScreenshots
      ? `${prefix}${number}-${slide.id}.png`
      : `${prefix}${lang}-${number}-${slide.id}.png`;
    const outputPath = path.join(langDir, fileName);
    const url = fileUrl(previewPath, {
      export: '1',
      device: args.deviceScreenshots ? '1' : '0',
      ipad: args.ipad ? '1' : '0',
      lang,
      slide: slide.id,
    });
    render(url, outputPath);
    console.log(`Wrote ${path.relative(root, outputPath)}`);
  }
}

function isGeneratedPng(file, ipad) {
  const isIpadFile = file.toLowerCase().startsWith('ipad_');
  if (ipad !== isIpadFile) return false;
  const checkName = isIpadFile ? file.slice(5) : file;
  return /^(?:[a-z]{2,3}-)?\d{2}-[a-z0-9-]+\.png$/i.test(checkName);
}

function cleanGeneratedFiles(dir, lang, ipad) {
  for (const file of fs.readdirSync(dir)) {
    if (!isGeneratedPng(file, ipad)) continue;
    if (lang) {
      const rest = ipad ? file.slice(5) : file;
      if (!rest.startsWith(`${lang}-`)) continue;
    }
    fs.unlinkSync(path.join(dir, file));
  }
}

function cleanGeneratedSlideFiles(dir, { slide, index }, ipad) {
  const number = String(index + 1).padStart(2, '0');
  const prefix = ipad ? 'ipad_' : '';
  const slidePattern = new RegExp(`^${prefix}(?:[a-z]{2,3}-)?${number}-${escapeRegExp(slide.id)}\\.png$`, 'i');
  for (const file of fs.readdirSync(dir)) {
    if (slidePattern.test(file)) fs.unlinkSync(path.join(dir, file));
  }
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function loadConfig(filePath) {
  const source = fs.readFileSync(filePath, 'utf8');
  const window = {};
  const fn = new Function('window', source + '\nreturn window.BIRDNET_MOCKUPS;');
  return fn(window);
}

function parseArgs(argv) {
  const parsed = {
    lang: 'en',
    slide: null,
    allLanguages: false,
    deviceScreenshots: false,
    ipad: false,
    browser: process.env.BROWSER || process.env.CHROME_PATH || process.env.EDGE_PATH || null,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--all-languages') {
      parsed.allLanguages = true;
    } else if (arg === '--device-screenshots') {
      parsed.deviceScreenshots = true;
    } else if (arg === '--ipad') {
      parsed.ipad = true;
    } else if (arg === '--lang') {
      parsed.lang = argv[++i];
    } else if (arg.startsWith('--lang=')) {
      parsed.lang = arg.slice('--lang='.length);
    } else if (arg === '--slide') {
      parsed.slide = argv[++i];
    } else if (arg.startsWith('--slide=')) {
      parsed.slide = arg.slice('--slide='.length);
    } else if (arg === '--browser') {
      parsed.browser = argv[++i];
    } else if (arg.startsWith('--browser=')) {
      parsed.browser = arg.slice('--browser='.length);
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      console.error(`Unknown argument: ${arg}`);
      printHelp();
      process.exit(1);
    }
  }

  return parsed;
}

function printHelp() {
  console.log(`Usage:
  node render-mockups.js [options]

Options:
  --lang <code>         Render one language. Default: en
  --all-languages      Render every language in mockups.config.js
  --slide <id>         Render one slide only
  --device-screenshots Render clean device screenshots once to output/screenshots
  --ipad               Render iPad portrait mockups instead of iPhone
  --browser <path>     Path to Chrome, Edge, or Chromium
  --help               Show this help
`);
}

function findBrowser(explicitPath) {
  const candidates = [];
  if (explicitPath) candidates.push(explicitPath);

  if (process.platform === 'win32') {
    const programFiles = [
      process.env.PROGRAMFILES,
      process.env['PROGRAMFILES(X86)'],
      process.env.LOCALAPPDATA,
    ].filter(Boolean);

    for (const base of programFiles) {
      candidates.push(path.join(base, 'Google', 'Chrome', 'Application', 'chrome.exe'));
      candidates.push(path.join(base, 'Microsoft', 'Edge', 'Application', 'msedge.exe'));
      candidates.push(path.join(base, 'Chromium', 'Application', 'chrome.exe'));
    }
    candidates.push('chrome.exe', 'msedge.exe', 'chromium.exe');
  } else if (process.platform === 'darwin') {
    candidates.push(
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
      '/Applications/Chromium.app/Contents/MacOS/Chromium',
      'google-chrome',
      'microsoft-edge',
      'chromium',
    );
  } else {
    candidates.push('google-chrome', 'google-chrome-stable', 'microsoft-edge', 'chromium', 'chromium-browser');
  }

  for (const candidate of candidates) {
    if (!candidate) continue;
    if (candidate.includes(path.sep) && !fs.existsSync(candidate)) continue;
    const result = spawnSync(candidate, ['--version'], { encoding: 'utf8', shell: false });
    if (result.status === 0) return candidate;
  }
  return null;
}

function render(url, outputPath) {
  const canvas = args.deviceScreenshots
    ? config.deviceScreenshot
    : args.ipad
    ? config.ipadCanvas
    : config.canvas;
  const browserArgs = [
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--allow-file-access-from-files',
    '--default-background-color=00000000',
    '--no-first-run',
    '--no-default-browser-check',
    `--window-size=${canvas.width},${canvas.height}`,
    '--force-device-scale-factor=1',
    `--screenshot=${outputPath}`,
    url,
  ];

  const result = spawnSync(browser, browserArgs, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  if (result.status !== 0) {
    console.error(result.stdout);
    console.error(result.stderr);
    throw new Error(`Browser exited with code ${result.status}`);
  }
}

function fileUrl(filePath, query) {
  const url = new URL(`file://${path.resolve(filePath).replace(/\\/g, '/')}`);
  for (const [key, value] of Object.entries(query)) {
    url.searchParams.set(key, value);
  }
  return url.toString();
}
