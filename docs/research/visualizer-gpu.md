# Visualizer GPU investigation

## Observations

- The visualizer uses one transparent, screen-wide layer surface per display. Each surface contains 72 gradient rectangles, each with an animated height. Cava emits up to 60 frames per second (`modules/visualizer/Visualizer.qml`, `modules/visualizer/cava.conf`).
- On the reported NVIDIA/Hyprland desktop, whole-GPU usage was approximately 55% with Omashell running and averaged 7% in a separate sample with Omashell stopped. These samples are not controlled enough to attribute the difference solely to the visualizer.
- Temporarily stopping Cava while music was playing did not yield a consistent large decrease in total GPU utilization.
- Controlled A/B tests using `bin/omashell` found that the full shell used roughly 47–59% GPU both with and without its visualizer, while the bar alone used 2–4%. Unmapping closed `PanelShell` windows reduced full-shell GPU usage to 7–13% in two samples. After applying the fix, the local launcher averaged 7.9% over eight samples with Cava running. This supports closed panel surfaces as the dominant issue on the tested system; results may differ by GPU, compositor, and workload.

## Relevant upstream guidance

- Qt's scene-graph renderer batches compatible primitives to reduce GPU draw calls; alpha-blended content has more ordering constraints than opaque content. Its `QSG_VISUALIZE` debugging modes can help inspect batching and overdraw. [Qt Quick Scene Graph Default Renderer](https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph-renderer.html)
- Qt recommends profiling rendering and animations rather than assuming which operation dominates; frame and timing behavior are hardware dependent. [Qt Quick performance considerations](https://doc.qt.io/qt-6/qtquick-performance.html), [Qt Creator QML Profiler](https://doc.qt.io/qtcreator/creator-qml-performance-monitor.html)
- Hyprland has documented reports of high GPU load on some NVIDIA systems even for other compositor activity; this is context, not evidence that a specific Hyprland issue causes this report. [Hyprland issue #6617](https://github.com/hyprwm/Hyprland/issues/6617)

## Candidate experiments

1. Compare the same running shell with its visualizer surface explicitly disabled versus enabled while replaying identical audio; record several samples of total and per-process GPU usage. This is a stronger isolation test than stopping Cava alone.
2. Compare a tightly sized layer surface around the bars against the current screen-wide surface. Measure compositor GPU utilization and confirm positioning on multiple displays; surface size is a hypothesis, not a demonstrated root cause.
3. Compare Cava at 30 versus 60 frames per second, and test reducing or removing per-bar animations. Animation timing can keep the compositor repainting between Cava updates, so verify actual redraws rather than assuming a 30 fps input implies 30 fps rendering.
4. Compare batching-friendly solid rectangles or a single custom-rendered visualization against the gradient implementation; use Qt's scene-graph diagnostics and GPU measurements before choosing. Preserve the existing appearance unless the performance benefit warrants a visible trade-off.
5. Keep `visualizerBarCount` and `visualizerInputRange` synchronized with `cava.conf`, and test silence, display changes, and transparent input regions after any implementation.
