// Sinh avatar-lib.vN.json cho mọi phiên bản (lib-v1.mjs, lib-v2.mjs …).
// Chạy: node libs/avatar-lib/build-lib.mjs [--preview <file.html>]   Tự kiểm: node libs/avatar-lib/check.mjs
// QUY TẮC (docs/19 §3.2): phiên bản đã phát hành sinh lại phải trùng từng byte;
// phiên bản mới được vẽ lại khoá cũ nhưng phải giữ nguyên bộ khoá (con vật × bảng màu × phụ kiện).
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { lib as v1 } from "./lib-v1.mjs";
import { lib as v2 } from "./lib-v2.mjs";

export const versions = [v1, v2];

/// Hàm vẽ chuẩn. Client (Dart) phải cho ra đúng chuỗi này; mẫu đối chiếu ghi vào test fixture.
/// Mọi chỗ trống {{tên}} lấy màu cùng tên trong bảng màu của khoá.
export function render(l, key) {
  const [animal, palette, accessory] = key.split(":");
  const p = l.palettes[Number(palette)];
  const fill = (svg) => svg.replace(/\{\{(\w+)\}\}/g, (m, name) => p[name] ?? m);
  return `<svg viewBox="${l.viewBox}" xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100" fill="${p.bg}"/>${fill(l.animals[animal].svg)}${fill(l.accessories[accessory].svg)}</svg>`;
}

export function keySet(l) {
  const keys = new Set();
  for (const a of Object.keys(l.animals))
    for (let p = 0; p < l.palettes.length; p++)
      for (const x of Object.keys(l.accessories)) keys.add(`${a}:${p}:${x}`);
  return keys;
}

const sampleKeys = ["fox:0:none", "cat:3:glasses", "elephant:9:phones", "lion:4:crown", "frog:5:bow", "seal:1:party"];

function build() {
  const here = dirname(fileURLToPath(import.meta.url));
  const root = join(here, "..", "..");
  const out = process.env.AVATAR_OUT; // check.mjs sinh vào thư mục tạm
  const write = (path, text) => {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, text);
  };
  const latest = versions.at(-1).version;
  for (const lib of versions) {
    const name = `avatar-lib.v${lib.version}.json`;
    const json = JSON.stringify(lib, null, 1) + "\n";
    const samples = JSON.stringify(Object.fromEntries(sampleKeys.map((k) => [k, render(lib, k)])), null, 1) + "\n";
    const samplesName = `avatar-lib.v${lib.version}.samples.json`;
    if (out) {
      write(join(out, name), json);
      write(join(out, samplesName), samples);
    } else {
      write(join(here, name), json);
      if (lib.version === latest) write(join(root, "mobile", "assets", "avatar", name), json);
      write(join(root, "mobile", "test", "fixtures", samplesName), samples);
    }
    const n = (o) => Object.keys(o).length;
    console.log(`avatar-lib v${lib.version}: ${n(lib.animals)} con vật × ${lib.palettes.length} màu × ${n(lib.accessories)} phụ kiện = ${keySet(lib).size} avatar`);
  }
  const i = process.argv.indexOf("--preview");
  if (i > 0) {
    write(process.argv[i + 1], preview(versions.at(-1)));
    console.log(`xem trước: ${process.argv[i + 1]}`);
  }
}

/** Trang duyệt hình (không commit): cả 50 con, 10 bảng màu, 6 phụ kiện, cỡ 40pt. */
function preview(lib) {
  const pic = (key, size) =>
    `<div title="${key}" style="width:${size}px;height:${size}px;border-radius:50%;overflow:hidden;display:inline-block;margin:3px">${render(lib, key).replace("<svg ", `<svg width="${size}" height="${size}" `)}</div>`;
  const animals = Object.keys(lib.animals);
  const label = (k) => `<div style="display:inline-block;text-align:center;font:11px sans-serif">${pic(`${k}:0:none`, 88)}<br>${lib.animals[k].name}</div>`;
  const row = (title, items) => `<h3 style="font:600 15px sans-serif;margin:18px 0 6px">${title}</h3><div>${items.join("")}</div>`;
  return (
    `<!DOCTYPE html><meta charset="utf-8"><title>avatar-lib v${lib.version}</title><body style="background:#FBF3E8;margin:20px">` +
    row(`50 con vật · bảng màu 0`, animals.map(label)) +
    row(`Cỡ 40pt`, animals.map((k) => pic(`${k}:0:none`, 40))) +
    ["fox", "panda", "owl", "frog", "elephant", "lion"].map((a) => row(`10 bảng màu · ${lib.animals[a].name}`, lib.palettes.map((_, p) => pic(`${a}:${p}:none`, 72)))).join("") +
    ["cat", "rabbit", "duck"].map((a) => row(`6 phụ kiện · ${lib.animals[a].name}`, Object.keys(lib.accessories).map((x) => pic(`${a}:2:${x}`, 88)))).join("") +
    `</body>`
  );
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) build();
