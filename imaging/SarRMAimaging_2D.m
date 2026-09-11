function [rawData,sarImage,xRangeT,yRangeT] = SarRMAimaging_2D(filespath,sensorParams,sarParams,targetDist,Flag)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2023 Southwest University, Chongqing
% College of Electronic and Information Engineering
% Any way use this code for research must retain the above copyright notice
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Advisor             : Prof. Chuandong Li
% Subprogram name     : SarRMAimaging_2D.m                  
% Date & time         : Oct. 13 2023 14:15                    
% Version             : 1.0                                   
% Purpose             : 2D-RMA imaging from raw echo data file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% -------------------------------------------------------------------------
%                              Introduction 
% -------------------------------------------------------------------------
% This program provides a SAR RMA_2D imaging for the raw data of
% development board of Texas Instruments (IWR 1642)
% -------------------------------------------------------------------------
%                                Variables
% -------------------------------------------------------------------------
% filespath: the path of the data
% e.x., filespath = 'D:\Data\RadarRawData\Radardata.csv';
% data format should be a csv including the two-dimensional array, the row 
% entries are fast time data and column entries are slow time data. 
% -------------------------------------------------------------------------
% sensorParams: a struct including the following parameters of sensor
%          Exmaple                                      Remark
% sensorParams.TxNum = 2;                   nummber of transmitting antenna
% sensorParams.RxNum = 4;                      nummber of receiving antenna
% sensorParams.Start_Freq_GHz = 77;                starting frequency (GHz)
% sensorParams.Slope_MHzperus = 3.04;                 slope of LFM (MHz/us)
% sensorParams.Sampling_Rate_ksps = 5000;       sampling rate of ADC (ksps)
% sensorParams.Adc_Start_Time_us = 4.66;       Adc sampling start time (us)
% sensorParams.Frame_Repetition_Period_ms= 80; Frame repetition period (ms)
% sensorParams.Samples_per_Chirp = 256;       Samples nummber of each chirp
% -------------------------------------------------------------------------
% sensorParams: a struct including the following parameters of SAR
%          Exmaple                                      Remark
% sarParams.RowSampleNum = 21;                  row scanning numbers of SAR 
% sarParams.Horizontal_stepSize_mm = 1; stepsize of horizontal antennas(dx)
% sarParams.Vertical_stepSize_mm = 2;      stepsize of vertical antenna(dy)
% dx, dy of SAR are usually set by half wave length of LFM 
% -------------------------------------------------------------------------
% targetDist: distance of target in mm
% -------------------------------------------------------------------------
% Flag: a vector inluding two boolean variables used in data processing
% e.x., Flag = [IsFFTpre imgFisrt IsPlot]; 
% If raw data has been Fourier transformed, IsFFTpre = true
% raw data is imaginary part is in front of the real part, imgFisrt = true
% If need generate image, IsPlot = true 
% -------------------------------------------------------------------------
%                                Outputs
% -------------------------------------------------------------------------
% rawData: th processed date from csv file
% matsize: Samples x ScanRowNum x (AntennaNums*RowSampleNum)
% sarImage: the image matrix by RMA_2D 
% xRangeT: the x axis of sarImage
% yRangeT: the y asis of sarImage

%% Setting default parameters
if (nargin < 5)
    IsFFTpre = false;
    imgFisrt = false;
    IsPlot = true;
else
    IsFFTpre = Flag(1);
    imgFisrt = Flag(2);
    IsPlot = Flag(3);
    IsReverseData = Flag(4);
    clear Flag
end

%% Define parameters, update based on the scenario

nSample = sensorParams.Samples_per_Chirp;   % Samples per Chirp
f0 = sensorParams.Start_Freq_GHz*1e9;
K = sensorParams.Slope_MHzperus*1e12;
fS = sensorParams.Sampling_Rate_ksps*1e3; % Sampling rate (sps)
TS = 1/fS;          % Sampling period
B = K*TS*nSample;           % 带宽 per Sampling
Zoom =4;
TxNum = sensorParams.TxNum; RxNum = sensorParams.RxNum;
RowSampleNum = sarParams.RowSampleNum; % The sampled number of each row
DFTpiont = sensorParams.Samples_per_Chirp; % The piont number of discrete Fourier transformation

