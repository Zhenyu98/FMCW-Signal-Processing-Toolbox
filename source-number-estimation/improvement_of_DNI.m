clear all
close all
clc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                牛顿插值和改进牛顿插值             %
%                                     by Jerry Yang%
%                                      2019uuz0302 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fs = 10000; %采样频率
fc1 = 1500;  %信源1频率
fc2 = 1000;
fc3 = 680;
fc4 = 670;
fc5 = 620;
MM = 200;%快拍数
T = (MM-1)*(1/fs);   %脉宽 
t = 1/fs:1/fs:T; 
NN = fs*T; %采样点数
xt1 = sin(2*pi*fc1*t);  %信号1
xt2 = sin(2*pi*fc2*t);
xt3 = sin(2*pi*fc3*t);
xt4 = sin(2*pi*fc4*t);
xt5 = sin(2*pi*fc5*t);
....................阵列参数..........................
N =8; %阵元数
c = 1540;   %水中声速
lemda = c/fc3;
d = lemda/2;
beita = 0:d:(N-1)*d;
theta1 = 40;    %信源1方位角
theta2 = 60;
theta3 = 80;
theta4 = 100;
theta5 = 120;
miu1 = [1,cos(theta1*pi/180),sin(theta1*pi/180)].';
miu2 = [1,cos(theta2*pi/180),sin(theta2*pi/180)].';
miu3 = [1,cos(theta3*pi/180),sin(theta3*pi/180)].';
miu4 = [1,cos(theta4*pi/180),sin(theta4*pi/180)].';
miu5 = [1,cos(theta5*pi/180),sin(theta5*pi/180)].';

a1 = exp(1j*2*pi*beita*cos(theta1*pi/180)/lemda).';
a1_vector = kron(a1,miu1);
a2 = exp(1j*2*pi*beita*cos(theta2*pi/180)/lemda).';
a2_vector = kron(a2,miu2);
a3 = exp(1j*2*pi*beita*cos(theta3*pi/180)/lemda).';
a3_vector = kron(a3,miu3);
a4 = exp(1j*2*pi*beita*cos(theta4*pi/180)/lemda).';
a4_vector = kron(a4,miu4);
a5 = exp(1j*2*pi*beita*cos(theta5*pi/180)/lemda).';
a5_vector = kron(a5,miu5);
a11 = a1*xt1;
a22 = a2*xt2;
a33 = a3*xt3;
a44 = a4*xt4;
a55 = a5*xt5;

a11_vector = a1_vector*xt1;
a22_vector = a2_vector*xt2;
a33_vector = a3_vector*xt3;
a44_vector = a4_vector*xt4;
a55_vector = a5_vector*xt5;


%%%%%%%%%%%%%%%%%%%monterkalor接受信号%%%%%%%%%%%%%%%%%%%%%%%%%%
SNR = -20:1:20;
% SNR = -10;
for snri = 1:length(SNR)
    tic
    snri
    snr = SNR(snri);   %信噪比
    Am =  sqrt(2*10^(snr/10));
    for ii = 1:1000
        noise = randn(N,length(xt1));
%         rec = a11*Am+noise;
%         rec = a11*Am+a22*Am+noise;
%         rec = a11*Am+a22*Am+a33*Am+noise;
%         rec = a11*Am+a22*Am+a33*Am+a44*Am+noise;
        rec = a11*Am+a22*Am+a33*Am+a44*Am+a55*Am+noise;
        rec_vector = a11_vector*Am+a22_vector*Am+a33_vector*Am+...
            a44_vector*Am+a55_vector*Am+randn(N*3,length(xt1));
%         rec = awgn(a11+a22+a33+a44+a55,snr);
        num = 5; %真实信源数
        recs = fft(rec,length(xt1),2);
        recs_vector = fft(rec_vector,length(xt1),2);
        Rxx=cov(rec');
        Rxx_vector=cov(rec_vector');
%         Rxx2=(recs*recs');%协方差矩阵 
        [V,D] = eig(Rxx);%特征分解,,若非方阵，则其就是奇异值分解
        EVA = diag(D);%取特征值
        [EVA,I] = sort(EVA,'descend');   %从大到小排列
        V = V(:,I); %由大到小排列特征值对应的特征向量矩阵
        
        [V_vector,D_vector] = eig(Rxx_vector);%特征分解,,若非方阵，则其就是奇异值分解
        EVA_vector = diag(D_vector);%取特征值
        [EVA_vector,I_vector] = sort(EVA_vector,'descend');   %从大到小排列
        V_vector = V_vector(:,I_vector); %由大到小排列特征值对应的特征向量矩阵

%%%%%%%%%%%%牛顿插值

        Rf = 1;
        [ k ] = Newton_NOS( EVA,Rf );
        [ k_gaijin  ] = Newton_NOS( EVA.*(log(EVA).^2),Rf );
        
        [ k_vector ] = Newton_NOS( EVA_vector,Rf );
        [ k_gaijin_vector  ] = Newton_NOS( EVA_vector.*(log(EVA_vector).^2),Rf );
        
        kN(snri,ii) = k;
        kN_gaijin(snri,ii) = k_gaijin;
        
        kN_vector(snri,ii) = k_vector;
        kN_gaijin_vector(snri,ii) = k_gaijin_vector;


    end
    SNew(snri)=length(find(kN(snri,1:ii)==num)) / ii;
    SNew_gaijin(snri)=length(find(kN_gaijin(snri,1:ii)==num)) / ii;
    SNew_vector(snri)=length(find(kN_vector(snri,1:ii)==num)) / ii;
    SNew_gaijin_vector(snri)=length(find(kN_gaijin_vector(snri,1:ii)==num)) / ii;

    toc
end

figure
plot(SNR,SNew,'r-*','linewidth',2)
hold on
plot(SNR,SNew_gaijin,'linewidth',2)
grid on
xlabel('SNR/dB');
ylabel('检测概率');
set(gca,'XDir','reverse')
legend('DNI','DNI改进算法');
title('标量')

figure
plot(SNR,SNew_vector,'r-*','linewidth',2)
hold on
plot(SNR,SNew_gaijin_vector,'linewidth',2)
grid on
xlabel('SNR/dB');
ylabel('检测概率');
set(gca,'XDir','reverse')
legend('DNI','DNI改进算法');
title('矢量')



