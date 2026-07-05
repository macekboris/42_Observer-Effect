window.FRM = {};

FRM.endpoint = new URL("/res/turboencabulator/query.php", location.href).toString();

FRM.delayMs = 80;

FRM.sleep = ms => new Promise(r => setTimeout(r, ms));

FRM.hx = v => Number(v & 255).toString(16).padStart(2, "0");

FRM.chr = v => {
  v &= 255;
  return v >= 32 && v <= 126 ? String.fromCharCode(v) : ".";
};

FRM.q = async function(params) {
  const url = new URL(FRM.endpoint);

  for (const [k, v] of Object.entries(params)) {
    url.searchParams.set(k, v);
  }

  const res = await fetch(url.toString(), {
    credentials: "include",
    cache: "no-store"
  });

  const text = await res.text();

  try {
    return JSON.parse(text);
  } catch {
    return { rawText: text };
  }
};

FRM.obs = function(r) {
  if (Number.isInteger(r.observation)) return r.observation & 255;
  if (Number.isInteger(r.obs)) return r.obs & 255;
  if (Number.isInteger(r.value)) return r.value & 255;
  if (Number.isInteger(r.result)) return r.result & 255;
  throw new Error("No observation field: " + JSON.stringify(r));
};

FRM.grok = async function(x, y) {
  const r = await FRM.q({
    action: "grok",
    x,
    y
  });

  await FRM.sleep(FRM.delayMs);
  return FRM.obs(r);
};

FRM.munge = async function() {
  const r = await FRM.q({ action: "munge" });
  await FRM.sleep(FRM.delayMs);
  return r;
};

// Nastavi hidden observer register na raw(x,y)
FRM.prime = async function(x, y) {
  await FRM.grok(x, y);
  const second = await FRM.grok(x, y);
  return second;
};

// Relativna vrednost targeta proti anchorju:
// raw(target) XOR raw(anchor)
FRM.rel = async function(target, anchor) {
  await FRM.prime(anchor.x, anchor.y);
  const v = await FRM.grok(target.x, target.y);
  return v & 255;
};

// Relativni snapshot 16x16
FRM.snapshot = async function(anchor = { x: 9, y: 8 }) {
  const rel = [];

  for (let y = 0; y < 16; y++) {
    const row = [];

    for (let x = 0; x < 16; x++) {
      const v = await FRM.rel({ x, y }, anchor);
      row.push(v);
    }

    rel.push(row);
  }

  return {
    anchor,
    rel,
    takenAt: new Date().toISOString()
  };
};

FRM.matrixForAnchorValue = function(snapshot, anchorValue) {
  return snapshot.rel.map(row =>
    row.map(v => (v ^ anchorValue) & 255)
  );
};

FRM.reverse = arr => [...arr].reverse();