TxRxNum = [TxNum RxNum];  Flag = [IsFFTpre imgFisrt IsReverseData];

nFFTtime = nSample*Zoom;    % Number of FFT points for Range-FFT
z0 = targetDist*1e-3;                         % Range of target (range of corresponding image slice)
dx = sarParams.Horizontal_stepSize_mm;        % Sampling distance at x (horizontal) axis in mm
dy = sarParams.Vertical_stepSize_mm;          % Sampling distance at y (vertical) axis in mm
imSize = sarParams.imSize;
%% Fixed parameters for all scenarios
c = physconst('lightspeed');
tI = 4.5225e-10; % Instrument delay for range calibration (corresponds to a 6.78cm range offset)
fif = f0+K*2*z0/c;
lambda = fif/c;

%% Read data from the raw file
rawData = rdata(filespath,RowSampleNum,DFTpiont,TxRxNum,Flag);

%% Take Range-FFT of rawData3D
rawDataFFT = fft(rawData,nFFTtime); %对距离维FFT
if IsPlot
    dr = c/2/B;
    L = 1:nFFTtime;
    range = dr*(L-B*tI)/Zoom;
    [~,row,col] = size(rawData);
    b=[]; b(1,:) = rawDataFFT(:,ceil(row/2),ceil(col/2));
    figure;  bar(z0,max(abs(b)),'BarWidth',0.3,'FaceAlpha',0.5); hold on;
    plot(range,abs(b),'LineWidth',1.5);
    legend('Target Area','Amplitude Spectrum');
    xlabel('Range/m'); ylabel('Amplitude of Echo');
    xlim([0 max(range)]);
    title("Echo Strength and Range")
end

%% Range focusing to z0
k = round(K*TS*(2*z0/c+tI)*nFFTtime); % corresponing range bin 根据距离算出取哪一张
sarData = squeeze(rawDataFFT(k+1,:,:)); 
matchedFilter = createMatchedFilterSimplified(77*4,dx,100,dy,z0*1e3,lambda);
[sarImage,xRangeT,yRangeT] = reconstructSARimageMatchedFilterSimplified(sarData,matchedFilter,dx,dy,imSize);

%% Plot SAR Image
if IsPlot
    figure; mesh(xRangeT,yRangeT,abs(fliplr(sarImage)),'FaceColor','interp','LineStyle','none')
    view(2)
    % colormap('jet');
    colormap('gray');
    xlabel('Horizontal (mm)')
    ylabel('Vertical (mm)')
    titleFigure = "SAR 2D Image - " + targetDist + "mm Focused";
    title(titleFigure)

    % MinmaxSarImage= (max(max(sarImage))-sarImage)/(max(max(sarImage))-min(min(sarImage)));
    % sarImageAbsLog = mag2db(abs(squeeze(MinmaxSarImage))); % 20*log10
    % sarImageAbsLog = sarImageAbsLog - max(max(sarImageAbsLog));
    GraySarImage = flip(mat2gray(abs(fliplr(sarImage))));
    sarImage_imadjust= imadjust(GraySarImage);
    sarImage_adapthisteq = adapthisteq(GraySarImage);
    figure;
    montage({GraySarImage,sarImage_imadjust,sarImage_adapthisteq},"Size",[1 3])
    title("Original Image and Enhanced Images using imadjust, and adapthisteq")
end

end




function  outdata = rdata(filespath,RowSampleNum,DFTpiont,TxRxNum,Flag)
IsReverseData = Flag(3);
raw_data = csvread(filespath);      %matsize: (ScanRowNum*RowSampleNum)x(2*NumTx*NumRx(AntennaNums)*DFTpiont+2) ex.,3200*2050
raw_data = raw_data(:,3:end);   %Remove the first two headers, matsize:1659*2048
%2*NumTx*AntennaNums(NumRx)*DFTpiont == the colNum of raw_data (ex., 2*2*4*128=2048 / 2*1*4*256=2048)

[row,~] = size(raw_data);
raw_data = raw_data';             %2048*3200

raw_data = raw_data(:,1:row-mod(row,RowSampleNum)); % Adaptive column, i.e., remove the incompletely sampled row

