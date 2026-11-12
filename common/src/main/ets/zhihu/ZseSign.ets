/**
 * Port of rs-zse-sign (Rust) — Zhihu x-zse-96 v4 signing algorithm.
 * Source: ZhihuPura-master/rs-zse-sign/src/lib.rs (AGPL-3.0, zly2006)
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

const ZK: number[] = [
  1170614578, 1024848638, 1413669199, 3951632832, 3528873006, 2921909214, 4151847688, 3997739139,
  1933479194, 3323781115, 3888513386, 460404854, 3747539722, 2403641034, 2615871395, 2119585428,
  2265697227, 2035090028, 2773447226, 4289380121, 4217216195, 2200601443, 3051914490, 1579901135,
  1321810770, 456816404, 2903323407, 4065664991, 330002838, 3506006750, 363569021, 2347096187
];

const ZB: number[] = [
  20, 223, 245, 7, 248, 2, 194, 209, 87, 6, 227, 253, 240, 128, 222, 91, 237, 9, 125, 157, 230,
  93, 252, 205, 90, 79, 144, 199, 159, 197, 186, 167, 39, 37, 156, 198, 38, 42, 43, 168, 217,
  153, 15, 103, 80, 189, 71, 191, 97, 84, 247, 95, 36, 69, 14, 35, 12, 171, 28, 114, 178, 148,
  86, 182, 32, 83, 158, 109, 22, 255, 94, 238, 151, 85, 77, 124, 254, 18, 4, 26, 123, 176, 232,
  193, 131, 172, 143, 142, 150, 30, 10, 146, 162, 62, 224, 218, 196, 229, 1, 192, 213, 27, 110,
  56, 231, 180, 138, 107, 242, 187, 54, 120, 19, 44, 117, 228, 215, 203, 53, 239, 251, 127, 81,
  11, 133, 96, 204, 132, 41, 115, 73, 55, 249, 147, 102, 48, 122, 145, 106, 118, 74, 190, 29, 16,
  174, 5, 177, 129, 63, 113, 99, 31, 161, 76, 246, 34, 211, 13, 60, 68, 207, 160, 65, 111, 82,
  165, 67, 169, 225, 57, 112, 244, 155, 51, 236, 200, 233, 58, 61, 47, 100, 137, 185, 64, 17, 70,
  234, 163, 219, 108, 170, 166, 59, 149, 52, 105, 24, 212, 78, 173, 45, 0, 116, 226, 119, 136,
  206, 135, 175, 195, 25, 92, 121, 208, 126, 139, 3, 75, 141, 21, 130, 98, 241, 40, 154, 66, 184,
  49, 181, 46, 243, 88, 101, 183, 8, 23, 72, 188, 104, 179, 210, 134, 250, 201, 164, 89, 216,
  202, 220, 50, 221, 152, 140, 33, 235, 214
];

const ZSE_ALPHABET: string = '6fpLRqJO8M/c3jnYxFkUVC4ZIG12SiH=5v0mXDazWBTsuw7QetbKdoPyAl+hN9rgE';
const ZSE_KEY16: string = '059053f7d15e01d7';

function rotl32(x: number, n: number): number {
  return (((x << n) | (x >>> (32 - n))) >>> 0);
}

function readU32Be(bytes: number[], offset: number): number {
  return (bytes[offset] * 0x1000000 + bytes[offset + 1] * 0x10000 + bytes[offset + 2] * 0x100 + bytes[offset + 3]) >>> 0;
}

function writeU32Be(value: number, out: number[], offset: number): void {
  out[offset] = (value >>> 24) & 0xFF;
  out[offset + 1] = (value >>> 16) & 0xFF;
  out[offset + 2] = (value >>> 8) & 0xFF;
  out[offset + 3] = value & 0xFF;
}

function gTransform(tt: number): number {
  const b0 = ZB[(tt >>> 24) & 0xFF];
  const b1 = ZB[(tt >>> 16) & 0xFF];
  const b2 = ZB[(tt >>> 8) & 0xFF];
  const b3 = ZB[tt & 0xFF];
  const ti = (b0 * 0x1000000 + b1 * 0x10000 + b2 * 0x100 + b3) >>> 0;
  return (ti ^ rotl32(ti, 2) ^ rotl32(ti, 10) ^ rotl32(ti, 18) ^ rotl32(ti, 24)) >>> 0;
}

function rBlock(input16: number[]): number[] {
  const tr: number[] = new Array<number>(36).fill(0);
  tr[0] = readU32Be(input16, 0);
  tr[1] = readU32Be(input16, 4);
  tr[2] = readU32Be(input16, 8);
  tr[3] = readU32Be(input16, 12);
  for (let i = 0; i < 32; i++) {
    const ta = gTransform((tr[i + 1] ^ tr[i + 2] ^ tr[i + 3] ^ ZK[i]) >>> 0);
    tr[i + 4] = (tr[i] ^ ta) >>> 0;
  }
  const out: number[] = new Array<number>(16).fill(0);
  writeU32Be(tr[35], out, 0);
  writeU32Be(tr[34], out, 4);
  writeU32Be(tr[33], out, 8);
  writeU32Be(tr[32], out, 12);
  return out;
}

function xBlocks(data: number[], iv: number[]): number[] {
  const out: number[] = [];
  let curIv: number[] = iv;
  for (let chunkStart = 0; chunkStart < data.length; chunkStart += 16) {
    const mixed: number[] = new Array<number>(16).fill(0);
    for (let i = 0; i < 16; i++) {
      mixed[i] = data[chunkStart + i] ^ curIv[i];
    }
    curIv = rBlock(mixed);
    for (let i = 0; i < 16; i++) {
      out.push(curIv[i]);
    }
  }
  return out;
}

function customEncode(inputBytes: number[]): string {
  const bytes: number[] = inputBytes.slice();
  while (bytes.length % 3 !== 0) {
    bytes.push(0);
  }
  let out = '';
  let i = 0;
  let p = bytes.length - 1;
  while (p >= 0) {
    let v = 0;
    const b0 = bytes[p];
    const m0 = (58 >>> (8 * (i % 4))) & 0xFF;
    i += 1;
    v |= (b0 ^ m0) & 0xFF;
    const b1 = bytes[p - 1];
    const m1 = (58 >>> (8 * (i % 4))) & 0xFF;
    i += 1;
    v |= ((b1 ^ m1) & 0xFF) << 8;
    const b2 = bytes[p - 2];
    const m2 = (58 >>> (8 * (i % 4))) & 0xFF;
    i += 1;
    v |= ((b2 ^ m2) & 0xFF) << 16;
    out += ZSE_ALPHABET.charAt(v & 63);
    out += ZSE_ALPHABET.charAt((v >>> 6) & 63);
    out += ZSE_ALPHABET.charAt((v >>> 12) & 63);
    out += ZSE_ALPHABET.charAt((v >>> 18) & 63);
    p -= 3;
  }
  return out;
}

function md5Hex(input: string): string {
  const encoder = new util.TextEncoder();
  const data: Uint8Array = encoder.encodeInto(input);
  const md = cryptoFramework.createMd('MD5');
  md.updateSync({ data: data });
  const digest = md.digestSync();
  const hexChars: string = '0123456789abcdef';
  let out = '';
  for (let i = 0; i < digest.data.length; i++) {
    out += hexChars.charAt((digest.data[i] >>> 4) & 0x0F);
    out += hexChars.charAt(digest.data[i] & 0x0F);
  }
  return out;
}

export function encryptZseV4(input: string): string {
  const seed = 12;
  const escaped = encodeURIComponent(input);
  const plain: number[] = [seed, 0];
  for (let i = 0; i < escaped.length; i++) {
    plain.push(escaped.charCodeAt(i));
  }
  const pad = 16 - (plain.length % 16);
  for (let i = 0; i < pad; i++) {
    plain.push(pad);
  }
  const first: number[] = new Array<number>(16).fill(0);
  for (let i = 0; i < 16; i++) {
    first[i] = (plain[i] ^ ZSE_KEY16.charCodeAt(i) ^ 42) & 0xFF;
  }
  const c0 = rBlock(first);
  const cipher: number[] = [];
  for (let i = 0; i < 16; i++) {
    cipher.push(c0[i]);
  }
  if (plain.length > 16) {
    const rest = plain.slice(16);
    const encryptedRest = xBlocks(rest, c0);
    for (let i = 0; i < encryptedRest.length; i++) {
      cipher.push(encryptedRest[i]);
    }
  }
  return customEncode(cipher);
}

export function createZse96Header(zse93: string, url: string, dc0: string, body: string | null): string {
  const afterScheme = url.substring(url.indexOf('//') + 2);
  const pathname = '/' + afterScheme.substring(afterScheme.indexOf('/') + 1);
  let signSource = zse93 + '+' + pathname + '+' + dc0;
  if (body !== null) {
    signSource += '+' + body;
  }
  return '2.0_' + encryptZseV4(md5Hex(signSource));
}

export const ZSE_93_WEB: string = '101_3_3.0';
