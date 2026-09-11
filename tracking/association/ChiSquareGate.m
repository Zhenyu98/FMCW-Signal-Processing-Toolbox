function gateThreshold = ChiSquareGate(P_G, m_d)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : ChiSquareGate.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Calculate chi-square tracking gate threshold
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

P_G = min(max(P_G, 1e-6), 1 - 1e-6);
if exist('chi2inv', 'file') == 2 || exist('chi2inv', 'builtin') == 5
    gateThreshold = chi2inv(P_G, m_d);
else
    gateThreshold = 2 * gammaincinv(P_G, m_d / 2);
end

end