raw_data = IQmerge(raw_data,RowSampleNum,DFTpiont,TxRxNum,Flag); %Combine the I signal and the Q singanl as a complex signal
if IsReverseData
    outdata = ReverseData(raw_data); %Reverse the even number line of the signal
else
    outdata = raw_data;
end

end

function [data3D] = IQmerge(raw_data,RowSampleNum,DFTpiont,TxRxNum,Flag)
%% Define Parameters
if (nargin < 5)
    IsFFTpre = false;
    imgFisrt = true;
else
    IsFFTpre = Flag(1);
    imgFisrt = Flag(2);
end

TxNum = TxRxNum(1); RxNum = TxRxNum(2);
VirtualAntennaNum = TxNum*RxNum;
[row,col] = size(raw_data); %the col size means total sample times
if row ~= VirtualAntennaNum*DFTpiont*2
    error('error: Plese check the DFTpiont or TxRxNum, the rowNum of rawdate should be equal to TxNum*RxNum*DFTpiont*2');
end
RowNumSAR = col/RowSampleNum;

%% The Rx antennas are converted to a complex number
Antenna = raw_data;
AntennaComplex = zeros(row/2,col);
for cindex = 1 : col
    for rindex = 1 : DFTpiont*VirtualAntennaNum
        if imgFisrt 
            AntennaComplex(rindex,cindex) = Antenna(2*rindex,cindex)+1i*Antenna(2*rindex-1,cindex);
        else
            AntennaComplex(rindex,cindex) = 1i*Antenna(2*rindex,cindex)+Antenna(2*rindex-1,cindex);
        end
    end
end

% NOW AntennaComplex format: (TxNum*RxNum*DFTpiont)*(RowSampleNum*RowNum) (2*4*128 * 32*100)
%% iFFT
if IsFFTpre
    for AntennaNum = 1:VirtualAntennaNum
        AntennaStar = DFTpiont*(AntennaNum-1)+1;
        AntennaEnd= DFTpiont*AntennaNum;
        AntennaComplex(AntennaStar:AntennaEnd,:) = ifft(AntennaComplex(AntennaStar:AntennaEnd,:),[],1);
    end
end

%% Matrix reconstruction

  AntennaData = zeros(DFTpiont,RowNumSAR,RowSampleNum*VirtualAntennaNum);
  for RowNum = 1:RowNumSAR
      for RowSampleIndex=1:RowSampleNum
          for AntennaNum = 1:VirtualAntennaNum
              AntennaStar = DFTpiont*(AntennaNum-1)+1; AntennaEnd= DFTpiont*AntennaNum;
              AntennaData(:,RowNum,VirtualAntennaNum*(RowSampleIndex-1)+AntennaNum) = AntennaComplex(AntennaStar:AntennaEnd,(RowNum-1)*RowSampleNum+RowSampleIndex);
          end
      end
  end

data3D = AntennaData;
% AntennasData format:  RowNum*ColNum*DFTpiont, ColNum == RowSampleNum*NumRx; (100*128*256) 
% RowNum\ColNum is row or col numbers of face szie of SAR 
end

%% ReverseData
function outdata = ReverseData(ReceivedData)
[Samples,RowNum,ColNum] = size(ReceivedData);
outdata = zeros(Samples,RowNum,ColNum);
        for RowNumindex = 1 : RowNum
            if rem(RowNumindex,2) == 0 %if RowNum is even number
                outdata(:,RowNumindex,:) = fliplr(squeeze(ReceivedData(:,RowNumindex,:))); %Reverse the even sequence of ReceivedData
            else
                outdata(:,RowNumindex,:) = ReceivedData(:,RowNumindex,:);
            end
        end
end

function matchedFilter = createMatchedFilterSimplified(xPointM,xStepM,yPointM,yStepM,zTarget,lambda)
% Example function calls, see details below
% -------------------------------------------------------------------------
% Matched filter for Tx0-Rx0 antenna pair with monostatic assumption
% matchedFilter = createMatchedFilterSimplified(512,200/406,512,2,400)

% Coordinate system
% -------------------------------------------------------------------------
% x is the Horizontal axis
% y is the Vertical axis
% z is the Depth axis

