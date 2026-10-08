# Admin lava animation: local performance check

Date: 2026-10-07. Chrome 154, Flutter web profile mode, `/login`, local macOS computer. The tab was brought to the foreground. No application behavior or animation settings were changed.

Six samples, eight seconds per sample after 1.5 seconds of warmup. Desktop viewport: 1440 × 900, DPR 2. Mobile viewport: 402 × 874, DPR 3. CPU throttling: 1×, 4×, 6×. Settings restored after measurements.

| Layout | CPU slowdown | rAF callbacks/s | p95 callback interval | Intervals >33.4 ms | Long tasks | Main thread busy |
|---|---:|---:|---:|---:|---:|---:|
| desktop | 1× | 120.0 | 9.2 ms | 0 | 0 | 25.8% |
| desktop | 4× | 120.0 | 9.2 ms | 0 | 0 | 46.0% |
| desktop | 6× | 119.7 | 9.2 ms | 0 | 0 | 53.8% |
| mobile | 1× | 120.0 | 9.3 ms | 0 | 0 | 28.1% |
| mobile | 4× | 120.0 | 9.2 ms | 0 | 0 | 29.2% |
| mobile | 6× | 119.8 | 9.1 ms | 0 | 0 | 40.5% |

The callback cadence stayed close to 120 Hz in all samples, with no intervals longer than 33.4 ms and no observed long tasks (tasks lasting at least 50 ms). This provides evidence against main-thread stalls under the tested CPU throttling. Main-thread busy percentage is the delta in CDP Performance TaskDuration divided by sample duration and measures the whole page, including the measurement code; it does not isolate animation cost.

These are browser requestAnimationFrame callback timings, not measured Flutter rendered FPS or GPU presentation times. CPU throttling does not emulate a weaker GPU, device thermal throttling, battery use, native Flutter rendering, or sustained load. Eight-second samples do not prove long-term stability or absence of memory leaks. Heap sizes fluctuate with garbage collection and are retained in the JSON only as diagnostic data.

The four tests in `apps/admin/test/admin_lava_panel_test.dart` also passed, including shader loading/painting, lifecycle pause/resume/disposal, reduced motion, and invitation layouts with a mobile keyboard.

The implementation limits the field to twelve bubbles, repaints only its CustomPaint region rather than rebuilding the form every frame, and stops the ticker when the app is not resumed, reduced motion is enabled, or TickerMode is disabled. The shader still evaluates the full animated panel per frame; a large high-DPR desktop viewport can therefore cost GPU time even when the Dart main thread is responsive.

No performance-driven visual changes are justified by these measurements. A physical lower-end Android device, in a profile/release build, remains necessary to check actual GPU frame times and sustained responsiveness.
