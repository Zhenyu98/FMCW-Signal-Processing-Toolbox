# Example figures

The gallery uses simulation outputs from the toolbox. No measured data, accounts, local paths, or hardware configuration screenshots are included.

| Image | Data source | Display |
| --- | --- | --- |
| `hero_pipeline.png` | Three-target simulation matching `demo_pointcloud_sim` | Range profile, range-Doppler map, and point cloud |
| `gallery_range_azimuth.png` | `pointcloud/demo_pointcloud_ra_sim.m` | Normalized linear amplitude on the actual nonuniform angle grid, plus detections and truth |
| `gallery_human_motion.png` | `signal/demo_human_motion_radar_echo.m` | Three separate oblique views of body-centered poses, translucent schematic body shapes, actual scattering centers, and relative spectral magnitude in dB |
| `gallery_tracking.png` | `validation/validate_tracking_pointcloud_integration.m` | Local views of each target; raw detections, EKF state history, and ground truth |

Regenerate the three gallery images from the repository root:

```matlab
run('docs/generate_readme_gallery.m')
```

The script calls existing demos without changing their parameters or algorithm outputs. It changes only layout, colors, labels, normalization for display, and axis limits. Ground truth is used to match tracks to panels, not by the estimator. The tracking panels show detections within 1 m of each true trajectory's mean position; axes zoom in on those trajectories. No trajectory smoothing is applied for display.

The demos clear the workspace and close figures. Save existing work before running them. Images are exported at 160 dpi with English labels for use by both README versions. The script does not regenerate the existing hero image.

The human panels center each pose horizontally on the body position and use the same scale and camera angle. Translucent body shapes are schematic visual aids; the gold markers are the original scattering centers. The body surfaces are not added to the radar model. The underlying simulated echo and micro-Doppler values are unchanged by this presentation.

## Algorithm gallery

Run `run('docs/generate_algorithm_gallery.m')` from the repository root. This script calls existing toolbox implementations and checks numerical criteria before exporting:

| Image | Tools and input | Display and scope |
| --- | --- | --- |
| `gallery_doa_source_count.png` | `DOA_FFT`, `DOA_MUSIC`, `DOA_IAA`, `Newton_NOS`; 12 sensors, 128 snapshots, 15 dB SNR, seed 2026 | Shared noisy observation; independently normalized spatial spectra and sorted covariance eigenvalues. MUSIC uses the estimated source count. Fixed scene, no performance ranking. |
| `gallery_doppler_time.png` | `RadarCubeGenerate`, `DTM`; 40 frames, 80 ms interval, 25 dB SNR | Range-FFT amplitude and DTM amplitude, both normalized globally; prescribed motion in white. Velocity is constant within each frame. |
| `gallery_two_ray.png` | Existing `validate_mathworks_two_ray_signal_source` | Deliberately resolvable propagation geometry and the computed range spectrum, with expected peak positions. |
| `gallery_doa_bounds.png` | Unmodified `Main_ZZB_Demo` and `ZZB_DOAs`, seed 2026 | Original 20 sensors, 5 sources, 40 snapshots, 1000 random angle draws; averaged root bounds, not estimator errors. Original attribution retained in source files. |

Additional dependencies: Radar Toolbox for the two-ray source; Statistics and Machine Learning Toolbox (`unifrnd`) and Communications Toolbox (`qfunc`) for the performance-bound demo. The source-count script uses the existing Newton threshold of 1 for this scenario. It does not validate all legacy source-number comparison scripts or all DOA branches.
