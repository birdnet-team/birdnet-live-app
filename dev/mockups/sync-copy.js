#!/usr/bin/env node
/* =============================================================================
   Sync store mockup copy from Markdown
   ============================================================================= */

const fs = require('fs');
const path = require('path');

const root = __dirname;
const copyPath = path.join(root, 'mockups.copy.md');
const generatedPath = path.join(root, 'mockups.copy.generated.js');

function parseCopyMarkdown(markdown) {
  const copy = { languages: {} };
  let currentLanguage = null;
  let currentSlide = null;

  for (const rawLine of markdown.split(/\r?\n/)) {
    const line = rawLine.trimEnd();
    const languageMatch = /^##\s+([A-Za-z]{2}(?:-[A-Za-z]{2})?)\s*$/.exec(line);
    if (languageMatch) {
      currentLanguage = languageMatch[1];
      currentSlide = null;
      copy.languages[currentLanguage] = copy.languages[currentLanguage] || {
        slides: {},
      };
      continue;
    }

    const slideMatch = /^###\s+([A-Za-z0-9_-]+)\s*$/.exec(line);
    if (slideMatch) {
      if (!currentLanguage) {
        throw new Error(`Slide appears before language section: ${line}`);
      }
      currentSlide = slideMatch[1];
      copy.languages[currentLanguage].slides[currentSlide] =
        copy.languages[currentLanguage].slides[currentSlide] || {};
      continue;
    }

    const titleMatch = /^Title:\s*(.*)$/.exec(line);
    if (titleMatch) {
      requireSlide(currentLanguage, currentSlide, line);
      copy.languages[currentLanguage].slides[currentSlide].title =
        titleMatch[1].trim();
      continue;
    }

    const subtitleMatch = /^Subtitle:\s*(.*)$/.exec(line);
    if (subtitleMatch) {
      requireSlide(currentLanguage, currentSlide, line);
      copy.languages[currentLanguage].slides[currentSlide].subtitle =
        subtitleMatch[1].trim();
    }
  }

  return copy;
}

function requireSlide(language, slide, line) {
  if (!language || !slide) {
    throw new Error(`Copy line appears outside a slide section: ${line}`);
  }
}

function loadCopy(filePath = copyPath) {
  return parseCopyMarkdown(fs.readFileSync(filePath, 'utf8'));
}

function applyCopyToConfig(config, copy) {
  for (const [languageCode, languageCopy] of Object.entries(copy.languages)) {
    const languageConfig = config.languages[languageCode];
    if (!languageConfig) continue;
    for (const [slideId, slideCopy] of Object.entries(languageCopy.slides)) {
      languageConfig.slides[slideId] = {
        ...(languageConfig.slides[slideId] || {}),
        ...slideCopy,
      };
    }
  }
  return config;
}

function writeGeneratedCopy(copy, filePath = generatedPath) {
  const json = JSON.stringify(copy, null, 2);
  const source = `// Generated from mockups.copy.md by sync-copy.js. Do not edit.\n` +
    `window.BIRDNET_MOCKUP_COPY = ${json};\n` +
    `(function applyMockupCopy() {\n` +
    `  const config = window.BIRDNET_MOCKUPS;\n` +
    `  const copy = window.BIRDNET_MOCKUP_COPY;\n` +
    `  if (!config || !copy) return;\n` +
    `  for (const [languageCode, languageCopy] of Object.entries(copy.languages || {})) {\n` +
    `    const languageConfig = config.languages[languageCode];\n` +
    `    if (!languageConfig) continue;\n` +
    `    for (const [slideId, slideCopy] of Object.entries(languageCopy.slides || {})) {\n` +
    `      languageConfig.slides[slideId] = {\n` +
    `        ...(languageConfig.slides[slideId] || {}),\n` +
    `        ...slideCopy,\n` +
    `      };\n` +
    `    }\n` +
    `  }\n` +
    `})();\n`;
  fs.writeFileSync(filePath, source, 'utf8');
}

function syncCopy() {
  const copy = loadCopy();
  writeGeneratedCopy(copy);
  return copy;
}

if (require.main === module) {
  const copy = syncCopy();
  const languageCount = Object.keys(copy.languages).length;
  const slideCount = Object.values(copy.languages)[0]
    ? Object.keys(Object.values(copy.languages)[0].slides).length
    : 0;
  console.log(`Synced ${languageCount} languages x ${slideCount} slides to ${path.basename(generatedPath)}`);
}

module.exports = {
  applyCopyToConfig,
  loadCopy,
  parseCopyMarkdown,
  syncCopy,
  writeGeneratedCopy,
};
