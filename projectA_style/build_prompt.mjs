import fs from 'node:fs';
import path from 'node:path';

const baseDir = '/Users/gue1971/MyWorks/ai-news/projectA_style';
const [styleId, characterId] = process.argv.slice(2);
if (!styleId || !characterId) {
  console.error('Usage: node build_prompt.mjs <main|shinen> <characterId>');
  process.exit(1);
}

const styleFile = styleId === 'shinen' ? 'style_shinen.txt' : 'style_main.txt';
const template = fs.readFileSync(path.join(baseDir, 'prompts/base_template.txt'), 'utf8');
const style = fs.readFileSync(path.join(baseDir, `prompts/${styleFile}`), 'utf8').trim();
const blocks = JSON.parse(fs.readFileSync(path.join(baseDir, 'prompts/character_blocks.json'), 'utf8'));
const ch = blocks[characterId];
if (!ch) {
  console.error(`Unknown characterId: ${characterId}`);
  process.exit(1);
}

const prompt = template
  .replace('[STYLE_BLOCK]', style)
  .replace('[CHARACTER_BLOCK]', ch);

const out = path.join(baseDir, `prompt_${styleId}_${characterId}.txt`);
fs.writeFileSync(out, prompt, 'utf8');
console.log(out);
