// Bangun font ikon GymIcons dari SVG IconScout di design/iconscout/icons.
// Kode glyph = 0xE900 + urutan nama berkas; hasil pemetaannya ditulis ke
// berkas .json di samping .ttf. Cara pakai ada di design/iconscout/SOURCES.md.
const SVGIcons2SVGFontStream = require('svgicons2svgfont');
const svg2ttf = require('svg2ttf');
const fs = require('fs');
const path = require('path');
const src = process.argv[2], out = process.argv[3];
const names = fs.readdirSync(src).filter((f) => f.endsWith('.svg')).sort();
const stream = new SVGIcons2SVGFontStream({ fontName: 'GymIcons', normalize: true, fontHeight: 1000, descent: 0, log: () => {} });
let svgFont = '';
stream.on('data', (d) => (svgFont += d));
stream.on('end', () => {
  const ttf = svg2ttf(svgFont, {});
  fs.writeFileSync(out, Buffer.from(ttf.buffer));
  const map = {};
  names.forEach((n, i) => (map[n.replace('.svg', '')] = 0xe900 + i));
  fs.writeFileSync(out.replace('.ttf', '.json'), JSON.stringify(map, null, 2));
  console.log('ok', out, Object.keys(map).length, 'glyphs');
});
names.forEach((n, i) => {
  const glyph = fs.createReadStream(path.join(src, n));
  glyph.metadata = { name: n.replace('.svg', ''), unicode: [String.fromCharCode(0xe900 + i)] };
  stream.write(glyph);
});
stream.end();
