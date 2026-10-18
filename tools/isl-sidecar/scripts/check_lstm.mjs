import { readFileSync } from 'node:fs';
import { logitsFromFeatures } from '../../../web/include/lstm_math.js';

const root = new URL('../../../web/include/', import.meta.url);
const manifest = JSON.parse(readFileSync(new URL('lstm_manifest.json', root)));
const weights = readFileSync(new URL('lstm_weights.bin', root));
const fixture = JSON.parse(readFileSync(new URL('fixture.json', root)));
const view = new Float32Array(weights.buffer, weights.byteOffset, weights.byteLength / 4);
const tensors = {};
for (const spec of manifest.tensors) {
  tensors[spec.name] = view.subarray(spec.offset / 4, spec.offset / 4 + spec.length);
}
const frames = Float32Array.from(fixture.input);
const logits = logitsFromFeatures(frames, fixture.frames, tensors);
let maxErr = 0;
for (let i = 0; i < fixture.logits.length; i++) {
  maxErr = Math.max(maxErr, Math.abs(logits[i] - fixture.logits[i]));
}
console.log(`max abs error ${maxErr}`);
if (maxErr > 1e-3) process.exit(1);
