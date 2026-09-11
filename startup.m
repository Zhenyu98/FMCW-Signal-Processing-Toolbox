% Add FMCW toolbox folders to MATLAB search path.
% 0_refer_code (local reference projects) is intentionally not added.

cur_dir = fileparts(mfilename('fullpath'));

folders = {
    'signal'
    'pointcloud'
    'imaging'
    'doa'
    'source-number-estimation'
    'tracking'
    fullfile('tracking', 'preprocessing')
    fullfile('tracking', 'clustering')
    fullfile('tracking', 'association')
    fullfile('tracking', 'filtering')
    fullfile('tracking', 'management')
    fullfile('tracking', 'visualization')
    'validation'
    'utils'
    fullfile('utils', 'DCA_Connet')
    };

for ii = 1:length(folders)
    folderPath = fullfile(cur_dir, folders{ii});
    if exist(folderPath, 'dir')
        addpath(folderPath, '-end');
    end
end

disp('FMCW Signal Processing Toolbox path is ready.');
