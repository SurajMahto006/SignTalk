/**
 * MediaPipe Gesture Recognizer (official tasks-vision) for SignTalk WebRTC demo.
 * @see https://developers.google.com/mediapipe/solutions/vision/gesture_recognizer/web_js
 */
import {
  FilesetResolver,
  GestureRecognizer,
} from 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14';

const WASM_BASE =
  'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm';
const MODEL_URL =
  'https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task';

const MIN_SCORE = 0.65;

let recognizer = null;
let initError = null;
let initPromise = null;
let rafId = null;
let videoEl = null;
let lastFrameMs = 0;
let pending = null;

function friendlyLabel(categoryName) {
  if (!categoryName || categoryName === 'None') return '';
  return categoryName.replace(/_/g, ' ');
}

async function ensureInit() {
  if (recognizer) return true;
  if (initError) return false;
  if (!initPromise) {
    initPromise = (async () => {
      try {
        const vision = await FilesetResolver.forVisionTasks(WASM_BASE);
        recognizer = await GestureRecognizer.createFromOptions(vision, {
          baseOptions: {
            modelAssetPath: MODEL_URL,
            delegate: 'GPU',
          },
          runningMode: 'VIDEO',
          numHands: 2,
        });
        return true;
      } catch (e) {
        initError = String(e);
        console.error('[SignTalkGesture] init failed', e);
        return false;
      }
    })();
  }
  return initPromise;
}

function loop() {
  if (!recognizer || !videoEl) return;
  if (videoEl.readyState < 2) {
    rafId = requestAnimationFrame(loop);
    return;
  }
  const now = performance.now();
  if (now - lastFrameMs < 80) {
    rafId = requestAnimationFrame(loop);
    return;
  }
  lastFrameMs = now;
  try {
    const result = recognizer.recognizeForVideo(videoEl, now);
    pending = { status: 'tracking', gesture: '', label: '', score: 0 };
    if (result.gestures?.length && result.gestures[0]?.length) {
      const top = result.gestures[0][0];
      const score = top.score ?? 0;
      const name = top.categoryName ?? '';
      if (score >= MIN_SCORE && name && name !== 'None') {
        pending = {
          status: 'recognized',
          gesture: name,
          label: friendlyLabel(name),
          score,
        };
      }
    }
  } catch (e) {
    pending = { status: 'error', message: String(e) };
  }
  rafId = requestAnimationFrame(loop);
}

globalThis.SignTalkGesture = {
  async init() {
    const ok = await ensureInit();
    if (!ok) {
      return { ready: false, error: initError || 'Gesture model failed to load' };
    }
    return { ready: true, error: null };
  },

  start(videoElementId) {
    if (!recognizer) {
      return { ok: false, error: initError || 'Call init() first' };
    }
    this.stop();
    videoEl = document.getElementById(videoElementId);
    if (!videoEl || videoEl.tagName !== 'VIDEO') {
      return { ok: false, error: `Video element not found: ${videoElementId}` };
    }
    lastFrameMs = 0;
    pending = { status: 'tracking', gesture: '', label: '', score: 0 };
    rafId = requestAnimationFrame(loop);
    return { ok: true, error: null };
  },

  stop() {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = null;
    videoEl = null;
    pending = null;
  },

  consume() {
    const out = pending;
    pending = null;
    if (!out) return { status: 'idle' };
    return out;
  },

  status() {
    if (initError) return { ready: false, running: !!rafId, error: initError };
    return { ready: !!recognizer, running: !!rafId, error: null };
  },
};
