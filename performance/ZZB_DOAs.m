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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [RAPB, RCRB, RZZB_Generalized, RZZB] = ZZB_DOAs(M, lambda, Array, SNR, T, K, num_MC, vartheta_min, vartheta_max, resolution)

one_k = ones(K, 1); % All-one vector in Eq. (13)

Zeta = deg2rad(vartheta_max - vartheta_min); % The range of DOAs, the first line below Eq.(26)

APB = K * Zeta^2 / ((K+1)^2 * (K+2)); % Eq. (42)
RAPB = rad2deg(sqrt(APB)) * ones(1, length(SNR)); % Root APB

sigma2_n = 1; % Noise power

%% Generating random DOAs
theta_rec = [];
for iter = 1 : num_MC
    theta = unifrnd(vartheta_min, vartheta_max, K, 1); %theta is random vars in uniform distribution
    while min( diff(sort(theta)) ) < resolution % Least 10 degrees separation between DOAs for random sample
        theta = unifrnd(vartheta_min, vartheta_max, K, 1);
    end
    theta_rec = [theta_rec, theta];
end
theta_rec = sort(theta_rec, 1);

%% Monte Carlo trials
for idx_SNR = 1 : length(SNR)
    for idx_MC = 1 : num_MC
        sigma2_s = 10^(SNR(idx_SNR)/10) * sigma2_n * ones(K, 1); % Sources power
        
        theta_MC = theta_rec(:, idx_MC); % DOAs in the idx_MC-th Monte Carlo trial
        
        A_theta = exp(-1j * (2*pi/lambda) * Array * sind(theta_MC')); % Steering Matrix
        
        Sigma = diag(sigma2_s); % Eq. (4)
        
        Rxx = A_theta * Sigma * A_theta' + sigma2_n * eye(M); % Covariance matrix
        
        %% CRB (Stochastic Model)
        PA_0 = eye(M) - A_theta * inv(A_theta' * A_theta) * A_theta';
        
        d_A_theta = -1j * (2*pi/lambda) * Array * cosd(theta_MC') .* A_theta;
        
        DPaD = d_A_theta' * PA_0 * d_A_theta;
        
        J_inv = (sigma2_n/(2*T)) * inv( real(DPaD .* (Sigma * A_theta' * inv(Rxx) * A_theta * Sigma).') ); % Inversion of Fisher information matrix
        
        CRB_MC = mean(diag(J_inv));
        
        %% ZZB (Stochastic Model)
        eta = sigma2_s / sigma2_n; % SNR vector containing SNRs of K sources
        
        P_L = exp( T * sum( log(4 * (1+M*eta) ./ (2+M*eta).^2) + (M*eta ./ (2+M*eta)).^2 ) ) ...
            * qfunc( sqrt( 2 * T * sum( (M*eta ./ (2+M*eta)).^2 ) ) ); % Eq. (48)
        coef_APB = 2 * P_L; % Combination coefficient for APB
        
        tilde_u = min( T * sum( (M*eta ./ (2+M*eta)).^2 ), K^2 * Zeta^2 / (8 * one_k' * J_inv * one_k) ); % Eq.(49)
        coef_CRB = gammainc(tilde_u, 3/2); % Combination coefficient for CRB
        
        ZZB_Generalized_MC = ((K+1)/2) * coef_APB * APB + coef_CRB * trace(J_inv)/K;
        ZZB_MC = coef_APB * APB + coef_CRB * trace(J_inv)/K; % Eq. (41)
        
        %% Root bounds
        RCRB_MC(idx_MC) = rad2deg(sqrt(CRB_MC)); % Root CRB for the each trial
        RZZB_Generalized_MC(idx_MC) = rad2deg(sqrt(ZZB_Generalized_MC)); % Root Generalized ZZB
        RZZB_MC(idx_MC) = rad2deg(sqrt(ZZB_MC)); % Root ZZB
    end
    
    RCRB(idx_SNR) = mean(RCRB_MC); % Averaged root CRB
    RZZB_Generalized(idx_SNR) = mean(RZZB_Generalized_MC); % Averaged root Generalized ZZB
    RZZB(idx_SNR) = mean(RZZB_MC); % Averaged root ZZB
end

end