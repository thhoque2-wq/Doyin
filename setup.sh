#!/bin/sh
set -e
cat > .env.example <<'__EOF__'
# Required in production: any long random string (signs download links)
SIGN_SECRET=change-me
# Optional
YTDLP_PATH=yt-dlp
FFMPEG_PATH=ffmpeg
# Netscape-format cookies file; Douyin often needs this for yt-dlp to work
YTDLP_COOKIES=
__EOF__
cat > jsconfig.json <<'__EOF__'
{ "compilerOptions": { "baseUrl": ".", "paths": { "@/*": ["./*"] } } }
__EOF__
cat > middleware.js <<'__EOF__'
import { NextResponse } from "next/server";

// CORS for the API so a standalone HTML page (or another domain) can call it.
// Set ALLOWED_ORIGIN to your site's origin in production; "*" also covers pages opened from local storage.
export function middleware(req) {
  const headers = {
    "Access-Control-Allow-Origin": process.env.ALLOWED_ORIGIN || "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
  if (req.method === "OPTIONS") return new NextResponse(null, { status: 204, headers });
  const res = NextResponse.next();
  for (const [k, v] of Object.entries(headers)) res.headers.set(k, v);
  return res;
}

export const config = { matcher: "/api/:path*" };
__EOF__
cat > next.config.js <<'__EOF__'
module.exports = { reactStrictMode: true };
__EOF__
cat > package.json <<'__EOF__'
{
  "name": "douyin-downloader",
  "version": "1.0.0",
  "private": true,
  "scripts": { "dev": "next dev", "build": "next build", "start": "next start" },
  "dependencies": {
    "lucide-react": "^0.383.0",
    "next": "14.2.15",
    "react": "18.3.1",
    "react-dom": "18.3.1"
  },
  "devDependencies": {
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.47",
    "tailwindcss": "^3.4.14"
  }
}
__EOF__
cat > postcss.config.js <<'__EOF__'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
__EOF__
cat > tailwind.config.js <<'__EOF__'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{js,jsx}", "./components/**/*.{js,jsx}"],
  theme: {
    extend: {
      keyframes: {
        "fade-up": { "0%": { opacity: 0, transform: "translateY(16px)" }, "100%": { opacity: 1, transform: "translateY(0)" } },
      },
      animation: { "fade-up": "fade-up .5s ease-out both" },
    },
  },
  plugins: [],
};
__EOF__
mkdir -p components
cat > components/Downloader.jsx <<'__EOF__'
"use client";
import { useState } from "react";
import { AlertCircle, ClipboardPaste, Download, Loader2 } from "lucide-react";
import ResultCard from "./ResultCard";

export default function Downloader() {
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [result, setResult] = useState(null);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!input.trim() || loading) return;
    setLoading(true);
    setError("");
    setResult(null);
    try {
      const res = await fetch("/api/resolve", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ input }),
      });
      const json = await res.json();
      if (!res.ok || !json.ok) throw new Error(json.error || "Something went wrong. Please try again.");
      setResult(json.data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function handlePaste() {
    try {
      setInput(await navigator.clipboard.readText());
    } catch {
      /* clipboard permission denied: user can paste manually */
    }
  }

  return (
    <section className="mt-10">
      <form
        onSubmit={handleSubmit}
        className="flex flex-col gap-3 rounded-2xl border border-slate-800 bg-slate-900/70 p-3 shadow-xl shadow-purple-950/20 backdrop-blur sm:flex-row"
      >
        <div className="relative flex-1">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Paste Douyin/TikTok link here..."
            className="h-14 w-full rounded-xl border border-slate-700 bg-slate-950 px-4 pr-12 text-base text-slate-100 placeholder-slate-500 outline-none transition focus:border-pink-500 focus:ring-2 focus:ring-pink-500/30"
          />
          <button
            type="button"
            onClick={handlePaste}
            aria-label="Paste from clipboard"
            className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 transition hover:text-pink-400"
          >
            <ClipboardPaste size={20} />
          </button>
        </div>
        <button
          type="submit"
          disabled={loading || !input.trim()}
          className="flex h-14 items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-pink-500 to-purple-600 px-8 font-bold text-white transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {loading ? <Loader2 className="animate-spin" size={20} /> : <Download size={20} />}
          {loading ? "Processing..." : "Download"}
        </button>
      </form>

      {error && (
        <div className="mt-4 flex animate-fade-up items-start gap-2 rounded-xl border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-300">
          <AlertCircle size={18} className="mt-0.5 shrink-0" />
          <span>{error}</span>
        </div>
      )}
      {result && <ResultCard data={result} />}
    </section>
  );
}
__EOF__
mkdir -p components
cat > components/Faq.jsx <<'__EOF__'
"use client";
import { useState } from "react";
import { ChevronDown } from "lucide-react";

