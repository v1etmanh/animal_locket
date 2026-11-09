// Tự kiểm thư viện avatar: node libs/avatar-lib/check.mjs
// Sinh mọi phiên bản vào thư mục tạm rồi kiểm các quy tắc ở docs/19 §3.2.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");
const out = mkdtempSync(join(tmpdir(), "avatar-lib-"));
execFileSync(process.execPath, [join(here, "build-lib.mjs")], {
  env: { ...process.env, AVATAR_OUT: out },
  stdio: "inherit",
});
const { render, keySet } = await import("./build-lib.mjs?check");
const committed = (path) => execFileSync("git", ["show", `HEAD:${path}`], { cwd: root }).toString();
const built = (name) => readFileSync(join(out, name), "utf8");

// v1 đã phát hành: sinh lại phải trùng từng byte với bản trong git.
assert.equal(built("avatar-lib.v1.json"), committed("libs/avatar-lib/avatar-lib.v1.json"), "v1 json đổi");
assert.equal(
  built("avatar-lib.v1.samples.json"),
  committed("mobile/test/fixtures/avatar-lib.v1.samples.json"),
  "v1 samples đổi",
);

const libs = readdirSync(out)
  .filter((f) => /^avatar-lib\.v\d+\.json$/.test(f))
  .map((f) => JSON.parse(built(f)));
const v1 = libs.find((l) => l.version === 1);
const keysV1 = keySet(v1);
assert.equal(keysV1.size, 3000);
for (const lib of libs) {
  assert.deepEqual(keySet(lib), keysV1, `bộ khoá v${lib.version} khác v1`);
  for (const key of keysV1) {
    assert.ok(!render(lib, key).includes("{{"), `v${lib.version} ${key} còn chỗ trống màu`);
  }
}
// v2 origami "gấp đơn giản" (spec §5.1).
const v2 = libs.find((l) => l.version === 2);
assert.ok(v2, "chưa có v2");
const hex = /^#[0-9A-F]{6}$/i;
v2.palettes.forEach((p, i) => {
  for (const base of ["fur", "belly", "accent", "bg"]) assert.equal(p[base], v1.palettes[i][base], `bảng ${i}.${base}`);
  for (const shade of ["furD", "furL", "bellyD", "accentD", "accentL"]) assert.match(p[shade] ?? "", hex, `bảng ${i}.${shade}`);
});
for (const [k, a] of Object.entries(v2.animals)) {
  assert.equal(a.name, v1.animals[k].name, `tên ${k}`);
  // Mảng giấy cạnh thẳng: hình tròn chỉ dùng cho chấm nhỏ (mắt, đốm).
  for (const m of a.svg.matchAll(/<circle[^>]*\br="([\d.]+)"/g)) assert.ok(Number(m[1]) <= 6, `${k}: circle r=${m[1]}`);
  assert.ok(!a.svg.includes("<ellipse"), `${k}: ellipse`);
}
for (const [k, x] of Object.entries(v2.accessories)) assert.ok(!x.svg.includes("<ellipse"), `phụ kiện ${k}: ellipse`);

// Mắt đọc được trên mọi bảng màu: mỗi chấm mực nằm trên một mảnh giấy màu bụng.
const INK = "#2B2420";
const lum = (h) => {
  const c = [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
};
const contrast = (a, b) => {
  const [x, y] = [lum(a), lum(b)].sort((m, n) => n - m);
  return (x + 0.05) / (y + 0.05);
};
v2.palettes.forEach((p, i) => {
  for (const bg of ["belly", "bellyD"]) assert.ok(contrast(INK, p[bg]) >= 4.5, `bảng ${i}: mắt trên ${bg} ${contrast(INK, p[bg]).toFixed(2)}`);
});
for (const [k, a] of Object.entries(v2.animals)) {
  const els = [...a.svg.matchAll(/<(polygon|circle|path|rect)\b[^>]*\/>/g)].map((m) => m[0]);
  els.forEach((el, i) => {
    if (!el.startsWith("<circle") || !el.includes(`fill="${INK}"`) || Number(/r="([\d.]+)"/.exec(el)[1]) < 3) return;
    assert.match(els[i - 1] ?? "", /^<polygon[^>]*fill="\{\{belly(D)?\}\}"/, `${k}: mắt không có mảnh nền`);
    // Kiểu "mắt to" người dùng chọn: mắt ≥ 4.4 và có đốm sáng trắng ngay sau.
    assert.ok(Number(/r="([\d.]+)"/.exec(el)[1]) >= 4.4, `${k}: mắt nhỏ`);
    assert.match(els[i + 1] ?? "", /^<circle[^>]*fill="#fff"/, `${k}: mắt thiếu đốm sáng`);
  });
}

// Phụ kiện không che đặc điểm trên đỉnh đầu, và khớp với mắt trên đỉnh (ếch):
// những con này phải có cách đặt riêng (`fit`) cho các phụ kiện liên quan.
const { RAW } = await import("./lib-v1.mjs");
const TOP = ["uhorn", "crest", "comb", "mohawk", "tuft", "knob"];
for (const row of RAW.split("\n")) {
  const [k, , , , , , eyes, extra = ""] = row.split("|");
  const needs = [
    ...(extra.split(",").some((x) => TOP.includes(x)) ? ["party", "crown"] : []),
    ...(eyes === "top" ? ["glasses", "party", "crown"] : []),
  ];
  for (const acc of needs) assert.ok(v2.animals[k].fit?.[acc], `${k} cần fit cho ${acc}`);
}
// Hàm vẽ áp cách đặt riêng: phụ kiện được bọc trong <g transform="fit">.
for (const key of ["unicorn:2:party", "chicken:2:crown", "frog:2:glasses"]) {
  const [a, , x] = key.split(":");
  assert.ok(render(v2, key).includes(`<g transform="${v2.animals[a].fit[x]}">`), `${key}: chưa áp fit`);
}
assert.ok(!render(v2, "horse:2:glasses").includes("<g "), "không có fit thì không bọc");

console.log(`check ok: ${libs.map((l) => "v" + l.version).join(", ")}`);
