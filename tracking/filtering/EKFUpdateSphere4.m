function [xUpdate, PUpdate, updateInfo] = EKFUpdateSphere4(xPred, PPred, z, R)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : EKFUpdateSphere4.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : EKF update with [range, azimuth, elevation, doppler]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[zPred, H] = Cart6ToSphere4AndJacobian(xPred);
innovation = z(:) - zPred;
innovation(2) = WrapAngle(innovation(2));
innovation(3) = WrapAngle(innovation(3));

S = H * PPred * H' + R;
S = (S + S') / 2;
K = PPred * H' / S;

xUpdate = xPred + K * innovation;
PUpdate = (eye(6) - K * H) * PPred * (eye(6) - K * H)' + K * R * K';
PUpdate = (PUpdate + PUpdate') / 2;

updateInfo.zPred = zPred;
updateInfo.H = H;
updateInfo.innovation = innovation;
updateInfo.S = S;
updateInfo.K = K;
updateInfo.NIS = innovation' / S * innovation;
updateInfo.componentNIS = innovation.^2 ./ max(diag(S), eps);

end
