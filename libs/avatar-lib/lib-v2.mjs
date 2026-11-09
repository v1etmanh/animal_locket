// Thư viện avatar v2: origami "gấp đơn giản" (spec UI redesign §5.1, ADR-015).
// Cùng bộ khoá với v1: dùng lại bảng RAW 50 con và 10 màu gốc, chỉ vẽ lại từng mảnh.
// Kiểu vẽ: mảng giấy đa giác cạnh thẳng; một nếp dọc giữa mặt (nửa phải sẫm);
// tai và mảnh phụ là mảnh gấp đôi (nếp từ đỉnh xuống giữa đáy); mắt chấm mực.
import { RAW, palettes as base } from "./lib-v1.mjs";

const INK = "#2B2420";

// ---------- màu: sắc độ tính sẵn từ màu gốc ----------
const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const hex = (c) => "#" + c.map((v) => Math.round(v).toString(16).padStart(2, "0")).join("").toUpperCase();
const mix = (a, b, t) => hex(rgb(a).map((v, i) => v + (rgb(b)[i] - v) * t));
const dark = (c) => mix(c, "#1A1008", 0.25);
const light = (c) => mix(c, "#FFFFFF", 0.25);
const palettes = base.map((p) => ({
  ...p,
  furD: dark(p.fur),
  furL: light(p.fur),
  bellyD: dark(p.belly),
  accentD: dark(p.accent),
  accentL: light(p.accent),
}));

// ---------- hình học ----------
const f1 = (n) => +n.toFixed(1);
const pts = (ps) => ps.map(([x, y]) => `${f1(x)},${f1(y)}`).join(" ");
const poly = (ps, fill) => `<polygon points="${pts(ps)}" fill="${fill}"/>`;
const mirror = (ps) => ps.map(([x, y]) => [100 - x, y]);
// Phần đa giác nằm bên phải đường x = 50 (Sutherland–Hodgman với một cạnh cắt).
function rightHalf(ps) {
  const out = [];
  for (let i = 0; i < ps.length; i++) {
    const a = ps[i], b = ps[(i + 1) % ps.length];
    const ina = a[0] >= 50, inb = b[0] >= 50;
    if (ina) out.push(a);
    if (ina !== inb) {
      const t = (50 - a[0]) / (b[0] - a[0]);
      out.push([50, a[1] + (b[1] - a[1]) * t]);
    }
  }
  return out;
}
/** Mảng đối xứng gấp dọc giữa: cả mảng màu [c], nửa phải màu [d]. */
const fold = (ps, c, d) => poly(ps, c) + poly(rightHalf(ps), d);
/** Mảnh gấp đôi: nếp từ [tip] tới giữa cạnh đáy [b1]–[b2]. */
const flap = (tip, b1, b2, c1, c2) => {
  const mid = [(b1[0] + b2[0]) / 2, (b1[1] + b2[1]) / 2];
  return poly([tip, b1, mid], c1) + poly([tip, mid, b2], c2);
};
/** Một cặp mảnh hai bên: bên trái sáng hơn, bên phải tối hơn (ánh sáng từ trái). */
const pairFlap = (tip, b1, b2, [l1, l2], [r1, r2]) =>
  flap(tip, b1, b2, l1, l2) + flap(...mirror([tip, b1, b2]), r1, r2);
