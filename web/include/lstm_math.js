/** Browser port of the OpenHands INCLUDE LSTM (pose flattener already applied). */

export function tensorsFromPack(manifest, buffer) {
  const view = new Float32Array(buffer);
  const tensors = {};
  for (const spec of manifest.tensors) {
    const start = spec.offset / 4;
    tensors[spec.name] = view.subarray(start, start + spec.length);
  }
  return tensors;
}

function gemvInto(out, weights, rows, cols, vector, bias) {
  for (let r = 0; r < rows; r++) {
    const row = r * cols;
    let sum = bias ? bias[r] : 0;
    for (let c = 0; c < cols; c++) sum += weights[row + c] * vector[c];
    out[r] = sum;
  }
}

function addScaled(out, weights, rows, cols, vector) {
  for (let r = 0; r < rows; r++) {
    const row = r * cols;
    let sum = out[r];
    for (let c = 0; c < cols; c++) sum += weights[row + c] * vector[c];
    out[r] = sum;
  }
}

/**
 * @param {Float32Array} frames length T * 54, row-major (T, 54)
 * @param {number} frameCount
 * @param {Record<string, Float32Array>} weights
 * @returns {Float32Array} logits, length 263
 */
export function logitsFromFeatures(frames, frameCount, weights) {
  const hidden = 128;
  const gate = hidden * 4;
  let seq = frames;
  let seqLen = frameCount;
  let inputSize = 54;

  const gates = new Float32Array(gate);
  const h = new Float32Array(hidden);
  const c = new Float32Array(hidden);

  for (let layer = 0; layer < 4; layer++) {
    const next = new Float32Array(seqLen * hidden * 2);
    for (const reverse of [false, true]) {
      const suffix = `l${layer}${reverse ? '_reverse' : ''}`;
      const wIh = weights[`decoder.rnn.weight_ih_${suffix}`];
      const wHh = weights[`decoder.rnn.weight_hh_${suffix}`];
      const bIh = weights[`decoder.rnn.bias_ih_${suffix}`];
      const bHh = weights[`decoder.rnn.bias_hh_${suffix}`];
      h.fill(0);
      c.fill(0);
      const hs = new Float32Array(seqLen * hidden);
      for (let step = 0; step < seqLen; step++) {
        const t = reverse ? seqLen - 1 - step : step;
        gemvInto(gates, wIh, gate, inputSize, seq.subarray(t * inputSize, (t + 1) * inputSize), bIh);
        addScaled(gates, wHh, gate, hidden, h);
        for (let i = 0; i < gate; i++) gates[i] += bHh[i];
        for (let i = 0; i < hidden; i++) {
          const ig = 1 / (1 + Math.exp(-gates[i]));
          const fg = 1 / (1 + Math.exp(-gates[hidden + i]));
          const gg = Math.tanh(gates[hidden * 2 + i]);
          const og = 1 / (1 + Math.exp(-gates[hidden * 3 + i]));
          c[i] = fg * c[i] + ig * gg;
          h[i] = og * Math.tanh(c[i]);
        }
        hs.set(h, t * hidden);
      }
      const destOffset = reverse ? hidden : 0;
      for (let t = 0; t < seqLen; t++) {
        next.set(hs.subarray(t * hidden, (t + 1) * hidden), t * hidden * 2 + destOffset);
      }
    }
    seq = next;
    inputSize = hidden * 2;
  }

  const width = hidden * 2;
  const hT = seq.subarray((seqLen - 1) * width, seqLen * width);
  const fc1 = weights['decoder.attn_block.fc1.weight'];
  const scoreFirst = new Float32Array(seqLen * width);
  for (let t = 0; t < seqLen; t++) {
    gemvInto(
      scoreFirst.subarray(t * width, (t + 1) * width),
      fc1,
      width,
      width,
      seq.subarray(t * width, (t + 1) * width),
      null,
    );
  }
  const score = new Float32Array(seqLen);
  let maxScore = -Infinity;
  for (let t = 0; t < seqLen; t++) {
    let sum = 0;
    const row = t * width;
    for (let i = 0; i < width; i++) sum += scoreFirst[row + i] * hT[i];
    score[t] = sum;
    if (sum > maxScore) maxScore = sum;
  }
  let denom = 0;
  for (let t = 0; t < seqLen; t++) {
    score[t] = Math.exp(score[t] - maxScore);
    denom += score[t];
  }
  const context = new Float32Array(width);
  for (let t = 0; t < seqLen; t++) {
    const w = score[t] / denom;
    const row = t * width;
    for (let i = 0; i < width; i++) context[i] += seq[row + i] * w;
  }
  const pre = new Float32Array(width * 2);
  pre.set(context, 0);
  pre.set(hT, width);
  const fc2 = weights['decoder.attn_block.fc2.weight'];
  const attention = new Float32Array(width);
  gemvInto(attention, fc2, width, width * 2, pre, null);
  for (let i = 0; i < width; i++) attention[i] = Math.tanh(attention[i]);

  const fcW = weights['decoder.fc.weight'];
  const fcB = weights['decoder.fc.bias'];
  const numClass = fcB.length;
  const logits = new Float32Array(numClass);
  gemvInto(logits, fcW, numClass, width, attention, fcB);
  return logits;
}

export function topPrediction(logits, labels) {
  let best = 0;
  let second = -Infinity;
  for (let i = 1; i < logits.length; i++) {
    if (logits[i] > logits[best]) {
      second = logits[best];
      best = i;
    } else if (logits[i] > second) {
      second = logits[i];
    }
  }
  const max = logits[best];
  let sum = 0;
  for (let i = 0; i < logits.length; i++) sum += Math.exp(logits[i] - max);
  const confidence = 1 / sum;
  const runnerUp = Math.exp(second - max) / sum;
  const raw = labels[best] || '';
  const word = raw.replace(/^\d+\.\s*/, '').replace(/[_]+/g, ' ').trim();
  return { word, confidence, margin: confidence - runnerUp, index: best };
}
