function [Matrix_Imag] = BPimaging(data,sensorParams,imgCut,IsPlot)
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
    IsPlot = true;
end

%% Define parameters, update based on the scenario
data = squeeze(data);
nSample = size(data,1);       % Samples per chirp
f0 = sensorParams.Start_Freq_GHz*1e9;
K = sensorParams.Slope_MHzperus*1e12;
fS = sensorParams.Sampling_Rate_ksps*1e3;       % Sampling rate (sps)
TS = 1/fS;                                      % Sampling period
B = K*TS*(nSample-1);                           % Band for a chrip
% Number of DFT points for Range-FFT
nFFTtime = nSample; 

% The sampled number of each row



L = imgCut(1);
dL = imgCut(2);
rangeNear = imgCut(3);
rangeFar = imgCut(4);

% Sampling distance at x (horizontal) axis in mm
dx = 1;        

%% Fixed parameters for all scenarios
c = physconst('lightspeed');
rmax = c*fS/(K*2)
dr = c/2/B



%% SAR parameters
% parameters of SAR

ArrayNum = size(data,2);
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


    case 2
        % traditional BP by matrix operations
        disp('traditional BP by matrix operations ')
        % 预先计算长度
        lenAzimuth = length(Azimuth);
        lenRange = length(range);
        % 预分配结果矩阵
        Matrix_Imag = zeros(length(x), length(y));

        % 使用 meshgrid 生成二维网格，以便于向量化计算
        [X, Y] = meshgrid(x, y);

        for ia = 1:lenAzimuth
            for ir = 1:lenRange
                % 使用网格计算 R
                R = sqrt((Azimuth(ia)-X).^2 + Y.^2);
                img = data(ir, ia) * exp(-4j * pi * R * f(ir) / c);
                Matrix_Imag = Matrix_Imag + img.';
            end
            waitbar(ia/lenAzimuth, h, 'traditional BP running with matrix operations...');
        end
        close(h);


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



    otherwise
        error("mode please choose 1,2,3,4");
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
