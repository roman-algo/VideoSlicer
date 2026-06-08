# VideoSlicer

A tiny, clean macOS app that cuts one video into many clips **losslessly** — no
matter how long or large the source is. You give it a movie and a list of
timestamps as JSON; it copies out each segment and drops the files into a folder
you choose.

- **No quality loss.** Default mode is ffmpeg stream-copy (`-c copy`): it copies
  the original video/audio bytes, never re-encodes. A 2‑hour 4K file is cut in
  seconds.
- **Scales to 50–100+ segments.** Paste them all at once; it runs them in order
  and shows per-clip progress.
- **Minimal UI.** Pick a video, paste JSON, pick an output folder, hit Cut.

<br>

## Timestamp JSON format

A JSON **array** of objects. Each object needs a `start` and either an `end` or
a `duration`. `name` is optional (used in the output filename).

```json
[
  { "name": "intro",     "start": "00:00:05",  "end": "00:00:18.500" },
  { "name": "highlight", "start": "01:12:40",  "end": "01:12:52" },
  { "name": "qa_part",   "start": "01:48:03",  "duration": 9.5 },
  { "name": "outro",     "start": 7200,        "end": 7212.25 }
]
```

**Time values** can be written either way:

| Form              | Example         | Meaning                    |
| ----------------- | --------------- | -------------------------- |
| Clock string      | `"01:12:40.250"`| 1 h 12 m 40.25 s           |
| Clock string      | `"03:08"`       | 3 m 8 s                    |
| Plain number      | `7212.25`       | 7212.25 seconds            |

Output files are named `‹source›_001_‹name›.‹ext›`, keeping the original
container/extension, e.g. `lecture_001_intro.mp4`.

See [`timestamps.example.json`](timestamps.example.json).

<br>

## Convert to MP4 (lossless)

The **Convert** tab remuxes files (e.g. `.mkv`) into `.mp4` **losslessly** — it
copies the existing video/audio streams into an MP4 container with `-c copy`, so
there's no re-encoding and no quality loss (a full movie converts in seconds).
Drop in one or many files, optionally choose an output folder (default: next to
each source), and hit Convert.

> Subtitles are dropped by default for reliability. Turn on *Keep text subtitles*
> to carry text subs across as `mov_text`. Image-based subs (PGS/VOBSUB) can't
> live in MP4 and will fail if that option is on.

<br>

## Requirements

- **macOS 13 (Ventura) or newer**
- **Xcode 16 or newer** (to build it the first time)
- **ffmpeg** — the cutting engine. Install once per Mac:
  ```sh
  brew install ffmpeg
  ```
  The app auto-detects ffmpeg at `/opt/homebrew/bin` (Apple Silicon),
  `/usr/local/bin` (Intel), or `/usr/bin`. If yours lives elsewhere, click
  **Set ffmpeg…** and point at the binary — the choice is remembered.

  > No Homebrew? Get it at <https://brew.sh>, or download a static ffmpeg from
  > <https://evermeet.cx/ffmpeg/> and select it with **Set ffmpeg…**.

<br>

## Build & run

```sh
git clone git@github.com:roman-algo/VideoSlicer.git
cd VideoSlicer
open VideoSlicer.xcodeproj
```

In Xcode press **⌘R**. The app launches. That's it.

(Lossless stream-copy makes cut points snap to the nearest keyframe — usually
within a second. If you need exactly-on-the-frame cuts, flip the
**Frame-accurate cuts (re-encode)** switch; that re-encodes, so it's slower and
not bit-identical.)

<br>

## Sharing the app across your Macs

Pick whichever fits how you work:

### Option A — Clone & build on each Mac (simplest, always works)
On every Mac: install Xcode + `brew install ffmpeg`, then
`git clone` this repo and press ⌘R once. The built app appears in Xcode's
Products and you can drag it to `/Applications`.

### Option B — Build once, copy the `.app` everywhere
1. On one Mac, in Xcode: **Product ▸ Archive ▸ Distribute App ▸ Custom ▸
   Copy App**, or just grab `VideoSlicer.app` from
   *Product ▸ Show Build Folder in Finder → Products/Debug*.
2. AirDrop / copy `VideoSlicer.app` to your other Mac and drop it in
   `/Applications`.
3. Because it isn't notarized, the first launch needs one of:
   - **Right-click the app ▸ Open ▸ Open**, *or*
   - clear the quarantine flag in Terminal:
     ```sh
     xattr -dr com.apple.quarantine /Applications/VideoSlicer.app
     ```
   Each Mac still needs `brew install ffmpeg`.

### Option C — iCloud Drive
Build once (Option B), then put `VideoSlicer.app` in
`iCloud Drive/Applications`. It syncs to your other Macs automatically; run it
from there (same first-launch/quarantine note applies).

> Options B and C share the app, not the source. Keep this GitHub repo as the
> source of truth and re-build when you change the code.

<br>

## How it works

For each segment the app runs, in order:

```sh
# lossless (default)
ffmpeg -ss <start> -i <input> -t <duration> -map 0 -c copy \
       -avoid_negative_ts make_zero <output>

# frame-accurate (optional toggle)
ffmpeg -ss <start> -i <input> -t <duration> -map 0 \
       -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 192k <output>
```

The app is not sandboxed, so it can read your source video, write to the folder
you pick, and launch ffmpeg directly.
