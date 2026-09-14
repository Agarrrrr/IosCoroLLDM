import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(path.resolve('website/package.json'));
const sharp = require('sharp');

const root = path.resolve('.');
const source = path.join(root, 'website/dist/social-kit/coro-lldm-app-icon-rounded.png');
const emblem = path.join(root, 'website/dist/social-kit/coro-lldm-emblema-transparente.png');
const out = path.join(root, 'assets/brand');

await fs.mkdir(out, { recursive: true });
await fs.copyFile(source, path.join(out, 'app-icon-rounded.png'));
await fs.copyFile(emblem, path.join(out, 'emblem-transparent.png'));

const emblemBuffer = await fs.readFile(emblem);

async function solidBackground(name, color) {
  const background = await sharp({
    create: { width: 1024, height: 1024, channels: 4, background: color },
  }).png().toBuffer();
  await sharp(background)
    .composite([{ input: emblemBuffer, blend: 'over' }])
    .png()
    .toFile(path.join(out, name));
}

await solidBackground('icon-light.png', '#F5F0E6');
await solidBackground('icon-oled.png', '#000000');
await solidBackground('icon-dark.png', '#11161C');
await solidBackground('icon-sepia.png', '#F4ECD8');

const circularMask = Buffer.from(
  '<svg width="1024" height="1024"><circle cx="512" cy="512" r="512" fill="white"/></svg>',
);
await sharp(source)
  .composite([{ input: circularMask, blend: 'dest-in' }])
  .png()
  .toFile(path.join(out, 'icon-circular.png'));

await sharp(emblemBuffer).tint('#FFFFFF').png().toFile(path.join(out, 'icon-monochrome.png'));
const androidFgEmblem = await sharp(emblemBuffer)
  .resize(620, 620, { fit: 'contain' })
  .toBuffer();
await sharp({
  create: { width: 1024, height: 1024, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
})
  .composite([{ input: androidFgEmblem, gravity: 'center' }])
  .png()
  .toFile(path.join(out, 'android-foreground.png'));
await sharp({
  create: { width: 1024, height: 1024, channels: 4, background: '#F5F0E6' },
}).png().toFile(path.join(out, 'android-background.png'));
await sharp(emblemBuffer).resize(768, 768, { fit: 'contain' }).png().toFile(path.join(out, 'splash-light.png'));
await sharp(emblemBuffer).resize(768, 768, { fit: 'contain' }).png().toFile(path.join(out, 'splash-dark.png'));

console.log(`Generated ${ (await fs.readdir(out)).length } brand variants in ${out}`);