const ITEMS = [
  { q: "How do I download a Douyin video?", a: "Open Douyin or TikTok, tap Share, then Copy Link. Paste it into the box above and press Download. When the preview appears, choose MP4 or MP3." },
  { q: "Why is it free?", a: "The tool runs on lightweight server-side processing, so we can keep it free for everyone. No sign-up or subscription is required." },
  { q: "Will the video have a watermark?", a: "No. We fetch the original video source without the platform watermark whenever it is available." },
  { q: "Can I download only the audio?", a: "Yes. Use the Download Audio (MP3) button on the result card to save the soundtrack." },
  { q: "Does it work on my phone?", a: "Yes. It works in any modern mobile or desktop browser. On iOS, use Safari to save files." },
];

export default function Faq() {
  const [open, setOpen] = useState(0);
  return (
    <section className="mt-20">
      <h2 className="mb-6 text-center text-2xl font-bold">Frequently Asked Questions</h2>
      <div className="space-y-3">
        {ITEMS.map((item, i) => (
          <div key={item.q} className="rounded-xl border border-slate-800 bg-slate-900/60">
            <button
              onClick={() => setOpen(open === i ? -1 : i)}
              aria-expanded={open === i}
              className="flex w-full items-center justify-between gap-4 p-4 text-left font-medium"
            >
              {item.q}
              <ChevronDown size={18} className={`shrink-0 text-pink-400 transition-transform ${open === i ? "rotate-180" : ""}`} />
            </button>
            <div className={`grid transition-all duration-300 ${open === i ? "grid-rows-[1fr]" : "grid-rows-[0fr]"}`}>
              <p className="overflow-hidden px-4 text-sm text-slate-400">
                <span className="block pb-4">{item.a}</span>
              </p>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
__EOF__
mkdir -p components
cat > components/Features.jsx <<'__EOF__'
import { Droplets, Smartphone, Zap } from "lucide-react";

const FEATURES = [
  { icon: Droplets, title: "No Watermark", text: "Get the clean original video without the Douyin or TikTok logo." },
  { icon: Zap, title: "Fast Speed", text: "Links are resolved in seconds and files stream straight to your device." },
  { icon: Smartphone, title: "Mobile Friendly", text: "Works in any browser on phones, tablets and desktops. No app needed." },
];

export default function Features() {
  return (
    <section className="mt-20 grid gap-4 sm:grid-cols-3">
      {FEATURES.map(({ icon: Icon, title, text }) => (
        <div key={title} className="rounded-2xl border border-slate-800 bg-slate-900/60 p-6 transition hover:border-purple-500/50">
          <div className="mb-4 inline-flex rounded-xl bg-gradient-to-br from-pink-500/20 to-purple-500/20 p-3 text-pink-400">
            <Icon size={22} />
          </div>
          <h3 className="font-semibold">{title}</h3>
          <p className="mt-1 text-sm text-slate-400">{text}</p>
        </div>
      ))}
    </section>
  );
}
__EOF__
mkdir -p components
cat > components/Footer.jsx <<'__EOF__'
export default function Footer() {
  return (
    <footer className="relative border-t border-slate-800 px-4 py-8 text-center text-xs text-slate-500">
      <p>© {new Date().getFullYear()} Douyin Video Downloader. All rights reserved.</p>
      <p className="mx-auto mt-2 max-w-xl">
        This site is not affiliated with, endorsed by, or connected to Douyin, TikTok or ByteDance. Please respect creators&apos; rights and only download content you are allowed to save.
      </p>
    </footer>
  );
}
__EOF__
mkdir -p components
cat > components/ResultCard.jsx <<'__EOF__'
import { Film, Music } from "lucide-react";

function formatDuration(s) {
  if (!s) return "";
  const m = Math.floor(s / 60);
  return `${m}:${String(Math.floor(s % 60)).padStart(2, "0")}`;
}

export default function ResultCard({ data }) {
  const { title, author, thumbnail, duration, videoLink, audioLink } = data;
  return (
    <div className="mt-6 flex animate-fade-up flex-col gap-5 overflow-hidden rounded-2xl border border-slate-800 bg-slate-900 p-4 sm:flex-row">
      <div className="relative mx-auto aspect-[9/16] w-44 shrink-0 overflow-hidden rounded-xl bg-slate-800 sm:mx-0">
        {thumbnail && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={thumbnail} alt={title} referrerPolicy="no-referrer" className="h-full w-full object-cover" />
        )}
        {duration > 0 && (
          <span className="absolute bottom-2 right-2 rounded bg-black/70 px-1.5 py-0.5 text-xs">{formatDuration(duration)}</span>
        )}
      </div>
      <div className="flex min-w-0 flex-1 flex-col justify-between gap-4">
        <div>
          <h2 className="line-clamp-3 text-lg font-semibold leading-snug">{title}</h2>
          {author && <p className="mt-1 text-sm text-slate-400">@{author}</p>}
        </div>
        <div className="flex flex-col gap-3">
          <a
            href={videoLink}
            download
            className="flex h-12 items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-pink-500 to-purple-600 font-bold text-white transition hover:brightness-110"
          >
            <Film size={18} /> Download MP4 (No Watermark)
          </a>
          <a
            href={audioLink}
            download
            className="flex h-12 items-center justify-center gap-2 rounded-xl border border-slate-700 bg-slate-800 font-semibold text-slate-100 transition hover:border-pink-500"
          >
            <Music size={18} /> Download Audio (MP3)
          </a>
        </div>
      </div>
    </div>
  );
}
__EOF__
mkdir -p app
cat > app/globals.css <<'__EOF__'
@tailwind base;
@tailwind components;
@tailwind utilities;
__EOF__
mkdir -p app
cat > app/layout.jsx <<'__EOF__'
import "./globals.css";

export const metadata = {
  title: "Douyin Video Downloader – No Watermark, HD MP4 & MP3",
  description: "Download Douyin and TikTok videos without watermark in HD quality. Free, fast and mobile friendly.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-slate-950 text-slate-100 antialiased">{children}</body>
    </html>
  );
}
__EOF__
mkdir -p app
cat > app/page.jsx <<'__EOF__'
import Downloader from "@/components/Downloader";
import Features from "@/components/Features";
import Faq from "@/components/Faq";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <div className="relative overflow-hidden">
      <div className="pointer-events-none absolute -top-40 left-1/2 h-[480px] w-[900px] -translate-x-1/2 rounded-full bg-gradient-to-r from-pink-600/30 via-fuchsia-600/20 to-purple-600/30 blur-3xl" />
      <main className="relative mx-auto max-w-4xl px-4 pb-16 pt-16 sm:pt-24">
        <section className="text-center">
          <h1 className="text-4xl font-extrabold tracking-tight sm:text-6xl">
            Douyin <span className="bg-gradient-to-r from-pink-500 to-purple-500 bg-clip-text text-transparent">Video Downloader</span>
          </h1>
          <p className="mx-auto mt-4 max-w-2xl text-base text-slate-400 sm:text-lg">
            Download Douyin and TikTok videos without watermarks in HD quality. Just paste the share link, no app or sign-up needed.
          </p>
        </section>
        <Downloader />
        <Features />
        <Faq />
      </main>
      <Footer />
    </div>
  );
}
__EOF__
mkdir -p app/api/resolve
cat > app/api/resolve/route.js <<'__EOF__'
import { NextResponse } from "next/server";
import { extractUrl, resolveVideo } from "@/lib/ytdlp";
import { sign } from "@/lib/sign";

export const runtime = "nodejs";
export const maxDuration = 60;

// Minimal in-memory rate limit (per IP, per minute). Use Redis for multi-instance setups.
const hits = new Map();
function limited(ip) {
  const now = Date.now();
  const rec = hits.get(ip);
  if (!rec || rec.reset < now) {
    hits.set(ip, { count: 1, reset: now + 60000 });
    return false;
  }
  return ++rec.count > 10;
}

function link(type, url, title) {
  const q = new URLSearchParams({ type, u: url, s: sign(url), name: title });
  return `/api/download?${q}`;
}

export async function POST(req) {
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0] || "local";
  if (limited(ip)) return NextResponse.json({ ok: false, error: "Too many requests. Please wait a minute." }, { status: 429 });

  let body;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid request." }, { status: 400 });
  }

  const url = extractUrl(body?.input);
  if (!url) {
    return NextResponse.json({ ok: false, error: "Please paste a valid Douyin or TikTok link." }, { status: 400 });
  }

  try {
    const v = await resolveVideo(url);
    return NextResponse.json({
      ok: true,
      data: {
        title: v.title,
        author: v.author,
        thumbnail: v.thumbnail,
        duration: v.duration,
        videoLink: link("video", v.videoUrl, v.title),
        audioLink: link("audio", v.videoUrl, v.title),
      },
    });
  } catch (err) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 502 });
  }
}
__EOF__
mkdir -p app/api/download
cat > app/api/download/route.js <<'__EOF__'
import { spawn } from "child_process";
import { Readable } from "stream";
import { verify } from "@/lib/sign";
import { UA } from "@/lib/ytdlp";

