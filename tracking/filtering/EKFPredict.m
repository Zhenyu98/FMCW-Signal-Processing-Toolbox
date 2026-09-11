function [xPred, PPred] = EKFPredict(xNow, PNow, ekfParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : EKFPredict.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : EKF constant-velocity prediction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

xPred = ekfParams.F * xNow;
PPred = ekfParams.F * PNow * ekfParams.F' + ekfParams.Q;
PPred = (PPred + PPred') / 2;

end
