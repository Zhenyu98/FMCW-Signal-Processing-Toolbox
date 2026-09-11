function [data,Matrix_Imag] = RAM_BPimaging(filespath,sensorParams,sarParams,imgCut,Flag)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2024 Southwest University, Chongqing
% College of Electronic and Information Engineering
% Any way use this code for research must retain the above copyright notice
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu         (feedback email:zheny_wu@163.com)
% Advisor             : Prof. Chuandong Li
% Code name           : main.m
% Date & time         : Mar. 04 2024 10:15
% Version             : 2.0
% Purpose             : 2D-BP imaging from raw echo data file
% Feature             : 1. four mode of BP can be choosed, including .. 
% --------------------- original BP (mode 1, 2), fast BP (mode 3, 4)
% --------------------- 2. GPU acceleration 3. whole raw data processing 
% --------------------- 4. sinc interpolation and its alternative
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% -------------------------------------------------------------------------
%                              Introduction
% -------------------------------------------------------------------------
% This program provides a guide for RAM_BPimaging.m
% GB-SAR BP imaging for the raw data of development board of
% Texas Instruments (IWR 1642)
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
% Flag: a vector inluding boolean variables used in processing
% e.x., Flag = [IsFFTpre imgFisrt IsPlot];
% If raw data has been Fourier transformed, IsFFTpre = true
% raw data is imaginary part is in front of the real part, imgFisrt = true
% If need generate image, IsPlot = true
% -------------------------------------------------------------------------
%                                  Outputs
% -------------------------------------------------------------------------
% rawData: the processed date from csv file
% format: Samples x ScanRowNum x (AntennaNums*RowSampleNum)
% sarImage: the image matrix by RMA_2D
% xRangeT: the x axis of sarImage
% yRangeT: the y asis of sarImage
% -------------------------------------------------------------------------
%                                  Thanks
% -------------------------------------------------------------------------
% This program is supported by experimental data from Chongqing Qinzhi
% Technology Co., Ltd.
% And thanks to Tingkai Hu for his constructive suggestions.

%% Setting default parameters
if (nargin < 4)
    IsFFTpre = false;
    imgFisrt = false;
    IsPlot = true;
    IsReverseData = true;
else
    IsFFTpre = Flag(1);
    imgFisrt = Flag(2);
    IsPlot = Flag(3);
    IsReverseData = Flag(4);
    clear Flag
end

%% Define parameters, update based on the scenario

nSample = sensorParams.Samples_per_Chirp;       % Samples per chirp
f0 = sensorParams.Start_Freq_GHz*1e9;
K = sensorParams.Slope_MHzperus*1e12;
fS = sensorParams.Sampling_Rate_ksps*1e3;       % Sampling rate (sps)
TS = 1/fS;                                      % Sampling period
B = K*TS*(nSample-1);                           % Band for a chrip
% Number of DFT points for Range-FFT
nFFTtime = nSample; 

TxNum = sensorParams.TxNum; RxNum = sensorParams.RxNum;
% The sampled number of each row
RowSampleNum = sarParams.RowSampleNum; 
% The piont number of discrete Fourier transformation
DFTpiont = sensorParams.Samples_per_Chirp; 

TxRxNum = [TxNum RxNum];  Flag = [IsFFTpre imgFisrt IsReverseData];

L = imgCut(1);
dL = imgCut(2);
rangeNear = imgCut(3);
rangeFar = imgCut(4);

% Sampling distance at x (horizontal) axis in mm
dx = sarParams.Horizontal_stepSize_mm;        

%% Fixed parameters for all scenarios
c = physconst('lightspeed');
rmax = c*fS/(K*2)
dr = c/2/B

%% Read data from the raw file
rawData = rdata(filespath,RowSampleNum,DFTpiont,TxRxNum,Flag);
data = squeeze(rawData);



%% SAR parameters
% parameters of SAR
PulseNum = RowSampleNum;     % Pulse number of each row or col
ArrayNum = PulseNum*RxNum*TxNum;
SARlength = (ArrayNum-1)*dx*1e-3; % SAR samples' length (m)