export const runtime = "nodejs";
export const maxDuration = 300;

const REFERER = "https://www.douyin.com/";

function disposition(name, ext) {
  const clean = (name || "video").replace(/[\\/:*?"<>|\r\n]+/g, " ").trim().slice(0, 80) || "video";
  return `attachment; filename="download.${ext}"; filename*=UTF-8''${encodeURIComponent(clean)}.${ext}`;
}

export async function GET(req) {
  const p = new URL(req.url).searchParams;
  const url = p.get("u") || "";
  const type = p.get("type") === "audio" ? "audio" : "video";

  // Only URLs we signed ourselves can be proxied (prevents SSRF / open proxy abuse).
  if (!url || !verify(url, p.get("s") || "")) return new Response("Invalid link", { status: 403 });

  if (type === "audio") {
    const ff = spawn(process.env.FFMPEG_PATH || "ffmpeg", [
      "-user_agent", UA,
      "-headers", `Referer: ${REFERER}\r\n`,
      "-i", url,
      "-vn", "-c:a", "libmp3lame", "-q:a", "2",
      "-f", "mp3", "pipe:1",
    ]);
    ff.on("error", () => ff.stdout.destroy());
    req.signal.addEventListener("abort", () => ff.kill("SIGKILL"));
    return new Response(Readable.toWeb(ff.stdout), {
      headers: { "Content-Type": "audio/mpeg", "Content-Disposition": disposition(p.get("name"), "mp3") },
    });
  }

  const upstream = await fetch(url, { headers: { "User-Agent": UA, Referer: REFERER }, signal: req.signal });
  if (!upstream.ok || !upstream.body) return new Response("Source unavailable", { status: 502 });

  const headers = {
    "Content-Type": upstream.headers.get("content-type") || "video/mp4",
    "Content-Disposition": disposition(p.get("name"), "mp4"),
  };
  const len = upstream.headers.get("content-length");
  if (len) headers["Content-Length"] = len;
  return new Response(upstream.body, { headers });
}
__EOF__
mkdir -p lib
cat > lib/sign.js <<'__EOF__'
import crypto from "crypto";

const secret = () => process.env.SIGN_SECRET || "dev-secret-change-me";

export const sign = (value) => crypto.createHmac("sha256", secret()).update(value).digest("hex");

export function verify(value, sig = "") {
  const a = Buffer.from(sign(value));
  const b = Buffer.from(sig);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
__EOF__
mkdir -p lib
cat > lib/ytdlp.js <<'__EOF__'
import { execFile } from "child_process";
import { promisify } from "util";

const run = promisify(execFile);
const ALLOWED_HOST = /(^|\.)(douyin\.com|iesdouyin\.com|tiktok\.com)$/i;

export const UA =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1";

/** Pulls the first http(s) URL out of pasted share text and checks the host. */
export function extractUrl(input = "") {
  const m = input.match(/https?:\/\/[^\s]+/);
  if (!m) return null;
  const raw = m[0].replace(/[)\]}>,.，。！]+$/, "");
  try {
    const u = new URL(raw);
    return ALLOWED_HOST.test(u.hostname) ? u.toString() : null;
  } catch {
    return null;
  }
}