FRM.allLines = function(m) {
  const lines = [];

  // rows
  for (let y = 0; y < 16; y++) {
    lines.push({
      where: "row",
      y,
      bytes: m[y]
    });

    lines.push({
      where: "rowRev",
      y,
      bytes: FRM.reverse(m[y])
    });
  }

  // columns
  for (let x = 0; x < 16; x++) {
    const col = [];

    for (let y = 0; y < 16; y++) {
      col.push(m[y][x]);
    }

    lines.push({
      where: "col",
      x,
      bytes: col
    });

    lines.push({
      where: "colRev",
      x,
      bytes: FRM.reverse(col)
    });
  }

  // flat row-major
  const flatRow = m.flat();

  lines.push({
    where: "flatRowMajor",
    bytes: flatRow
  });

  lines.push({
    where: "flatRowMajorRev",
    bytes: FRM.reverse(flatRow)
  });

  // flat column-major
  const flatCol = [];

  for (let x = 0; x < 16; x++) {
    for (let y = 0; y < 16; y++) {
      flatCol.push(m[y][x]);
    }
  }

  lines.push({
    where: "flatColMajor",
    bytes: flatCol
  });

  lines.push({
    where: "flatColMajorRev",
    bytes: FRM.reverse(flatCol)
  });

  // diagonals down-right
  for (let sx = 0; sx < 16; sx++) {
    const bytes = [];
    let x = sx;
    let y = 0;

    while (x < 16 && y < 16) {
      bytes.push(m[y][x]);
      x++;
      y++;
    }

    if (bytes.length >= 4) {
      lines.push({
        where: "diagDR",
        startX: sx,
        startY: 0,
        bytes
      });

      lines.push({
        where: "diagDRRev",
        startX: sx,
        startY: 0,
        bytes: FRM.reverse(bytes)
      });
    }
  }

  for (let sy = 1; sy < 16; sy++) {
    const bytes = [];
    let x = 0;
    let y = sy;

    while (x < 16 && y < 16) {
      bytes.push(m[y][x]);
      x++;
      y++;
    }

    if (bytes.length >= 4) {
      lines.push({
        where: "diagDR",
        startX: 0,
        startY: sy,
        bytes
      });

      lines.push({
        where: "diagDRRev",
        startX: 0,
        startY: sy,
        bytes: FRM.reverse(bytes)
      });
    }
  }

  // diagonals down-left
  for (let sx = 0; sx < 16; sx++) {
    const bytes = [];
    let x = sx;
    let y = 0;

    while (x >= 0 && y < 16) {
      bytes.push(m[y][x]);
      x--;
      y++;
    }

    if (bytes.length >= 4) {
      lines.push({
        where: "diagDL",
        startX: sx,
        startY: 0,
        bytes
      });

      lines.push({
        where: "diagDLRev",
        startX: sx,
        startY: 0,
        bytes: FRM.reverse(bytes)
      });
    }
  }

  for (let sy = 1; sy < 16; sy++) {
    const bytes = [];
    let x = 15;
    let y = sy;

    while (x >= 0 && y < 16) {
      bytes.push(m[y][x]);
      x--;
      y++;
    }

    if (bytes.length >= 4) {
      lines.push({
        where: "diagDL",
        startX: 15,
        startY: sy,
        bytes
      });

      lines.push({
        where: "diagDLRev",
        startX: 15,
        startY: sy,
        bytes: FRM.reverse(bytes)
      });
    }
  }

  return lines;
};

FRM.printableRuns = function(bytes, minLen = 4) {
  const runs = [];
  let cur = "";
  let start = 0;

  for (let i = 0; i < bytes.length; i++) {
    const c = FRM.chr(bytes[i]);

    if (c !== ".") {
      if (!cur) start = i;
      cur += c;
    } else {
      if (cur.length >= minLen) {
        runs.push({
          start,
          end: i - 1,
          text: cur
        });
      }
      cur = "";
    }
  }

  if (cur.length >= minLen) {
    runs.push({
      start,
      end: bytes.length - 1,
      text: cur
    });
  }

  return runs;
};

FRM.adjectives = [
  "bad",
  "good",
  "rotten",
  "delicious",
  "fresh",
  "ripe",
  "unripe",
  "sweet",
  "sour",
  "bitter",
  "juicy",
  "spoiled",
  "moldy",
  "mouldy",
  "tasty",
  "nasty",
  "nice",
  "gross",
  "soft",
  "hard",
  "old",
  "new"
];

FRM.fruits = [
  "apple",
  "apples",
  "orange",
  "oranges",
  "pine",
  "pineapple",
  "pineapples",
  "banana",
  "bananas",
  "pear",
  "pears",
  "peach",
  "peaches",
  "plum",
  "plums",
  "grape",
  "grapes",
  "melon",
  "melons",
  "lemon",
  "lemons",
  "lime",
  "limes",
  "mango",
  "mangos",
  "mangoes",
  "berry",
  "berries",
  "strawberry",
  "strawberries",
  "blueberry",
  "blueberries",
  "raspberry",
  "raspberries",
  "cherry",
  "cherries",
  "kiwi",
  "kiwis",
  "fruit",
  "fruits",
  "ananas"
];

