const APP_DATA = window.APP_DATA || {};
const slides = APP_DATA.slides || [];
const readerTexts = APP_DATA.readerTexts || [];
const characters = APP_DATA.characters || [];

const slideImages = slides.map((_, i) => `./slides_v1/slide_${String(i + 1).padStart(2, "0")}.jpg`);

const slideRoot = document.getElementById("slide");
const template = document.getElementById("slideTemplate");

let current = 0; // 0=cover, 1=cast, 2=toc, 3..=content
let readerTab = "manga";
let readerFontSize = 0.94;
const READER_FONT_MIN = 0.82;
const READER_FONT_MAX = 1.14;
const READER_FONT_STEP = 0.06;
let currentUtterance = null;
let touchStartX = 0;

function isInteractiveTarget(target) {
  if (!(target instanceof Element)) return false;
  return Boolean(target.closest("button, a, input, textarea, select, label, [role='button']"));
}

function splitIntoParagraphs(text) {
  const normalized = String(text ?? "").replace(/\r\n/g, "\n").trim();
  if (!normalized) return [];

  const byBlankLines = normalized.split(/\n{2,}/).map((s) => s.trim()).filter(Boolean);
  if (byBlankLines.length > 1) return byBlankLines;

  // Fallback: make readable chunks when source has no paragraph breaks.
  const sentences = normalized.match(/[^。！？!?]+[。！？!?]?/g)?.map((s) => s.trim()).filter(Boolean) ?? [normalized];
  const chunks = [];
  let bucket = [];
  sentences.forEach((s, idx) => {
    bucket.push(s);
    if (bucket.length >= 3 || idx === sentences.length - 1) {
      chunks.push(bucket.join(""));
      bucket = [];
    }
  });
  return chunks;
}

const totalPages = slides.length + 3; // 0: cover, 1: cast, 2: toc, 3..: content

function stopSpeaking() {
  if (!("speechSynthesis" in window)) return;
  window.speechSynthesis.cancel();
  currentUtterance = null;
}

function renderCoverPage() {
  const wrap = document.createElement("section");
  wrap.className = "cover-page";
  wrap.addEventListener("click", (event) => {
    event.stopPropagation();
    goTo(1);
  });

  const paper = document.createElement("section");
  paper.className = "page-paper";

  const heroWrap = document.createElement("section");
  heroWrap.className = "cover-hero-wrap";

  const hero = document.createElement("img");
  hero.className = "cover-hero";
  hero.src = "./cover_art/cover_art_v10.jpg";
  hero.alt = "登場人物紹介";
  hero.loading = "eager";

  const titleBlock = document.createElement("section");
  titleBlock.className = "cover-title-block";
  const titleMain = document.createElement("h1");
  titleMain.className = "cover-title-main";
  titleMain.textContent = "AI覇権バトル2025";
  titleBlock.append(titleMain);
  heroWrap.append(hero, titleBlock);
  paper.append(heroWrap);
  wrap.appendChild(paper);
  slideRoot.replaceChildren(wrap);
}

function renderCastPage() {
  const wrap = document.createElement("section");
  wrap.className = "toc-page";

  const paper = document.createElement("section");
  paper.className = "page-paper page-paper-toc";

  const title = document.createElement("h1");
  title.textContent = "キャラクター紹介";
  paper.appendChild(title);

  const cast = document.createElement("section");
  cast.className = "toc-cast";
  characters.forEach((ch) => {
    const card = document.createElement("article");
    card.className = "toc-cast-card";
    const img = document.createElement("img");
    img.src = ch.image;
    img.alt = ch.name;
    img.loading = "lazy";
    const meta = document.createElement("div");
    meta.className = "toc-cast-meta";
    const label = document.createElement("h3");
    label.textContent = ch.name;
    const desc = document.createElement("p");
    desc.textContent = ch.desc;
    meta.append(label, desc);
    card.append(img, meta);
    cast.appendChild(card);
  });
  paper.appendChild(cast);

  const hint = document.createElement("p");
  hint.className = "cast-hint";
  hint.textContent = "次へめくると目次";
  paper.appendChild(hint);

  wrap.appendChild(paper);

  slideRoot.replaceChildren(wrap);
}

function renderTocPage() {
  const wrap = document.createElement("section");
  wrap.className = "toc-page toc-page-list";

  const paper = document.createElement("section");
  paper.className = "page-paper page-paper-toc";

  const title = document.createElement("h1");
  title.textContent = "目次";
  paper.append(title);

  const listWrap = document.createElement("section");
  listWrap.className = "toc-list-wrap";

  const list = document.createElement("ol");
  list.className = "toc-list";
  slides.forEach((slide, i) => {
    const li = document.createElement("li");
    const text = document.createElement("span");
    text.className = "toc-item-title";
    text.textContent = `${i + 1}. ${slide.title}`;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "btn btn-ghost toc-jump";
    button.textContent = "→";
    button.setAttribute("aria-label", `${i + 1}ページへ移動`);
    button.addEventListener("click", () => goTo(i + 3));
    li.append(text, button);
    list.appendChild(li);
  });
  listWrap.append(list);
  paper.appendChild(listWrap);

  wrap.appendChild(paper);

  slideRoot.replaceChildren(wrap);
}

