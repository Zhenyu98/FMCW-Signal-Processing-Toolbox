%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : validate_template_equivalence.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Template for reference-code equivalence validation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
clear
close all

%% reference project
% Fill in the original reference project path and entry script/function.
refPath = fullfile('..', '0_refer_code', 'project_name');

%% toolbox path
toolboxRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(toolboxRoot, 'startup.m'));

%% define parameters / load same data
% Keep the input exactly the same for reference code and toolbox code.
% Example:
% sensorParams.Start_Freq_GHz = 77;
% targetParams.range = [7.00, 7.50];

%% run reference method
% addpath(refPath)
% ref_output = reference_function(input);

%% run toolbox method
% new_output = toolbox_function(input);

%% equivalence metrics
% rawNmse = norm(ref_output(:) - new_output(:))^2 / (norm(ref_output(:))^2 + eps);
% alpha = (new_output(:)' * ref_output(:)) / (new_output(:)' * new_output(:) + eps);
% alignedNmse = norm(ref_output(:) - alpha * new_output(:))^2 / (norm(ref_output(:))^2 + eps);
%
% disp(['raw NMSE: ', num2str(rawNmse)])
% disp(['aligned NMSE: ', num2str(alignedNmse)])

%% sanity checks
% assert(isequal(size(ref_output), size(new_output)))
% assert(rawNmse < 1e-10 || alignedNmse < 1e-10)

disp('Fill this template with a real reference project before running.')
