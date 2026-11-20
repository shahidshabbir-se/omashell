# Throwaway visualizer GPU prototype

Question: can a narrower surface and fewer updates reduce compositor/GPU usage while retaining the 72-bar look? This is an experiment, not production code; it uses deterministic synthetic levels, not Cava.

Run on the NVIDIA/Wayland desktop:

```sh
nix-shell -p quickshell --run 'modules/visualizer/prototype/benchmark.sh'
```

The script temporarily pauses running Omashell/visualizer processes, starts one prototype at a time, samples whole-GPU utilization, and resumes the paused processes on exit. The frozen shell surfaces remain on the compositor; unrelated desktop/video activity also affects the results. Close GPU-intensive applications and avoid interacting with the desktop during measurement. Do not infer performance from one short run.

Variants:
- `baseline`: no visible prototype surface.
- `current`: full-width surface, 60 Hz inputs, 300 ms animations, gradients.
- `rate30`: current surface and animations, 30 Hz inputs.
- `compact`: bar-width surface, 60 Hz inputs and 300 ms animations.
- `optimized`: bar-width surface, 30 Hz inputs, no height animations; gradients retained.

A clean run with `omashell.service` stopped: baseline 2.6% and 3.0%; current 7.2% and 7.2%; optimized 4.4% and 5.2%; compact 5.6%; rate30 6.6%. The optimized synthetic prototype saves roughly 2–3 percentage points of whole-GPU utilization under these conditions. This does not explain the roughly 53% measured with the complete Omashell service restored: test the actual shell with its visualizer surface explicitly enabled and disabled before attributing the overall load. No production decision has been made.

Earlier runs with Omashell running are invalid: the benchmark originally matched the Linux process name, which differs for the Nix-wrapped executable, and stopped Cava without stopping the shell. The script now matches executable arguments. Even when paused correctly, a shell's frozen surfaces remain visible; stopping the service entirely is a cleaner comparison.
