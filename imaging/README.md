# imaging

FMCW radar imaging module.

Range-Doppler map:

```matlab
[dopplerFFTOut, range_axis, velocity_axis] = RDM(data, sensorParams, true);
```

Range-Angle map:

```matlab
[RangeAngleFFT, range_axis, angle_axis] = RAM(data, sensorParams, 180, true);
```

Doppler-Time map (per-frame Doppler for FRAMED data, one Doppler snapshot per frame):

```matlab
% data: [Sample x ChirpPerFrame x FrameNum] or [Sample x ChirpPerFrame x Array x FrameNum]
[DopplerTimeMap, velocity_axis, time_axis] = DTM(data, sensorParams, true);
```

Micro-Doppler spectrogram (CONTINUOUS capture; slow-time STFT on the strongest range bin):

```matlab
[MicroDopplerSpec, velocity_axis, time_axis] = MDS(data, sensorParams, true);
```

SAR / BP demos:

```matlab
demo_rma_imaging_2d
demo_bp_imaging_2d
```
