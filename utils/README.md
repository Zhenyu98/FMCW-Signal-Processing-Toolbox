# utils

`utils/` only stores hardware-facing utilities and raw-data format helpers.
FFT, CFAR, DOA, point-cloud generation, imaging, tracking, and signal simulation
should stay in their own toolbox modules.

## Formal Raw Reader

Use this function for DCA1000 raw ADC bin files:

```matlab
[radar_data, adcCube, readerInfo] = readDCA1000Raw(fileName, numADCSamples, numRX, numTX);
```

Output format:

```matlab
% radar_data: (numRX*numTX) x (loopChirpNum*numADCSamples)
% adcCube: numADCSamples x loopChirpNum x (numRX*numTX)
```

The old reader scripts such as `readDCA1000_1.m`, `readDCA1000_1843.m`, and
`DCA1000_Read_Data.m` were removed from the formal toolbox path. If a reference
project needs its original reader, keep that copy under `0_refer_code/` and use
the validation scripts to compare it with `readDCA1000Raw.m`.

## mmWave Studio / DCA1000 Control

`DCA_Connet/` keeps MATLAB and Lua scripts used to connect mmWave Studio
through the RSTD interface and trigger DCA1000 capture:

```text
DCA_Connet/
    Init_RSTD_Connection.m
    mmWaveRadarInit.m
    RadarConfigure.m
    SendCaptureCMD.m
    CaptureData.m
    DCAconnect.lua
    DataCaptureDemo_1243.lua
    CaptureData1243.lua
    70.295.xml
```

These scripts are hardware-control helpers built on TI's mmWave Studio Lua
examples (MATLAB wrappers by Xuliang). They use the TI default installation
path `C:\ti\mmwave_studio_02_01_01_00` and the DCA1000 default Ethernet
settings; update both before running them on another machine.

## What Does Not Belong Here

- Radar cube generation: use `signal/RadarCubeGenerate.m`.
- Range/Doppler/angle FFT processing: use `pointcloud/` or `imaging/`.
- Temporary raw data, `.bin`, `.mat`, `.csv`, logs, manuals, and screenshots.
- One-off plotting or video conversion scripts.
