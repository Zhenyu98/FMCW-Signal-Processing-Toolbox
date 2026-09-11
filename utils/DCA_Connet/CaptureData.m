clc;
clear;
close all;

%% import path
currentFolder = pwd;

% 生成完整的路径
root_path = fullfile(currentFolder, '..', 'Dataset\');
data_name = 'T1'; %保存数据的文件夹
data_path = strcat(root_path,data_name);

%% 雷达基本参数配置
nSample = 256; % ADC采样点 256
chirpnum = 64; % 每帧chirp个数 lua5：128
framenum = 100;
F0 = 60e9; % 起始频率
c = physconst('lightspeed'); % 光速
LAMBDA = c / F0; % 波长
d = LAMBDA / 2; % 天线间距
TxNum = 3; % 发射天线数目
RxNum = 4;
% 游泳池的实验参数 最远11m 速度3m/s 脚本5
K = 70.283e12; % 调频斜率
Fs = 6000e3; % 采样率 6847
IDEL_TIME = 100e-6; % 空闲时间
RAMP_TIME = 56e-6; % 脉冲持续时间 80
TC = (IDEL_TIME + RAMP_TIME) * TxNum; % 单帧时间
TF = TC * chirpnum; % 帧间时间CHIRP
RANGE_RES = c / (2 * 1 / Fs * nSample * K); % 距离分辨率
RANGE_AXIS = (1: nSample) * RANGE_RES; % 距离单元
VELOCITY_RES = c / (2 * F0 * TF); % 速度分辨率
VELOCITY_AXIS = [-chirpnum / 2 : chirpnum / 2 - 1] * VELOCITY_RES; % 速度单元

init_frame = 0;
framebytes=nSample*chirpnum*TxNum*RxNum*2*2;
% 如 256adc*255chirp*3TX*4RX*2IQ*2byte = 3133440
%% connect to the DCA1000EVM
mmWaveRadarInit();
pause(0.1);
%% capture data
adc_file_name = strcat(data_path,'\adc_data_Raw_0.bin'); % 检测该文件夹下是否存在bin文件
SendCaptureCMD(root_path,data_name); % 发送采集数据的指令
pause(0.1);
FID = fopen(adc_file_name,'r'); % 读取bin文件
rt_show = [];
dt_show = [];
FRAME_SET = [];
%% check the adc data
while(true)
    D = dir(adc_file_name);
    path_size = D.bytes  % 监测采集文件大小
    if path_size ~= 0
        NUMADCBITS = 16; % ADC采样精度
        NUMLANES = 4; % 接收天线通道数目，通常不需要改变，除非仅用单通道
        ISREAL = 0; % 0 表示复数，1表示实数

        %% 读取文件并转为有符号数

        ADCDATA = fread(FID,'int16');
        %         ADCDATA = fread(FID,37498880,'int16');
        % 如果ADC精度为12位/14位则需要对采样数据补偿
        if NUMADCBITS ~= 16
            LMAX = 2^(NUMADCBITS-1)-1;
            ADCDATA(ADCDATA > LMAX) = ADCDATA(ADCDATA > LMAX) - 2^NUMADCBITS;
        end

        %% 参考TI的ADC RAW DATA CAPTURE的PDF 重排通道数据
        if ISREAL
            ADCDATA = reshape(ADCDATA, NUMLANES, []); % 每个接收天线只有一组采样即实部
        else % 每个接收天线有两组采样数据：实部和虚部
            ADCDATA = reshape(ADCDATA, NUMLANES*2, []);
            ADCDATA = ADCDATA([1,2,3,4],:) + sqrt(-1)*ADCDATA([5,6,7,8],:);
        end
        data = ADCDATA(1,:);

        max_frame = floor(size(data,2)/(nSample*TxNum*chirpnum));
        if max_frame ~= 0
            RX1_DATA = reshape(data(1:nSample*TxNum*chirpnum*max_frame),nSample,TxNum,chirpnum,max_frame);

            TX1_DATA = squeeze(RX1_DATA(:,1,:,:));
            range_plane = zeros(nSample/2,max_frame);
            micro_doppler = zeros(chirpnum,max_frame);
            for frame_idx = 1:max_frame
                adc_data = squeeze(TX1_DATA(:,:,frame_idx));
                adc_data = adc_data - mean(adc_data,1); % 滤除静态杂波
                adc_data = adc_data .* hanning(nSample); % 加窗
                range_profile = fft(adc_data,nSample,1); % 距离fft
                range_profile = range_profile - repmat(mean(range_profile'),size(range_profile,2),1)'; % 滤除速度为0目标
                doppler_profile = fftshift(fft(range_profile,chirpnum,2),2); % 多普勒fft

                %     cfar_matrix = cfar_ca_2d(doppler_profile,Tr,Td,Gr,Gd,alpha);
                %     doppler_profile(cfar_matrix == 0) = 0;
                dsum = abs(doppler_profile).^2;
                rsum = sum(dsum(1:end/2,:),2);
                vsum = sum(dsum(1:end/2,:),1);
                range_plane(:,frame_idx) = rsum;
                micro_doppler(:,frame_idx) = vsum;
            end

            init_frame = init_frame + max_frame;
            FRAME_SET = 1:init_frame;
            axis xy;
            subplot(121);
            rt_show = [rt_show,db(abs(range_plane))/2];
            imagesc(FRAME_SET*100/1e3,RANGE_AXIS(end/2+1:end),rt_show);
            xlabel('Frame Period(s)');ylabel('Range(m)');
            colormap(jet);caxis([80 110]);

            axis xy;
            subplot(122);
            dt_show = [dt_show,(db(abs(micro_doppler)))/2];
            imagesc(FRAME_SET*100/1e3,VELOCITY_AXIS,dt_show);
            xlabel('Frame Period(s)');ylabel('Velocity(m/s)');
            colormap(jet);caxis([80 110]);
            pause(0.01);
        end
    end
    if path_size == framebytes*framenum
        fclose(FID); % 关闭bin文件
        break; % 如果文件大小满足采集要求则退出循环
    end
end


