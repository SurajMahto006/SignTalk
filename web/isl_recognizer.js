/**
 * Live INCLUDE (263-word Indian Sign Language) recognizer.
 * Pose + both hands -> the pretrained OpenHands LSTM, running in the browser.
 */
import {
  FilesetResolver,
  HandLandmarker,
  PoseLandmarker,
} from 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14';
import { logitsFromFeatures, tensorsFromPack, topPrediction } from './include/lstm_math.js';

const WASM_BASE = 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm';
const POSE_URL =
  'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task';
const HAND_URL =
  'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task';

const POSE_INDEXES = [0, 2, 5, 11, 12, 13, 14];
const HAND_INDEXES = [0, 4, 5, 8, 9, 12, 13, 16, 17, 20];
const FRAME_MS = 100;
const WINDOW_MS = 1800;
const MIN_FRAMES = 12;
const MIN_CONFIDENCE = 0.4;
const REPEAT_MS = 1600;

let pose = null;
let hands = null;
let weights = null;
let labels = null;
let initError = null;
let initPromise = null;
let videoEl = null;
let rafId = null;
let lastFrameMs = 0;
let lastInferMs = 0;
let pending = null;
let lastWord = '';
let lastWordAt = 0;
const history = [];

function resolveLocalPreviewVideo(preferredId) {
  const el = document.getElementById(preferredId);
  if (el && el.tagName === 'VIDEO') return el;
  const all = [...document.querySelectorAll('video[id^="video_RTCVideoRenderer-"]')];
  if (all.length === 0) return null;
  return all[all.length - 1];
}

async function createWithFallback(factory) {
  const mobile = /Android|iPhone|iPad|Mobile/i.test(navigator.userAgent);
  const order = mobile ? ['CPU', 'GPU'] : ['GPU', 'CPU'];
  let last = null;
  for (const delegate of order) {
    try {
      return await factory(delegate);
    } catch (e) {
      last = e;
    }
  }
  throw last || new Error('model failed');
}

async function ensureInit() {
  if (pose && hands && weights) return true;
  if (initError) return false;
  if (!initPromise) {
    initPromise = (async () => {
      const vision = await FilesetResolver.forVisionTasks(WASM_BASE);
      pose = await createWithFallback((delegate) =>
        PoseLandmarker.createFromOptions(vision, {
          baseOptions: { modelAssetPath: POSE_URL, delegate },
          runningMode: 'VIDEO',
          numPoses: 1,
        }),
      );
      hands = await createWithFallback((delegate) =>
        HandLandmarker.createFromOptions(vision, {
          baseOptions: { modelAssetPath: HAND_URL, delegate },
          runningMode: 'VIDEO',
          numHands: 2,
        }),
      );
      const [manifestRes, weightRes] = await Promise.all([
        fetch('include/lstm_manifest.json'),
        fetch('include/lstm_weights.bin'),
      ]);
      const manifest = await manifestRes.json();
      const buffer = await weightRes.arrayBuffer();
      weights = tensorsFromPack(manifest, buffer);
      labels = manifest.labels;
      console.info(`[SignTalkISL] INCLUDE model ready (${labels.length} words)`);
      return true;
    })().catch((e) => {
      initError = String(e);
      console.error('[SignTalkISL] init failed', e);
      return false;
    });
  }
  return initPromise;
}

function xy(lm, index) {
  if (!lm || !lm[index]) return { x: 0, y: 0 };
  return { x: lm[index].x, y: lm[index].y };
}

function assignHands(detected, leftWrist, rightWrist) {
  const used = new Set();
  function take(wrist) {
    let best = null;
    let bestD = 0.25;
    let bestIndex = -1;
    detected.forEach((hand, index) => {
      if (used.has(index)) return;
      const d = Math.hypot(hand[0].x - wrist.x, hand[0].y - wrist.y);
      if (d < bestD) {
        bestD = d;
        best = hand;
        bestIndex = index;
      }
    });
    if (bestIndex >= 0) used.add(bestIndex);
    return best;
  }
  return [take(leftWrist), take(rightWrist)];
}