% Variables
% -------------------------------------------------------------------------
% This code creates Matched Filter for the following scenario:
% xPointM: number of measurement points at x (horizontal) axis
% xStepM: Sampling distance at x (horizontal) axis in mm
% yPointM: number of measurement points at y (vertical) axis
% yStepM: Sampling distance at y (vertical) axis in mm
% zTarget: z distance of target in mm


%-------------------------------------------------------------------------%
% Define Measurement Locations at Linear Rail
% Coordinates: [x y z], x-Horizontal, y-Vertical, z-Depth
%-------------------------------------------------------------------------%
x = xStepM * (-(xPointM-1)/2 : (xPointM-1)/2) * 1e-3; % xStepM is in mm
y = (yStepM * (-(yPointM-1)/2 : (yPointM-1)/2) * 1e-3).'; % yStepM is in mm

%-------------------------------------------------------------------------%
% Define Target Locations
% Coordinates: [x y z], x-Horizontal, y-Vertical, z-Depth
%-------------------------------------------------------------------------%
z0 = zTarget*1e-3; % zTarget is in mm
R = sqrt(x.^2 + y.^2 + z0^2);
%--------------------------------------------------------------------------
% Create Single Tone Matched Filter
%--------------------------------------------------------------------------
k = 2*pi*lambda;
matchedFilter = exp(-1i*2*k*R);
end

function [sarImage,xRangeT,yRangeT] = reconstructSARimageMatchedFilterSimplified(sarData,matchedFilter,xStepM,yStepM,imSize)
% Example function calls, see details below
% -------------------------------------------------------------------------
% sarImage = reconstructSARimageMatchedFilterSimplified(sarData,matchedFilter,200/406,2,200);

% Variables
% -------------------------------------------------------------------------
% This code creates SAR Image for the following scenario:
% sarData: nVertical x nHorizontal 2-D SAR Data
% matchedFilter: nVertical x nHorizontal 2-D Matched Filter
% xStepM: measurement step size at x (horizontal) axis in mm (only used for data display)
% yStepM: measurement step size at y (vertical) axis in mm (only used for data display)
% xySizeT: Target size in mm (only used for data display)
% -------------------------------------------------------------------------

%% sarData should be in following format
% yPointM x xPointM
[yPointM,xPointM] = size(sarData);
[yPointF,xPointF] = size(matchedFilter);


%% Equalize Dimensions of sarData and Matched Filter with Zero Padding
if (xPointF > xPointM)
    sarData = padarray(sarData,[0 floor((xPointF-xPointM)/2)],0,'pre');
    sarData = padarray(sarData,[0 ceil((xPointF-xPointM)/2)],0,'post');
else  
    matchedFilter = padarray(matchedFilter,[0 floor((xPointM-xPointF)/2)],0,'pre');
    matchedFilter = padarray(matchedFilter,[0 ceil((xPointM-xPointF)/2)],0,'post');
end

if (yPointF > yPointM)
    sarData = padarray(sarData,[floor((yPointF-yPointM)/2) 0],0,'pre');
    sarData = padarray(sarData,[ceil((yPointF-yPointM)/2) 0],0,'post');
else  
    matchedFilter = padarray(matchedFilter,[floor((yPointM-yPointF)/2) 0],0,'pre');
    matchedFilter = padarray(matchedFilter,[ceil((yPointM-yPointF)/2) 0],0,'post');
end

%% Create SAR Image
sarDataFFT = fft2(sarData,512,256); %sardata 2D-FFT
matchedFilterFFT = fft2(matchedFilter,512,256);%这里没有用 POST 定理
sarImage = fftshift(ifft2(sarDataFFT .* matchedFilterFFT));
% sarImage = fftshift(ifft2(sarDataFFT));

%% Define Target Axis
[yPointT,xPointT] = size(sarImage);
xRangeT = xStepM * (-(xPointT-1)/2 : (xPointT-1)/2); % xStepM is in mm
yRangeT = yStepM * (-(yPointT-1)/2 : (yPointT-1)/2); % yStepM is in mm

%% Crop the Image for Related Region
indXpartT = xRangeT>(-imSize/2) & xRangeT<(imSize/2);
indYpartT = yRangeT>(-imSize/2) & yRangeT<(imSize/2);

xRangeT = xRangeT(indXpartT);
yRangeT = yRangeT(indYpartT);
sarImage = sarImage(indYpartT,indXpartT);

end