const pairPoly = (ps, l, r) => poly(ps, l) + poly(mirror(ps), r);
/** Mắt to chấm mực có đốm sáng (kiểu "mắt to" người dùng chọn), đặt trên một mảnh giấy màu bụng để đọc được cả trên lông tối. */
const eye = (x, y, r, back = "{{belly}}") => {
  const s = r + 2.6;
  return poly([[x, y - s], [x + s, y], [x, y + s], [x - s, y]], back) + `<circle cx="${x}" cy="${y}" r="${r}" fill="${INK}"/><circle cx="${f1(x + r * 0.35)}" cy="${f1(y - r * 0.38)}" r="${f1(r * 0.34)}" fill="#fff"/>`;
};
const dots = (y, r = 4.8, dx = 12) => eye(50 - dx, y, r) + eye(50 + dx, y, r, "{{bellyD}}");
const line = (d, color, w) => `<path d="${d}" stroke="${color}" stroke-width="${w}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
const hexagon = (cx, cy, r) => [0, 1, 2, 3, 4, 5].map((k) => [cx + r * Math.cos((Math.PI / 3) * k), cy + r * Math.sin((Math.PI / 3) * k)]);

const FUR = ["{{fur}}", "{{furD}}"];
const FURL = ["{{furL}}", "{{fur}}"];
const ACC = ["{{accent}}", "{{accentD}}"];
const ACCL = ["{{accentL}}", "{{accent}}"];

// ---------- mảnh: cùng tên với v1 ----------
const E = {
  none: "",
  tri: pairFlap([24, 10], [16, 46], [44, 32], FURL, FUR) + pairFlap([27, 21], [21, 41], [37, 34], ACCL, ACC),
  // Tai tròn của gấu/chuột: mảnh bốn cạnh đỉnh bằng, gấp chéo.
  rnd:
    pairPoly([[12, 42], [14, 24], [22, 18]], "{{furL}}", "{{furD}}") +
    pairPoly([[12, 42], [22, 18], [32, 18], [42, 32]], "{{fur}}", "{{furD}}") +
    pairPoly([[19, 36], [21, 26], [30, 23], [35, 32]], "{{accent}}", "{{accentD}}"),
  big:
    pairPoly([[4, 44], [8, 22], [26, 14], [38, 34]], "{{furL}}", "{{furD}}") +
    pairPoly([[10, 40], [13, 26], [25, 21], [32, 34]], "{{accent}}", "{{accentD}}"),
  long: pairFlap([32, 0], [26, 36], [44, 32], FURL, FUR) + pairFlap([34, 9], [31, 32], [40, 30], ACCL, ACC),
  flop: pairPoly([[24, 34], [8, 44], [10, 74], [24, 62]], "{{accent}}", "{{accentD}}"),
};
const H = {
  round: fold([[50, 26], [70, 31], [80, 46], [80, 64], [68, 80], [50, 85], [32, 80], [20, 64], [20, 46], [30, 31]], ...FUR),
  wide: fold([[50, 30], [74, 34], [87, 50], [83, 68], [66, 82], [50, 86], [34, 82], [17, 68], [13, 50], [26, 34]], ...FUR),
  tall: fold([[50, 21], [68, 27], [76, 44], [76, 67], [64, 83], [50, 89], [36, 83], [24, 67], [24, 44], [32, 27]], ...FUR),
};
const MU = {
  m: fold([[50, 59], [62, 64], [59, 76], [50, 80], [41, 76], [38, 64]], "{{belly}}", "{{bellyD}}"),
  w: fold([[50, 57], [68, 62], [66, 75], [50, 83], [34, 75], [32, 62]], "{{belly}}", "{{bellyD}}"),
  s: fold([[50, 61], [58, 65], [56, 73], [44, 73], [42, 65]], "{{belly}}", "{{bellyD}}"),
  f: fold([[50, 40], [68, 46], [73, 64], [63, 80], [50, 85], [37, 80], [27, 64], [32, 46]], "{{belly}}", "{{bellyD}}"),
  n: "",
};
const EY = {
  n: dots(55),
  big: poly(hexagon(38, 51, 10), "{{belly}}") + poly(hexagon(62, 51, 10), "{{bellyD}}") + dots(51, 5, 12),
  top:
    pairFlap([32, 16], [19, 42], [45, 42], FURL, FUR) + eye(32, 33, 4.4) + eye(68, 33, 4.4, "{{bellyD}}"),
};
const MOUTH = line("M50 66v3M45 71l5-2 5 2", INK, 1.4);
const NO = {
  none: "",
  dot: poly([[46, 61], [54, 61], [50, 66]], INK) + MOUTH,
  tri: poly([[46, 61], [54, 61], [50, 66]], "{{accentD}}") + MOUTH,
  pig:
    fold([[42, 62], [58, 62], [61, 68], [58, 74], [42, 74], [39, 68]], "{{furL}}", "{{fur}}") +
    poly([[45, 65.5], [47, 67.5], [45, 70.5], [43, 67.5]], "{{accentD}}") +
    poly([[55, 65.5], [57, 67.5], [55, 70.5], [53, 67.5]], "{{accentD}}"),
  beak: flap([50, 73], [43, 58], [57, 58], "#F2A33A", "#D9862A"),
  bill: fold([[36, 64], [64, 64], [66, 70], [58, 77], [42, 77], [34, 70]], "#F2A33A", "#D9862A"),
  smile: line("M34 66l16 6 16-6", INK, 2),
};
// X: [lớp, svg]  B = vẽ trước tai/đầu, M = trên đầu (trước mõm), F = trên cùng
const star = (n, cx, cy, r1, r2) =>
  Array.from({ length: n * 2 }, (_, k) => {
    const r = k % 2 ? r2 : r1, t = (Math.PI * k) / n - Math.PI / 2;
    return [cx + r * Math.cos(t), cy + r * Math.sin(t)];
  });
const X = {
  mane: ["B", fold(star(12, 50, 56, 46, 36), ...ACC)],
  shell: ["B", fold([[12, 74], [24, 52], [50, 44], [76, 52], [88, 74], [72, 94], [28, 94]], ...ACC)],
  tail: ["B", poly([[64, 94], [88, 84], [98, 56], [92, 30], [80, 36], [84, 60], [72, 80]], "{{accent}}") + poly([[92, 30], [98, 56], [88, 84], [84, 60]], "{{accentD}}")],
  antler: ["B", line("M34 34l-8-22m4 12l-10-2M66 34l8-22m-4 12l10-2", "#8A5A2B", 3.5)],
  horn: ["B", pairFlap([30, 10], [32, 34], [44, 28], ["#F1E9D8", "#D9D2C5"], ["#D9D2C5", "#BDB5A6"])],
  wool: ["B", fold([[14, 62], [12, 46], [20, 36], [22, 26], [34, 22], [42, 14], [50, 20], [58, 14], [66, 22], [78, 26], [80, 36], [88, 46], [86, 62]], "{{belly}}", "{{bellyD}}")],
  spikes: ["B", fold([[14, 60], [18, 30], [30, 40], [34, 16], [46, 34], [50, 10], [54, 34], [66, 16], [70, 40], [82, 30], [86, 60]], ...ACC)],
  wing: ["B", pairPoly([[22, 46], [2, 40], [6, 72], [14, 62], [22, 66]], "{{accent}}", "{{accentD}}")],
  uhorn: ["B", flap([50, 2], [44, 32], [56, 32], "#F2C14E", "#D9A43A")],
  knob: ["B", line("M38 28v-10M62 28v-10", "#8A5A2B", 3) + pairPoly([[38, 11], [42, 15], [38, 19], [34, 15]], "{{accent}}", "{{accentD}}")],
  mohawk: ["B", fold([[40, 30], [42, 12], [50, 6], [58, 12], [60, 30]], ...ACC)],
  tuft: ["B", fold([[44, 30], [46, 16], [50, 11], [54, 16], [56, 30]], ...ACC)],
  crest: ["B", fold([[40, 30], [36, 8], [46, 20], [50, 4], [54, 20], [64, 8], [60, 30]], ...ACC)],
  comb: ["B", poly([[36, 30], [42, 18], [48, 28]], "#E3453F") + poly([[44, 28], [50, 14], [56, 28]], "#E3453F") + poly([[52, 28], [58, 18], [64, 30]], "#C23630")],
  stripe: ["M", line("M50 27v11M40 29l3 9M60 29l-3 9M21 56h9M22 64l8-2M79 56h-9M78 64l-8-2", "{{accentD}}", 3)],
  spots: ["M", [[30, 42, 5], [68, 36, 6], [72, 62, 4], [52, 33, 3]].map(([x, y, r]) => poly([[x, y - r], [x + r, y], [x, y + r], [x - r, y]], "{{accent}}")).join("")],
  mask: ["M", fold([[18, 52], [34, 43], [50, 49], [66, 43], [82, 52], [67, 62], [50, 56], [33, 62]], ...ACC)],
  patch: ["M", pairPoly([[29, 56], [38, 45], [47, 56], [38, 66]], "{{accent}}", "{{accentD}}")],
  cheek: ["M", pairPoly([[25, 63], [31, 59], [33, 66]], "{{accentL}}", "{{accent}}")],
  whisk: ["F", line("M30 63l-14-3M30 67l-14 3M70 63l14-3M70 67l14 3", INK, 1.2)],
  tongue: ["F", poly([[47, 72], [53, 72], [53, 77], [50, 80], [47, 77]], "#E86A7A")],
  tusk: ["F", poly([[38, 70], [33, 79], [39, 86], [37, 78]], "#F1E9D8") + poly([[62, 70], [67, 79], [61, 86], [63, 78]], "#D9D2C5")],
  // Vòi sáng hơn đầu để tách khỏi mặt.
  trunk: ["F", fold([[43, 58], [57, 58], [57, 74], [64, 82], [58, 90], [48, 80], [43, 72]], ...FURL) + line("M44 66h12M45 74h11", "{{furD}}", 1.4)],
  teeth: ["F", '<rect x="46" y="70" width="8" height="8" fill="#fff" stroke="#2B2420"/><path d="M50 70v8" stroke="#2B2420"/>'],
  fang: ["F", poly([[44, 71], [48, 71], [46, 77]], "#fff") + poly([[52, 71], [56, 71], [54, 77]], "#fff")],
  beard: ["F", flap([50, 92], [43, 76], [57, 76], "{{belly}}", "{{bellyD}}")],
  rhorn: ["F", flap([50, 42], [42, 66], [58, 66], "#D9D2C5", "#BDB5A6")],
};

const TOP_FEATURES = new Set(["uhorn", "crest", "comb", "mohawk", "tuft", "knob"].map((x) => X[x]));
// Mũ đội lệch sang trái, nhỏ lại, chừa đỉnh đầu.
const TILTED_HATS = {
  party: "translate(-19 11) rotate(-24 50 30) scale(.8) translate(12.5 7.5)",
  crown: "translate(-18 12) rotate(-18 50 31) scale(.7) translate(21.4 13.3)",
};
// Mắt trên đỉnh: kính dời lên và giãn theo mắt; mũ nhỏ đặt giữa hai mắt.
const TOP_EYES = {
  glasses: "translate(50 33) scale(1.5 1) translate(-50 -55)",
  party: "translate(50 44) scale(.55) translate(-50 -30)",
  crown: "translate(50 42) scale(.55) translate(-50 -31)",
};

const animals = {};
for (const row of RAW.split("\n")) {
  const [k, name, e, h, m, no, ey, ex] = row.split("|");
  const xs = (ex || "").split(",").filter(Boolean).map((x) => {
    if (!X[x]) throw new Error(`Chi tiết không tồn tại: ${x} (${k})`);
    return X[x];
  });
  for (const [part, table] of [[e, E], [h, H], [m, MU], [ey, EY], [no, NO]]) {
    if (!(part in table)) throw new Error(`Mảnh không tồn tại: ${part} (${k})`);
  }
  const layer = (l) => xs.filter((x) => x[0] === l).map((x) => x[1]).join("");
  const svg = layer("B") + E[e] + H[h] + layer("M") + MU[m] + EY[ey] + NO[no] + layer("F");
  // Cách đặt phụ kiện riêng (transform SVG), để mũ không che đặc điểm trên đỉnh đầu
  // và kính/mũ khớp với mắt trên đỉnh (ếch).
  const fit = {
    ...(xs.some((x) => TOP_FEATURES.has(x)) ? TILTED_HATS : {}),
    ...(ey === "top" ? TOP_EYES : {}),
  };
  animals[k] = Object.keys(fit).length ? { name, svg, fit } : { name, svg };
}

const RED = ["#E35D6A", "#B93A47"];
const GOLD = ["#F2C14E", "#D9A43A"];
const accessories = {
  none: { name: "Không", svg: "" },
  glasses: {
    name: "Kính",
    svg:
      `<polygon points="${pts(hexagon(38, 55, 9))}" fill="none" stroke="${INK}" stroke-width="2"/>` +
      `<polygon points="${pts(hexagon(62, 55, 9))}" fill="none" stroke="${INK}" stroke-width="2"/>` +
      line("M47 55h6", INK, 2),
  },
  party: { name: "Mũ tiệc", svg: flap([50, 3], [38, 30], [62, 30], ...RED) + line("M42 22h16M45 14h10", "#fff", 2) + poly([[50, 0], [53, 3], [50, 6], [47, 3]], GOLD[0]) },
  crown: { name: "Vương miện", svg: fold([[34, 31], [34, 13], [42, 21], [50, 8], [58, 21], [66, 13], [66, 31]], ...GOLD) },
  bow: { name: "Nơ", svg: poly([[50, 88], [36, 80], [36, 96]], RED[0]) + poly([[50, 88], [64, 80], [64, 96]], RED[1]) + poly([[50, 84], [54, 88], [50, 92], [46, 88]], "#9E2F3B") },
  phones: {
    name: "Tai nghe",
    svg: line("M19 56l3-18 12-14 16-4 16 4 12 14 3 18", "#333", 4) + pairPoly([[14, 50], [25, 50], [25, 68], [14, 68]], ...RED),
  },
};

export const lib = {
  version: 2,
  // avatar_key = animal:palette:accessory (palette là chỉ số trong mảng palettes)
  keyFormat: "animal:palette:accessory",
  viewBox: "0 0 100 100",
  animals,
  palettes,
  accessories,
};
