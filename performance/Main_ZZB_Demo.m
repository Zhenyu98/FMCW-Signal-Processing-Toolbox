%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Simulation demo for Ziv-Zakai bound for multi-source DOA estimation
%%% Version: 1.1
%%% Author: Zongyu Zhang
%%% Date: 2023/06/01

%%% If you in any way use this code for research that results in
%%% publications, please cite our original article:
%%% Z. Zhang, Z. Shi, and Y. Gu, "Ziv-Zakai bound for DOAs estimation",
%%% IEEE Trans. Signal Process., vol. 71, pp. 136-149, 2023.

%%% Please report any bug to Zongyu Zhang (zongyu_zhang@zju.edu.cn). 

%%% Introduction:
%%% This program provides the APB, CRB and the ZZB for DOA estimation of
%%% fully incoherent multiple sources with the same SNR.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all;

M = 20;                         % The number of array sensors
lambda = 2;                     % The waveform length
Array = [0:M-1]' * lambda/2;	% ULA
SNR = [-40:0.5:-10,-8:2:20];	% SNR grid (in dB)
T = 40;                         % The number of snapshots
K = 5;                          % The number of sources
% K = 1;
num_MC = 1000;                  % The number of Monte Carlo trials
vartheta_min = -60;             % Minimum value of DOAs range (in deg)
vartheta_max = 60;              % Maximum value of DOAs range (in deg)
resolution = 10;                % Least 10 degrees separation between DOAs for random sample

[RAPB, RCRB, RZZB_Generalized, RZZB] = ZZB_DOAs(M, lambda, Array, SNR, T, K, num_MC, vartheta_min, vartheta_max, resolution);

%% Figure plot
figure;
semilogy(SNR, RAPB, 'k-.', 'Linewidth', 1.5);
hold on;
grid on;
semilogy(SNR, RCRB, 'b--', 'Linewidth', 1.5);
semilogy(SNR, RZZB_Generalized, 'g--', 'Linewidth', 1.5);
semilogy(SNR, RZZB, 'r', 'Linewidth', 1.5);
legend('APB', 'CRB', 'Generalized ZZB', 'ZZB');
axis([-40, 20, 1e-2, 1e2]);
xlabel('SNR (dB)');
ylabel('RMSE (deg)');