FRM.buildNeedles = function() {
  const set = new Set();

  for (const w of [...FRM.adjectives, ...FRM.fruits]) {
    set.add(w.toLowerCase());
  }

  for (const adj of FRM.adjectives) {
    for (const fruit of FRM.fruits) {
      const a = adj.toLowerCase();
      const f = fruit.toLowerCase();

      set.add(a + f);
      set.add(a + " " + f);
      set.add(a + "_" + f);
      set.add(a + "-" + f);
    }
  }

  [
    "badapples",
    "badapple",
    "goodapples",
    "goodapple",
    "goodoranges",
    "goodorange",
    "badoranges",
    "badorange",
    "deliciouspine",
    "deliciouspineapples",
    "deliciouspineapple",
    "rottenoranges",
    "rottenorange",
    "623rottenoranges",
    "858deliciouspine"
  ].forEach(x => set.add(x.toLowerCase()));

  return [...set].sort((a, b) => b.length - a.length);
};

FRM.needles = FRM.buildNeedles();

FRM.findMatches = function(text) {
  const lower = text.toLowerCase();
  return FRM.needles.filter(n => lower.includes(n));
};

FRM.score = function(text, matches) {
  let score = 0;

  for (const m of matches) {
    score += 100 + m.length * 5;
  }

  if (/^[0-9]{1,4}[a-z]{6,}$/i.test(text)) score += 80;
  if (/^[a-z]{6,}$/i.test(text)) score += 50;

  if (/(bad|good|rotten|delicious|fresh|ripe|sweet|sour|juicy|spoiled|moldy|mouldy|tasty|nasty)(apple|apples|orange|oranges|pine|pineapple|pineapples|banana|bananas|pear|pears|grape|grapes|melon|melons|lemon|lemons|mango|berry|berries|cherry|cherries|kiwi|kiwis)/i.test(text)) {
    score += 300;
  }

  return score;
};

FRM.scanSnapshot = function(snapshot, minLen = 4) {
  const hits = [];

  for (let anchorValue = 0; anchorValue < 256; anchorValue++) {
    const m = FRM.matrixForAnchorValue(snapshot, anchorValue);
    const lines = FRM.allLines(m);

    for (const line of lines) {
      const fullText = line.bytes.map(FRM.chr).join("");
      const fullMatches = FRM.findMatches(fullText);

      if (fullMatches.length) {
        hits.push({
          anchorValue,
          anchorHex: FRM.hx(anchorValue),
          where: line.where,
          x: line.x,
          y: line.y,
          startX: line.startX,
          startY: line.startY,
          start: 0,
          end: line.bytes.length - 1,
          text: fullText,
          matches: fullMatches.slice(0, 10),
          score: FRM.score(fullText, fullMatches)
        });
      }

      for (const run of FRM.printableRuns(line.bytes, minLen)) {
        const matches = FRM.findMatches(run.text);

        if (matches.length) {
          hits.push({
            anchorValue,
            anchorHex: FRM.hx(anchorValue),
            where: line.where + "/run",
            x: line.x,
            y: line.y,
            startX: line.startX,
            startY: line.startY,
            start: run.start,
            end: run.end,
            text: run.text,
            matches: matches.slice(0, 10),
            score: FRM.score(run.text, matches)
          });
        }
      }
    }
  }

  hits.sort((a, b) =>
    b.score - a.score ||
    b.text.length - a.text.length ||
    a.anchorValue - b.anchorValue
  );

  return hits;
};

// To je isti postopek kot tisti, ki je za (7,3) dal 623rottenoranges.
FRM.scanPrimer = async function(primer, opts = {}) {
  const anchor = opts.anchor || { x: 9, y: 8 };
  const minLen = opts.minLen || 4;

  console.log("========================================");
  console.log("Primer:", primer, "anchor:", anchor);

  console.log("Priming...");
  const primeSecond = await FRM.prime(primer.x, primer.y);
  console.log("prime second obs should be 00-ish:", FRM.hx(primeSecond), primeSecond);

  console.log("Munge...");
  const mungeResult = await FRM.munge();
  console.log("munge:", mungeResult);

  console.log("Snapshot...");
  const snap = await FRM.snapshot(anchor);

  console.log("Scan fruit clues...");
  const hits = FRM.scanSnapshot(snap, minLen);

  const result = {
    primer,
    anchor,
    mungeResult,
    snap,
    hits
  };

  if (!window.FRM_RESULTS) window.FRM_RESULTS = [];
  window.FRM_RESULTS.push(result);
  window.LAST_FRM = result;

  console.log("Top hits for primer", primer);
  console.table(hits.slice(0, opts.top || 30).map(h => ({
    anchorHex: h.anchorHex,
    where: h.where,
    x: h.x,
    y: h.y,
    start: h.start,
    end: h.end,
    text: h.text,
    matches: h.matches.join(","),
    score: h.score
  })));

  return result;
};

