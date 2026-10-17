/**
 * MediaPipe Gesture Recognizer (official tasks-vision) for SignTalk WebRTC demo.
 * Supports **local** (your camera) and **remote** (partner’s main video) channels.
 */
import {
  FilesetResolver,
  GestureRecognizer,
} from 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14';

const WASM_BASE =
  'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm';
const MODEL_URL =
  'https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/1/gesture_recognizer.task';

const MIN_SCORE = 0.58;
const FRAME_MS = 80;

let recognizer = null;
let initError = null;
let initPromise = null;
let mediaPipeConsoleHintLogged = false;

function makeChannel() {
  return { videoEl: null, rafId: null, lastFrameMs: 0, pending: null };
}

const channels = {
  local: makeChannel(),
  remote: makeChannel(),
};

function logMediaPipeConsoleHintOnce() {
  if (mediaPipeConsoleHintLogged) return;
  mediaPipeConsoleHintLogged = true;
  console.info(
    '[SignTalkGesture] MediaPipe console W1016/XNNPACK lines are normal. ' +
      'Local = your camera; remote = partner video on your screen.',
  );
}

function resolveLocalPreviewVideo(preferredId) {
  let el = document.getElementById(preferredId);
  if (el && el.tagName === 'VIDEO') return el;
  const all = [...document.querySelectorAll('video[id^="video_RTCVideoRenderer-"]')];
  if (all.length === 0) return null;
  if (all.length === 1) return all[0];
  return all[all.length - 1];
}

function resolveRemotePreviewVideo(preferredId) {
  let el = document.getElementById(preferredId);
  if (el && el.tagName === 'VIDEO') return el;
  const all = [...document.querySelectorAll('video[id^="video_RTCVideoRenderer-"]')];
  if (all.length < 2) return null;
  return all[0];
}

function friendlyLabel(categoryName) {
  if (!categoryName || categoryName === 'None') return '';
  return categoryName.replace(/_/g, ' ');
}

async function ensureInit() {
  if (recognizer) return true;
  if (initError) return false;
  if (!initPromise) {
    initPromise = (async () => {
      const vision = await FilesetResolver.forVisionTasks(WASM_BASE);
      const base = { modelAssetPath: MODEL_URL };
      const opts = { runningMode: 'VIDEO', numHands: 2 };
      const mobile = /Android|iPhone|iPad|Mobile/i.test(navigator.userAgent);
      const order = mobile ? ['CPU', 'GPU'] : ['GPU', 'CPU'];
      for (const delegate of order) {
        try {
          recognizer = await GestureRecognizer.createFromOptions(vision, {
            baseOptions: { ...base, delegate },
            ...opts,
          });
          console.info(`[SignTalkGesture] using ${delegate} delegate`);
          logMediaPipeConsoleHintOnce();
          return true;
        } catch (e) {
          console.warn(`[SignTalkGesture] ${delegate} delegate failed`, e);
          recognizer = null;
        }
      }
      initError = 'GPU and CPU delegates failed';
      return false;
    })();
  }
  return initPromise;
}

function runLoop(channelKey) {
  const ch = channels[channelKey];
  if (!recognizer || !ch.videoEl) return;
  if (ch.videoEl.readyState < 2) {
    ch.rafId = requestAnimationFrame(() => runLoop(channelKey));
    return;
  }
  const now = performance.now();
  if (now - ch.lastFrameMs < FRAME_MS) {
    ch.rafId = requestAnimationFrame(() => runLoop(channelKey));
    return;
  }
  ch.lastFrameMs = now;
  try {
    const result = recognizer.recognizeForVideo(ch.videoEl, now);
    ch.pending = { status: 'tracking', gesture: '', label: '', score: 0 };
    if (result.gestures?.length && result.gestures[0]?.length) {
      const top = result.gestures[0][0];
      const score = top.score ?? 0;
      const name = top.categoryName ?? '';
      if (score >= MIN_SCORE && name && name !== 'None') {
        ch.pending = {
          status: 'recognized',
          gesture: name,
          label: friendlyLabel(name),
          score,
        };
      }
    }
  } catch (e) {
    ch.pending = { status: 'error', message: String(e) };
  }
  ch.rafId = requestAnimationFrame(() => runLoop(channelKey));
}

function startChannel(channelKey, videoElementId, resolveFn) {
  if (!recognizer) {
    return { ok: false, error: initError || 'Call init() first' };
  }
  stopChannel(channelKey);
  const ch = channels[channelKey];
  ch.videoEl = resolveFn(videoElementId);
  if (!ch.videoEl) {
    return { ok: false, error: `Video element not found: ${videoElementId}` };
  }
  ch.lastFrameMs = 0;
  ch.pending = { status: 'tracking', gesture: '', label: '', score: 0 };
  ch.rafId = requestAnimationFrame(() => runLoop(channelKey));
  return { ok: true, error: null };
}

function stopChannel(channelKey) {
  const ch = channels[channelKey];
  if (ch.rafId) cancelAnimationFrame(ch.rafId);
  ch.rafId = null;
  ch.videoEl = null;
  ch.pending = null;
}

function consumeChannel(channelKey) {
  const ch = channels[channelKey];
  const out = ch.pending;
  ch.pending = null;
  if (!out) return { status: 'idle' };
  return out;
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
    return startChannel('local', videoElementId, resolveLocalPreviewVideo);
  },

  stop() {
    stopChannel('local');
  },

  consume() {
    return consumeChannel('local');
  },

  startRemote(videoElementId) {
    return startChannel('remote', videoElementId, resolveRemotePreviewVideo);
  },

  stopRemote() {
    stopChannel('remote');
  },

  consumeRemote() {
    return consumeChannel('remote');
  },

  status() {
    if (initError) return { ready: false, running: !!channels.local.rafId, error: initError };
    return {
      ready: !!recognizer,
      running: !!channels.local.rafId || !!channels.remote.rafId,
      error: null,
    };
  },
};