% axis parameters
Azimuth = linspace(-SARlength/2,SARlength/2,ArrayNum); % Azimuth axis
range = dr*(1:nSample); % Range axis
f = linspace(f0,f0+B,nSample);

x = linspace(-L,L,dL);                       
y = linspace(rangeNear,rangeFar,dL);

%% BP algorithms
mode = input('Enter a BP mode: ');

h = waitbar(0,'正在BP计算');
tic
switch mode
    case 1
        % traditional BP
        disp('traditional BP running')
        lenX = length(x);
        lenY = length(y);
        lenAzimuth = length(Azimuth);
        lenRange = length(range);

        Matrix_Imag=zeros(lenX,lenY);

        parfor ix = 1:lenX % 目标网格下的方位坐标
            for iy = 1:lenY % 目标网格下的距离坐标
                Imag_temp = 0;
                for ia = 1:lenAzimuth % 循环方位向
                    for ir = 1:lenRange % 循环距离向
                        R = sqrt((Azimuth(ia)-x(ix))^2+(y(iy))^2); % 各阵元与目标的实际距离
                        img = data(ir,ia)*exp(-4j*pi*R*f(ir)/c); % 相位补偿
                        Imag_temp = Imag_temp + img;  % 对距离和方向维做积分
                    end
                end
                Matrix_Imag(ix,iy) = Imag_temp;
            end
            waitbar(ix/length(lenX));
        end
        close(h);                                                  % 关闭进度条



    % case 2
    %     % traditional BP by matrix operations
    %     disp('traditional BP by matrix operations ')
    %     % 预先计算长度
    %     lenAzimuth = length(Azimuth);
    %     lenRange = length(range);
    %     % 预分配结果矩阵
    %     Matrix_Imag = zeros(length(x), length(y));
    % 
    %     % 使用 meshgrid 生成二维网格，以便于向量化计算
    %     [X, Y] = meshgrid(x, y);
    % 
    %     for ia = 1:lenAzimuth
    %         for ir = 1:lenRange
    %             % 使用网格计算 R
    %             R = sqrt((Azimuth(ia)-X).^2 + Y.^2);
    %             img = data(ir, ia) * exp(-4j * pi * R * f(ir) / c);
    %             Matrix_Imag = Matrix_Imag + img.';
    %         end
    %         waitbar(ia/lenAzimuth, h, 'traditional BP running with matrix operations...');
    %     end
    %     close(h);


    case 3
        % FAST BP with SincInterp (FAST VERSION)
        disp('FAST BP with SincInterp')
        IsGPU = 0;
        fx = (0:nSample-1)/(nSample)*fS;
        
        lenX = length(x);
        lenY = length(y);
        lenAzimuth = length(Azimuth);
        [X_grid, Y_grid] = meshgrid(x, y); % 创建 X 和 Y 的网格

        % Range-FFT & add hamming window
        DataFFT = RangePro(data,nFFTtime,ArrayNum);

        % GPU algorithm acceleration
        if IsGPU
            X_grid = gpuArray(X_grid);
            Y_grid = gpuArray(Y_grid);
            DataFFT = gpuArray(DataFFT);
            K = gpuArray(K);
            fx = gpuArray(fx);
            dr = gpuArray(dr);
            f0 = gpuArray(f0);
            c = gpuArray(c);
            nFFTtime = gpuArray(nFFTtime);
            output = gpuArray.zeros(lenY,lenX);
            Matrix_Imag = gpuArray.zeros(lenX, lenY);
        else
            % 创建一个与 R 同样大小的输出矩阵
            output = zeros(lenY,lenX);
            % 预分配结果矩阵
            Matrix_Imag = zeros(lenX, lenY);
        end

        for ia = 1:lenAzimuth
            R = sqrt((Azimuth(ia) - X_grid).^2 + Y_grid.^2); % 向量化计算距离
            Rp = ceil(R/dr)+1;% 映射为频点

            % %  距离向的插值
            out = sincInterpVec(DataFFT(:,ia).',fx,K*(2*R/c));

            % 仅对有效索引赋值
            validIndex = Rp <= nFFTtime; %最大探测条件内
            output(validIndex) = out(validIndex);

            img = output.* exp(-4j*pi*f0*R/c); % 向量化相位补偿
            Matrix_Imag = Matrix_Imag + img.'; % 累加结果
            waitbar(ia/lenAzimuth, h, 'FAST BP running with sinc interp...');
        end
        close(h);
   

    case 4
        % FAST BP
        disp('FAST BP running without sinc interp ')
        lenX = length(x);
        lenY = length(y);
        lenAzimuth = length(Azimuth);
        [X_grid, Y_grid] = meshgrid(x, y); % 创建 X 和 Y 的网格

        % Range-FFT & add hamming window
        DataFFT = RangePro(data,nFFTtime,ArrayNum);

        % 创建一个与 Rp 同样大小的输出矩阵
        output = zeros(lenY,lenX);

        % 预分配结果矩阵
        Matrix_Imag = zeros(lenX, lenY);

        for ia = 1:lenAzimuth
            R = sqrt((Azimuth(ia) - X_grid).^2 + Y_grid.^2); % 向量化计算距离
            % img = sinc_interp_vectorized(DataFFT(:,ia), fx, K*(2*R/c), 11, 1);
            atendata = DataFFT(:,ia);
            Rp = ceil(R/dr)+1;
            % 检查索引是否在 img 的大小范围内
            validIndex = Rp <= nFFTtime;

            % 仅对有效索引赋值
            output(validIndex) = atendata(Rp(validIndex));

            img = output .* exp(-4j*pi*f0*R/c); % 向量化相位补偿
            Matrix_Imag = Matrix_Imag + img.'; % 累加结果
            waitbar(ia/lenAzimuth);
        end
        close(h);

    case 5
    % BP with Beamforming
    disp('BP with Beamforming running')

    lenX = length(x);
    lenY = length(y);
    lenAzimuth = length(Azimuth);
    lenRange = length(range);
    
    % 初始化成像矩阵
    Matrix_Imag=zeros(lenX,lenY);

    % 定义波束形成权重
    theta_steering = 15; % 方向角 (可以动态调整)
    wavelength = c / mean(f); % 计算波长
    d = wavelength / 2; % 假设天线间距为 λ/2
    w = exp(-1j * (2 * pi * d / wavelength) * (0:lenAzimuth-1)' * sind(theta_steering)); % 计算权重
    
    parfor ix = 1:lenX % 目标网格的 X 坐标
        for iy = 1:lenY % 目标网格的 Y 坐标
            Imag_temp = 0;
            
            % 计算每个目标点的方位角增益
            for ia = 1:lenAzimuth % 角度维度 (Azimuth)
                for ir = 1:lenRange % 距离维度 (Range)
                    R = sqrt((Azimuth(ia)-x(ix))^2 + y(iy)^2); % 计算目标到各阵元的真实距离
                    
                    % 波束形成加权处理
                    img = data(ir,ia) * exp(-4j*pi*R*f(ir)/c) * w(ia); % 相位补偿 + 方向加权
                    
                    Imag_temp = Imag_temp + img; % 累积积分
                end
            end
            Matrix_Imag(ix,iy) = Imag_temp;
        end
        waitbar(ix/lenX);
    end



    otherwise
        error("mode please choose 1,2,3,4,5");
end
toc

%% Plot
if IsPlot
figure
h = surf(abs(Matrix_Imag));
shading interp; 
set(h, 'EdgeColor', 'none');
colorbar; % 添加colorbar
set(gca,'YDir','normal');
title('BP Range-Azimuth Imaging For mmWave Radar');
xlabel('方位向'); ylabel('距离向');

figure;pcolor(x,y,abs(Matrix_Imag)');   
shading interp;
colorbar; % 添加colorbar
set(gca,'YDir','normal');
title('BP Range-Azimuth Imaging For mmWave Radar');
xlabel('方位向');ylabel('距离向');
axis equal;

figure
contour(x,y,abs(Matrix_Imag)',15);
set(gca,'YDir','normal');
title('BP Range-Azimuth Imaging For mmWave Radar');
xlabel('方位向');ylabel('距离向');
axis equal;

% Convert to dB
Matrix_Imag_dB = 20*log10(abs(Matrix_Imag) + eps); % 添加eps防止对0取对数

% PLOT FIG in dB with colorbar
figure
h = surf(abs(Matrix_Imag_dB));
shading interp; 
set(h, 'EdgeColor', 'none');
colorbar; % 添加colorbar
cb.Label.String = 'dB'; % 设置colorbar的标签为dB
set(gca,'YDir','normal');
title('BP Range-Azimuth Imaging For mmWave Radar in dB');
xlabel('方位向'); ylabel('距离向');
end
end



%% Rread raw data
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


%% I&Q signal merge
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


%% Range Processing
function DataRemoveDC = RangePro(data,nFFTtime,ArrayNum)
% 生成汉明窗，长度与信号的列数相匹配
window = hamming(nFFTtime);
windowMatrix = repmat(window, 1, ArrayNum);
datawin = data .* windowMatrix;

DataFFT = fft(datawin,nFFTtime,1);

% Remove DC Term
% static filter
DataRemoveDC = zeros(nFFTtime,ArrayNum);
avg = sum(DataFFT,2)/ArrayNum; % average range vector (slow time)
% If target is static (i,e, DC term), abs(avg) is very big
% If target is not static in slow time np, abs(avg) is very small
for l=1:ArrayNum
    DataRemoveDC(:,l) = DataFFT(:,l)-avg;
end
end


%% Sinc Interpolation
function [out,x_out] = sinc_interp(in,x_in,x_new,N,win)
%
% sinc_interp
%
% Sinc-based (band-limited)interpolation.
%
% INPUTS
% in = data sequence to be interpolated
% x_in = vector of sample locations corresponding to data samples of 'in'.
% Must be uniformly spaced at some interval dx_in. Must be same
% length as 'in'.
% x_new = vector of desired sample locations. Must be uniformly spaced at
% some interval dx_out.
% N = order of interpolating sinc, in units of max(dx_in,dx_out).
% Must be odd.
% win = 1 if Hamming window applied to interpolation kernel, otherwise no
% window. (win=1 is recommended.)
%
% OUTPUTS
% out = interpolated data sequence corresponding to sample locations in
% x_out.
% x_out = sample locations of output vector. This will be a subset of the
% locations in x_new; relative span of x_new and x_in, and filter
% end effects, may limit x_out to not include some of the values in
% x_new.
%
% Mark A. Richards
% February 2007
if (mod(N,2) ~= 1)
    disp(' ')
    disp(' ** Error: sinc_interp : filter order not odd.')
    disp([' ** Filter order input = ',int2str(N)])
    disp(' ')
    return
end
Nhalf = (N-1)/2;
d_in = x_in(2) - x_in(1);
% d_out = x_new(2) - x_new(1);
% Now figure out interpolating filter impulse response in continuous time.
% This will be a sinc function, possibly windowed. Bandwidth of the sinc
% LPF frequency response is based on the larger sampling interval of the
% two grids. Specifically, the unwindowed impulse response is h(x) =
% sin(pi*x/del)/(pi*x) and dt = max(dt1,dt2). To add to this, we specify
% how many sample increments we will go out on the tails, where 1 increment
% is dt; and then we also apply a hamming window of the same length. The
% Hamming formula in continuous time is w(t) = 0.54 + 0.46*cos(pi*t/dt).
% del = max(d_in,d_out);
del=d_in;
% find the values within x_new that can be successfully interpolated from the
% values available in x_in, i.e. where end effects won't kill us.
% x_in
% x_new
% Nhalf
% x_new(1)-Nhalf*del
% x_in(1)
% x_new(end)+Nhalf*del
% x_in(end)

% index = find( (x_new-Nhalf*del >= x_in(1) ) & ...
%     (x_new+Nhalf*del <= x_in(end)) );   %找到要插值的位置
% if (isempty(index))
%     disp(' ')
%     disp(' ** Error: sinc_interp : Requested output samples cannot be interpolated')
%     disp(' ')
%     return
% end
% x_out = x_new(index);

x_out = x_new;   % index 表示待插值的位置
% out = {};
out = zeros(size(x_out));
% step through the output samples one at a time, interpolating a value for
% each one from the input samples.
for k = 1:length(x_out)

    % first find the span of the interpolating filter on the x axis
    x_current = x_out(k);
    x_low = x_current - Nhalf*del;
    x_high = x_current + Nhalf*del;
    % compute the *relative* position of each input sample within this span
    % compared to the current output sample location; these will be the
    % values at which the interpolating kernel filter response will be
    % needed.
    index_rel = find( (x_in >= x_low ) & ...
        (x_in <= x_high) );
    x_rel = x_in(index_rel) - x_current;
    % Now compute and apply the sinc weights. First fix any spots where
    % x_rel = 0; these will cause the sinc function to be undefined. Then
    % add in the window, if used, and apply to the data to compute the
    % output point.
    trouble = find(x_rel==0);
    if (~isempty(trouble))
        x_rel(trouble) = x_rel(trouble)+eps; % this will prevent division by zero
    end
    h = (sin(pi*x_rel/del)/pi./x_rel);

    if (win == 1)
        w = 0.54 + 0.46*cos(pi*x_rel/del/(Nhalf+1));
    else
        w = ones(size(h));
    end

    h = h.*w;
    h = h/sum(h);
    out(k) = sum(sum( in(index_rel).*h));
    

end
end


% sinc 插值 矩阵运算版本
function y = sincInterpVec(y_in, x_in, x_out)
    % 计算输入样本间的间隔
    dx = x_in(2) - x_in(1);
    
    % 获取x_out的尺寸
    [rows, cols] = size(x_out);
    
    % 初始化输出矩阵
    y = zeros(rows, cols);
    
    % 将x_in扩展为与x_out每个点对应的矩阵形式
    X_in = repmat(x_in, numel(x_out), 1);
    X_out = repmat(x_out(:), 1, length(x_in));
    
    % 计算差值
    xd = X_in - X_out;
    
    % 计算sinc权重
    sinc_weights = sin(pi*xd/dx) ./ (pi*xd/dx);
    sinc_weights(xd == 0) = 1;  % 处理除以0的情况
    
    % 归一化权重
    sinc_weights = sinc_weights ./ sum(sinc_weights, 2);
    
    % 应用权重并计算插值结果
    y(:) = sum((repmat(y_in, numel(x_out), 1) .* sinc_weights), 2);
    
    % 将输出重塑为原始x_out的形状
    y = reshape(y, rows, cols);
end


% sinc 插值 非矩阵运算版本
function y = sincInterp(y_in, x_in, x_out) 
    % Sinc插值函数 - 适应x_out为二维矩阵的情况
    % x_in: 输入数据的x坐标
    % y_in: 输入数据的y坐标
    % x_out: 插值输出的x坐标（可以是二维矩阵）
    % 计算输入样本间的间隔
    dx = x_in(2) - x_in(1);

    % 初始化输出矩阵
    y = zeros(size(x_out));

    % 对于x_out中的每个元素，计算其sinc插值
    for idx = 1:numel(x_out)
        % 计算当前x_out元素与所有x_in元素的差值
        xd = x_in - x_out(idx);

        % 计算sinc权重
        sinc_weights = sin(pi*xd/dx) ./ (pi*xd/dx);
        sinc_weights(xd == 0) = 1;  % 处理除以0的情况

        % 归一化权重
        sinc_weights = sinc_weights / sum(sinc_weights);

        % 应用权重并计算插值结果
        y(idx) = sum(y_in .* sinc_weights);
    end

end
