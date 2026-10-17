/**
 * Capture JPEG frames from HTMLVideoElement (Sign-to-Text camera or WebRTC preview).
 */
(function () {
  function resolveVideo(preferredId) {
    if (preferredId) {
      const el = document.getElementById(preferredId);
      if (el && el.tagName === 'VIDEO') return el;
    }
    const rtc = [...document.querySelectorAll('video[id^="video_RTCVideoRenderer-"]')];
    if (rtc.length > 0) return rtc[rtc.length - 1];
    const cam = document.getElementById('signtalk-camera-preview');
    if (cam && cam.tagName === 'VIDEO') return cam;
    return null;
  }

  function captureJpegBase64(video, quality) {
    const w = video.videoWidth || 0;
    const h = video.videoHeight || 0;
    if (w < 16 || h < 16) {
      return { ok: false, error: 'Video not ready (no dimensions yet).' };
    }
    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    if (!ctx) return { ok: false, error: 'Canvas not supported.' };
    ctx.drawImage(video, 0, 0, w, h);
    const dataUrl = canvas.toDataURL('image/jpeg', quality ?? 0.72);
    const comma = dataUrl.indexOf(',');
    return { ok: true, base64: comma >= 0 ? dataUrl.slice(comma + 1) : dataUrl };
  }

  globalThis.SignTalkFrameCapture = {
    captureFromVideoId(preferredId, quality) {
      const video = resolveVideo(preferredId);
      if (!video) return { ok: false, error: 'No video element found.' };
      return captureJpegBase64(video, quality);
    },

    /** Collect [count] JPEG base64 strings spaced by intervalMs (async). */
    async captureClip(preferredId, count, intervalMs, quality) {
      const n = Math.max(1, Math.min(count ?? 8, 24));
      const gap = Math.max(40, intervalMs ?? 80);
      const frames = [];
      for (let i = 0; i < n; i += 1) {
        const shot = this.captureFromVideoId(preferredId, quality);
        if (shot.ok && shot.base64) frames.push(shot.base64);
        if (i + 1 < n) {
          await new Promise((r) => setTimeout(r, gap));
        }
      }
      if (frames.length === 0) {
        return { ok: false, error: 'Could not capture any frames.', frames: [] };
      }
      return { ok: true, frames };
    },
  };
})();