FRM.scanPrimers = async function(primers, opts = {}) {
  const out = [];

  for (let i = 0; i < primers.length; i++) {
    const p = primers[i];

    console.log("###", i + 1, "/", primers.length, p);

    const r = await FRM.scanPrimer(p, opts);
    out.push(r);

    await FRM.sleep(opts.betweenMs || 250);
  }

  window.FRM_BATCH = out;

  const summary = [];

  for (const r of out) {
    for (const h of r.hits.slice(0, opts.summaryPerPrimer || 5)) {
      summary.push({
        primer: `(${r.primer.x.toString(16)},${r.primer.y.toString(16)})`,
        anchorHex: h.anchorHex,
        where: h.where,
        x: h.x,
        y: h.y,
        text: h.text,
        matches: h.matches.join(","),
        score: h.score
      });
    }
  }

  console.log("=== Batch summary ===");
  console.table(summary);

  window.FRM_SUMMARY = summary;
  return out;
};

// Smiselni začetni set: okoli stolpcev 7/8, ker sta bila ključna.
FRM.defaultPrimers = function() {
  const primers = [];

  for (let y = 0; y < 16; y++) {
    primers.push({ x: 7, y });
    primers.push({ x: 8, y });
  }

  return primers;
};

// Manjši, varnejši set.
FRM.smallPrimers = function() {
  return [
    { x: 7, y: 0 },
    { x: 7, y: 1 },
    { x: 7, y: 2 },
    { x: 7, y: 3 },
    { x: 7, y: 4 },
    { x: 8, y: 0 },
    { x: 8, y: 1 },
    { x: 8, y: 2 },
    { x: 8, y: 3 },
    { x: 8, y: 4 },
    { x: 9, y: 8 }
  ];
};

// Ekstremno: vsi pari 0..15.
// Uporabi pazljivo, ker naredi veliko requestov in mutira stanje.
FRM.allPrimers = function() {
  const primers = [];

  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      primers.push({ x, y });
    }
  }

  return primers;
};

FRM.uniqueHitTexts = function(results = window.FRM_RESULTS || []) {
  const map = new Map();

  for (const r of results) {
    for (const h of r.hits) {
      const key = h.text.toLowerCase();

      if (!map.has(key)) {
        map.set(key, {
          text: h.text,
          count: 0,
          bestScore: h.score,
          examples: []
        });
      }

      const item = map.get(key);
      item.count++;
      item.bestScore = Math.max(item.bestScore, h.score);

      if (item.examples.length < 8) {
        item.examples.push({
          primer: `(${r.primer.x.toString(16)},${r.primer.y.toString(16)})`,
          anchorHex: h.anchorHex,
          where: h.where,
          x: h.x,
          y: h.y,
          text: h.text,
          matches: h.matches
        });
      }
    }
  }

  const out = [...map.values()].sort((a, b) =>
    b.bestScore - a.bestScore ||
    b.count - a.count ||
    b.text.length - a.text.length
  );

  console.table(out.slice(0, 100).map(x => ({
    text: x.text,
    count: x.count,
    score: x.bestScore
  })));

  window.FRM_UNIQUE = out;
  return out;
};

console.log("FRM loaded.");
console.log("Najprej priporočam majhen scan:");
console.log("  await FRM.scanPrimers(FRM.smallPrimers(), {top:20})");
console.log("Potem širše:");
console.log("  await FRM.scanPrimers(FRM.defaultPrimers(), {top:10, betweenMs:300})");
console.log("Unikatni najdeni fruit nizi:");
console.log("  FRM.uniqueHitTexts()");