/** Uses yt-dlp to resolve a watermark-free direct video URL. */
export async function resolveVideo(url) {
  const args = ["-J", "--no-playlist", "--no-warnings", "--user-agent", UA];
  if (process.env.YTDLP_COOKIES) args.push("--cookies", process.env.YTDLP_COOKIES);

  let stdout;
  try {
    ({ stdout } = await run(process.env.YTDLP_PATH || "yt-dlp", [...args, url], {
      timeout: 30000,
      maxBuffer: 20 * 1024 * 1024,
    }));
  } catch (err) {
    if (err.code === "ENOENT") throw new Error("Server is missing yt-dlp.");
    throw new Error("Could not fetch this video. The link may be private, expired or unsupported.");
  }

  const info = JSON.parse(stdout);
  const formats = (info.formats || [])
    .filter(
      (f) =>
        f.url &&
        f.vcodec !== "none" &&
        f.acodec !== "none" &&
        f.format_id !== "download" &&
        !/watermark/i.test(`${f.format_id} ${f.format_note || ""}`)
    )
    .sort((a, b) => (b.height || 0) - (a.height || 0) || (b.tbr || 0) - (a.tbr || 0));

  const videoUrl = formats[0]?.url || info.url;
  if (!videoUrl) throw new Error("No downloadable video found for this link.");

  return {
    title: info.title || info.description || "Untitled video",
    author: info.uploader || info.channel || "",
    thumbnail: info.thumbnail || "",
    duration: info.duration || 0,
    videoUrl,
  };
}
__EOF__
