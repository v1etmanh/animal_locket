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

console.log(`check ok: ${libs.map((l) => "v" + l.version).join(", ")}`);
