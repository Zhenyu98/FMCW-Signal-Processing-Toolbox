clear all
close all
clc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                   牛顿插值信源数影响             %
%                                     by Jerry Yang%
%                                      2019uuz0302 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fs = 10000; %采样频率
fc1 = 1500;  %信源1频率
fc2 = 1000;
fc3 = 500;
fc4 = 400;
fc5 = 300;

....................阵列参数..........................
N = 8; %阵元数
c = 1540;   %水中声速
lemda = c/fc3;
d = lemda/2;
beita = 0:d:(N-1)*d;
theta1 = 40;    %信源1方位角
theta2 = 60;
theta3 = 80;
theta4 = 100;
theta5 = 120;
a1 = exp(1j*2*pi*beita*cos(theta1*pi/180)/lemda).'; %信源1阵列流形
a2 = exp(1j*2*pi*beita*cos(theta2*pi/180)/lemda).';
a3 = exp(1j*2*pi*beita*cos(theta3*pi/180)/lemda).';
a4 = exp(1j*2*pi*beita*cos(theta4*pi/180)/lemda).';
a5 = exp(1j*2*pi*beita*cos(theta5*pi/180)/lemda).';
%%%%%%%%%%%%%%%%%%%monterkalor接受信号%%%%%%%%%%%%%%%%%%%%%%%%%%
snr = 0;
MM = 80;
T = (MM-1)*(1/fs);   %脉宽 
t = 1/fs:1/fs:T; 
NN = fs*T; %采样点数
xt1 = sin(2*pi*fc1*t);  %信号1
xt2 = sin(2*pi*fc2*t);
xt3 = sin(2*pi*fc3*t);
xt4 = sin(2*pi*fc4*t);
xt5 = sin(2*pi*fc5*t);
a11 = a1*xt1;
a22 = a2*xt2;
a33 = a3*xt3;
a44 = a4*xt4;
a55 = a5*xt5;
Am =  sqrt(2*10^(snr/10));
NUM = 1:6;
for numi = 1:length(NUM)
    tic
    numi  
    num = NUM(numi);%快拍数
    for ii = 1:1000       
        noise = randn(N,length(xt1));
        rec = a11*Am+(numi-2>=0)*a22*Am+(numi-3>=0)*a33*Am+...
            (numi-4>=0)*a44*Am+(numi-5>=0)*a55*Am+noise;
        recs = fft(rec,length(xt1),2);
        % Rxx=(recs*recs');%协方差矩阵 
        Rxx=cov(rec');
        [V,D] = eig(Rxx);%特征分解,,若非方阵，则其就是奇异值分解
        EVA = diag(D);%取特征值
        [EVA,I] = sort(EVA,'descend');   %从大到小排列
        V = V(:,I); %由大到小排列特征值对应的特征向量矩阵

%%%%%%%%%%%%牛顿插值
        Rf = 1;
        [ k ] = Newton_NOS( EVA,Rf );
        [ k_gaijin  ] = Newton_NOS( EVA.*(log(EVA).^2),Rf );
        
        kN(numi,ii) = k;
        kN_gaijin(numi,ii) = k_gaijin;
%%%%%%%%%%%%MDL法和AIC法
        for k=0:N-1 
            %第一个特征值一直到最后一个特征值进行处理
            sigema=0;
            pai=1;
            for i=k+1:N
                pai=EVA(i)*pai;%特征值连乘
                sigema=EVA(i)+sigema;%特征值连加
            end
            Alpha_k = 1/(N-k)*sigema;
            Beita_k = pai^(1/(N-k));
            W1 = Alpha_k/Beita_k;
%             W = Beita_k/Alpha_k;
            W=pai^(1/(N-k))/sigema*(N-k);
            AIC(k+1)=-2*NN*(N-k)*log(W)+2*k*(2*N-k);
            MDL(k+1)=-NN*(N-k)*log(W)+k*(2*N-k)*log(NN)/2;
        end
            
        [mA,kA(numi,ii)]=min(AIC);
        [mM,kM(numi,ii)]=min(MDL);
%%%%%%%%%%%%盖氏圆法GDE
%         Rxxp=Rxx(2:N,2:N);
        Rxxp=Rxx(1:N-2,1:N-2);
        [Vp,Dp]=eig(Rxxp);
        Vp=fliplr(Vp);
        %构造酉矩阵Tp = [V 0]
        %               [0 1]
        Tp=zeros(N,N);
        Tp(1:N-2,1:N-2)=Vp;
        Tp(N,N)=1;
        Rt=Tp'*Rxx*Tp;%变换后的矩阵Rt
        rk=abs(Rt(1:N-1,N));%圆盘半径rk
        DL=40/MM;%调整因子，0<DL<1，理论上N越大DL越小。源程序用的0.2
        GDE=rk(1:N-1)-DL./(N-1)*sum(rk);
        %
        k0=0;
        for k=1:N-1
            if GDE(k)<0
                k0=k;
                break
            end
        end
        Ns_est(ii)=k0-1;
%%%%%%%%%%%%特征值阈值法
        ET = 0.6;
        PC = mode(round(log(EVA)))+ET;%mod求众数,ET为阈值       
        k_ET(numi,ii) = 0;%特征子空间投影预分配
        for k=1:N
            if round(log(EVA(k)))-PC > 0
                k_ET(numi,ii) = k_ET(numi,ii)+1;
            end
        end       
        
    end
    SNew(numi)=length(find(kN(numi,1:ii)==num)) / ii;
    SNew_gaijin(numi)=length(find(kN_gaijin(numi,1:ii)==num)) / ii;
    SAIC(numi)=length(find(kA(numi,1:ii)==num+1)) / ii;
    SMDL(numi)=length(find(kM(numi,1:ii)==num+1)) / ii;
    SGDE(numi)=length(find(Ns_est==num))/ii;  %估计到的信号源个数
    SET(numi) = length(find(k_ET(numi,1:ii)==num))/ii;%阈值法
    toc
end

figure
plot(NUM,SET,'linewidth',2)
hold on
plot(NUM,SNew_gaijin,'r-*','linewidth',2)
hold on
plot(NUM,SAIC,'-.')
hold on
plot(NUM,SMDL,'-.','linewidth',2)
hold on
plot(NUM,SGDE,'--','linewidth',2)
grid on
xlabel('信源个数');
ylabel('检测概率');
legend('ET','DNI改进算法','AIC','MDL','GDE');
axis tight

