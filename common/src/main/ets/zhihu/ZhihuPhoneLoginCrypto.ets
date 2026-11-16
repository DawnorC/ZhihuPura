/**
 * SMS request-body codec ported from Zhihu++ ZhihuMessageBodyEncryptor.kt.
 * Copyright (C) 2024-2026 zly2006 <i@zly2006.me>
 * SPDX-License-Identifier: AGPL-3.0-only
 */
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

const BLOCK_SIZE: number = 16;
const ROUNDS: number = 10;
const INITIAL_VECTOR: string = 'f0551856aa575faa';
const INITIAL_XOR: number = 176;
const ROUND_XOR: number = 432;
const FINAL_XOR: number = 688;
const SUBSTITUTE: number = 5040;
const MIX_TABLES: number[] = [944, 1968, 2992, 4016];
const SHIFT_ROWS: number[] = [0, 5, 10, 15, 4, 9, 14, 3, 8, 13, 2, 7, 12, 1, 6, 11];

// The upstream lookup tables define the on-wire codec for Zhihu's mobile client.
const PROTOCOL_DATA: string =
  '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' +
  'HyVIBQ==';

const base64: util.Base64Helper = new util.Base64Helper();
let tables: Uint8Array | undefined;

function swapPairs(value: number): number {
  return ((value & 0x55) << 1) | ((value & 0xaa) >>> 1);
}

function encodedXor(data: Uint8Array, table: number, left: number, right: number): number {
  const high = ((left >>> 4) << 4) ^ (right >>> 4);
  const low = ((left & 0x0f) << 4) ^ (right & 0x0f);
  return (data[table + high] & 0xf0) ^ (data[table + low] >>> 4);
}

function encryptBlock(block: Uint8Array, data: Uint8Array): Uint8Array {
  let state = new Uint8Array(BLOCK_SIZE);
  for (let index = 0; index < BLOCK_SIZE; index++) {
    state[index] = encodedXor(data, INITIAL_XOR, block[index], data[index]);
  }
  for (let round = 1; round < ROUNDS; round++) {
    const mixed = new Uint8Array(BLOCK_SIZE);
    for (let word = 0; word < BLOCK_SIZE; word += 4) {
      for (let table = 0; table < MIX_TABLES.length; table++) {
        const lookup = MIX_TABLES[table] + state[SHIFT_ROWS[word + table]] * 4;
        for (let byte = 0; byte < 4; byte++) {
          const value = data[lookup + 3 - byte];
          const index = word + byte;
          mixed[index] = table === 0 ? value : encodedXor(data, ROUND_XOR, mixed[index], value);
        }
      }
    }
    const key = round * BLOCK_SIZE;
    for (let index = 0; index < BLOCK_SIZE; index++) {
      mixed[index] = encodedXor(data, ROUND_XOR, mixed[index], data[key + index]);
    }
    state = mixed;
  }
  const key = ROUNDS * BLOCK_SIZE;
  const encrypted = new Uint8Array(BLOCK_SIZE);
  for (let index = 0; index < BLOCK_SIZE; index++) {
    const substituted = data[SUBSTITUTE + state[SHIFT_ROWS[index]]];
    encrypted[index] = encodedXor(data, FINAL_XOR, substituted, data[key + index]);
  }
  return encrypted;
}

export function encryptPhoneLoginForm(form: string): string {
  if (!tables) {
    tables = base64.decodeSync(PROTOCOL_DATA);
  }
  const plain = new util.TextEncoder().encodeInto(form);
  const padding = BLOCK_SIZE - plain.length % BLOCK_SIZE;
  const output = new Uint8Array(plain.length + padding);
  let previous = new Uint8Array(BLOCK_SIZE);
  for (let index = 0; index < BLOCK_SIZE; index++) {
    previous[index] = swapPairs(INITIAL_VECTOR.charCodeAt(index));
  }
  for (let offset = 0; offset < output.length; offset += BLOCK_SIZE) {
    const block = new Uint8Array(BLOCK_SIZE);
    for (let index = 0; index < BLOCK_SIZE; index++) {
      const position = offset + index;
      const value = position < plain.length ? plain[position] : padding;
      block[index] = swapPairs(value) ^ 0xbb ^ previous[index];
    }
    previous = encryptBlock(block, tables);
    for (let index = 0; index < BLOCK_SIZE; index++) {
      output[offset + index] = swapPairs(previous[index]);
    }
  }
  return base64.encodeToStringSync(output);
}

export async function signPhoneLoginRequest(secret: string, input: string): Promise<string> {
  // Zhihu's mobile API requires HMAC-SHA1 for these two client signatures.
  const encoder = new util.TextEncoder();
  const generator = cryptoFramework.createSymKeyGenerator('HMAC');
  const key = await generator.convertKey({ data: encoder.encodeInto(secret) });
  const mac = cryptoFramework.createMac('SHA1');
  await mac.init(key);
  await mac.update({ data: encoder.encodeInto(input) });
  const digest = await mac.doFinal();
  let hex = '';
  for (const byte of digest.data) {
    hex += byte.toString(16).padStart(2, '0');
  }
  return hex;
}