function renderContent(pageNumber) {
  const index = pageNumber - 3;
  const data = slides[index];
  const node = template.content.firstElementChild.cloneNode(true);

  const readerEra = node.querySelector(".reader-era");
  const readerImpact = node.querySelector(".reader-impact");
  const readerTitle = node.querySelector(".reader-title");
  const readerPageCounter = node.querySelector(".reader-page-counter");
  readerEra.textContent = data.era;
  readerImpact.textContent = String(data.impact).includes("★") ? data.impact : "";
  readerTitle.textContent = `${index + 1}. ${data.title}`;
  readerPageCounter.textContent = `${index + 1}/${slides.length}`;
  readerPageCounter.title = "目次へ";
  readerPageCounter.addEventListener("click", () => goTo(2));

  const visual = node.querySelector(".slide-visual");
  const image = node.querySelector(".slide-image");
  const imagePath = slideImages[index];
  if (imagePath) {
    image.src = imagePath;
    image.alt = `${index + 1}. ${data.title}`;
    image.onerror = () => {
      visual.hidden = true;
    };
    visual.hidden = false;
  } else {
    visual.hidden = true;
  }
  const readerTextEl = node.querySelector(".reader-text");
  const textFrameEl = node.querySelector(".text-frame");
  const readerNotesWrap = node.querySelector(".reader-notes");
  const readerNoteList = node.querySelector(".reader-note-list");
  const tabButtons = node.querySelectorAll(".reader-tab");
  const fontDecButton = node.querySelector(".reader-font-dec");
  const fontIncButton = node.querySelector(".reader-font-inc");
  const fontButtons = node.querySelectorAll(".reader-font");
  const speakButton = node.querySelector(".reader-speak");
  const currentEntry = readerTexts[index] ?? { novel: "", deepdive: "", notes: [] };
  const currentText = readerTab === "manga" ? "" : (currentEntry?.[readerTab] ?? "");
  readerTextEl.replaceChildren();
  if (currentText) {
    splitIntoParagraphs(currentText).forEach((paragraph) => {
      const p = document.createElement("p");
      p.className = "reader-paragraph";
      p.textContent = paragraph;
      readerTextEl.appendChild(p);
    });
  }
  const showNotes = readerTab === "deepdive" && Array.isArray(currentEntry.notes) && currentEntry.notes.length > 0;
  const showManga = readerTab === "manga" && Boolean(imagePath);
  const showReaderFontControls = readerTab !== "manga";
  readerNotesWrap.hidden = !showNotes;
  textFrameEl.hidden = showManga;
  visual.hidden = !showManga || !Boolean(imagePath);
  speakButton.disabled = showManga;
  speakButton.style.opacity = showManga ? "0.45" : "1";
  textFrameEl.style.setProperty("--reader-font-size", `${readerFontSize}rem`);
  fontButtons.forEach((btn) => {
    btn.hidden = !showReaderFontControls;
  });
  fontDecButton.disabled = !showReaderFontControls || readerFontSize <= READER_FONT_MIN;
  fontIncButton.disabled = !showReaderFontControls || readerFontSize >= READER_FONT_MAX;
  readerNoteList.replaceChildren();
  if (showNotes) {
    currentEntry.notes.forEach((note) => {
      const li = document.createElement("li");
      li.textContent = note;
      readerNoteList.appendChild(li);
    });
  }
  tabButtons.forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tab === readerTab);
    btn.addEventListener("click", () => {
      readerTab = btn.dataset.tab;
      stopSpeaking();
      renderContent(current);
    });
  });

  fontDecButton.addEventListener("click", () => {
    readerFontSize = Math.max(READER_FONT_MIN, Number((readerFontSize - READER_FONT_STEP).toFixed(2)));
    renderContent(current);
  });

  fontIncButton.addEventListener("click", () => {
    readerFontSize = Math.min(READER_FONT_MAX, Number((readerFontSize + READER_FONT_STEP).toFixed(2)));
    renderContent(current);
  });

  speakButton.addEventListener("click", () => {
    if (readerTab === "manga") return;
    if (!("speechSynthesis" in window)) {
      alert("このブラウザは読み上げに対応していません。");
      return;
    }
    if (currentUtterance) {
      stopSpeaking();
      speakButton.textContent = "🔊";
      return;
    }
    const utter = new SpeechSynthesisUtterance(currentText);
    utter.lang = "ja-JP";
    utter.rate = 1.0;
    utter.onend = () => {
      currentUtterance = null;
      speakButton.textContent = "🔊";
    };
    currentUtterance = utter;
    speakButton.textContent = "■";
    window.speechSynthesis.speak(utter);
  });

  slideRoot.replaceChildren(node);
}

function goTo(index) {
  stopSpeaking();
  current = Math.max(0, Math.min(totalPages - 1, index));
  if (current === 0) {
    renderCoverPage();
  } else if (current === 1) {
    renderCastPage();
  } else if (current === 2) {
    renderTocPage();
  } else {
    renderContent(current);
  }
}

window.addEventListener("keydown", (event) => {
  if (event.key === "ArrowRight") {
    goTo(current + 1);
  }
  if (event.key === "ArrowLeft") {
    goTo(current - 1);
  }
});

window.addEventListener("touchstart", (event) => {
  touchStartX = event.changedTouches[0]?.clientX ?? 0;
});

window.addEventListener("touchend", (event) => {
  const endX = event.changedTouches[0]?.clientX ?? 0;
  const dx = endX - touchStartX;
  if (Math.abs(dx) < 50) return;
  if (dx < 0) goTo(current + 1);
  if (dx > 0) goTo(current - 1);
});

slideRoot.addEventListener("click", (event) => {
  if (current < 1) return; // start from character page
  if (isInteractiveTarget(event.target)) return;

  const rect = slideRoot.getBoundingClientRect();
  const tapX = event.clientX - rect.left;
  const half = rect.width / 2;
  if (tapX < half) {
    goTo(current - 1);
  } else {
    goTo(current + 1);
  }
});

goTo(0);
