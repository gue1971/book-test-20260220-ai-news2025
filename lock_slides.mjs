import fs from 'fs';

const appPath = '/Users/gue1971/MyWorks/ai-news/app.js';
const outJson = '/Users/gue1971/MyWorks/ai-news/SLIDES_FINAL_LOCK_JA.json';
const outMd = '/Users/gue1971/MyWorks/ai-news/SLIDES_FINAL_LOCK_JA.md';

const src = fs.readFileSync(appPath, 'utf8');
const m = src.match(/const slides = (\[[\s\S]*?\n\]);\n\nconst readerTexts/);
if (!m) throw new Error('slides block not found');

const slides = Function(`"use strict"; return (${m[1]});`)();

fs.writeFileSync(outJson, JSON.stringify({ locked: true, version: 'final', slides }, null, 2) + '\n');

let md = '# 18枚台本 最終確定（変更禁止）\n\n';
md += 'このファイルは生成用の固定台本です。生成中は文言を変更しません。\n\n';
slides.forEach((s, i) => {
  md += `## ${i + 1}. ${s.title}\n`;
  md += `- 時期: ${s.era}\n`;
  md += `- 見出し: ${s.title}\n`;
  md += `- ナレーション: ${s.narration}\n`;
  md += '- 吹き出し:\n';
  for (const [name, line] of s.bubbles) {
    md += `  - ${name}: ${line}\n`;
  }
  md += `- 解説: ${s.onsite}\n\n`;
});

fs.writeFileSync(outMd, md);
console.log(outJson);
console.log(outMd);