function pushFrame(poseLm, handLms) {
  const [left, right] = assignHands(handLms, xy(poseLm, 15), xy(poseLm, 16));
  const points = [];
  for (const index of POSE_INDEXES) points.push(xy(poseLm, index));
  for (const index of HAND_INDEXES) points.push(left ? xy(left, index) : { x: 0, y: 0 });
  for (const index of HAND_INDEXES) points.push(right ? xy(right, index) : { x: 0, y: 0 });
  history.push({ t: performance.now(), points });
  const cutoff = performance.now() - WINDOW_MS;
  while (history.length && history[0].t < cutoff) history.shift();
}

function featuresFromHistory() {
  if (history.length < MIN_FRAMES) return null;
  let sx = 0;
  let sy = 0;
  let dist = 0;
  for (const frame of history) {
    const a = frame.points[3];
    const b = frame.points[4];
    sx += (a.x + b.x) / 2;
    sy += (a.y + b.y) / 2;
    dist += Math.hypot(a.x - b.x, a.y - b.y);
  }
  const n = history.length;
  const meanDist = dist / n;
  if (meanDist < 0.02) return null;
  const cx = sx / n;
  const cy = sy / n;
  const scale = 1 / meanDist;
  const out = new Float32Array(n * 54);
  for (let t = 0; t < n; t++) {
    const pts = history[t].points;
    for (let v = 0; v < 27; v++) out[t * 54 + v] = (pts[v].x - cx) * scale;
    for (let v = 0; v < 27; v++) out[t * 54 + 27 + v] = (pts[v].y - cy) * scale;
  }
  return out;
}

function infer() {
  const features = featuresFromHistory();
  if (!features || !weights) return;
  const logits = logitsFromFeatures(features, history.length, weights);
  const top = topPrediction(logits, labels);
  const now = performance.now();
  if (top.confidence < MIN_CONFIDENCE || !top.word) return;
  if (top.word === lastWord && now - lastWordAt < REPEAT_MS) return;
  lastWord = top.word;
  lastWordAt = now;
  pending = { status: 'recognized', word: top.word, score: top.confidence };
}

function loop() {
  if (!pose || !hands || !videoEl) return;
  if (videoEl.readyState < 2) {
    rafId = requestAnimationFrame(loop);
    return;
  }
  const now = performance.now();
  if (now - lastFrameMs >= FRAME_MS) {
    lastFrameMs = now;
    try {
      const poseResult = pose.detectForVideo(videoEl, now);
      const handResult = hands.detectForVideo(videoEl, now);
      const poseLm = poseResult.landmarks && poseResult.landmarks[0];
      if (poseLm) {
        pushFrame(poseLm, handResult.landmarks || []);
        if (history.length >= MIN_FRAMES && now - lastInferMs > 450) {
          lastInferMs = now;
          infer();
        }
      }
    } catch (e) {
      pending = { status: 'error', message: String(e) };
    }
  }
  rafId = requestAnimationFrame(loop);
}

globalThis.SignTalkIsl = {
  async init() {
    const ready = await ensureInit();
    return { ready, error: ready ? null : initError };
  },

  start(videoElementId) {
    if (!pose || !hands) return { ok: false, error: initError || 'Call init() first' };
    this.stop();
    videoEl = resolveLocalPreviewVideo(videoElementId);
    if (!videoEl) return { ok: false, error: `Video element not found: ${videoElementId}` };
    history.length = 0;
    lastFrameMs = 0;
    lastInferMs = 0;
    pending = { status: 'tracking', word: '', score: 0 };
    rafId = requestAnimationFrame(loop);
    return { ok: true, error: null };
  },

  stop() {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = null;
    videoEl = null;
    pending = null;
    history.length = 0;
  },

  consume() {
    const out = pending;
    pending = null;
    if (!out) return { status: 'idle' };
    return out;
  },
};
