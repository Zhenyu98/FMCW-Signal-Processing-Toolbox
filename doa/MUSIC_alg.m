function [theta, spectrum] = MUSIC_alg(data, num_sources, array)
    % 数据中心化
    data = data - mean(data, 2);
    % 计算协方差矩阵
    R = data * data';
    % 求解特征值和特征向量
    [E, D] = eig(R);
    % 按特征值大小排序，取噪声子空间
    [eigenvals, idx] = sort(diag(D), 'ascend');
    En = E(:, idx(1:end-num_sources));

    % 搜索角度和谱
    theta = -90:1:90;  % 角度范围
    spectrum = zeros(size(theta));
    for i = 1:length(theta)
        % 波达方向向量
        steering = exp(-1j * pi * sin(theta(i) * pi/180) * array);
        % MUSIC谱
        spectrum(i) = 1 / (steering' * En * En' * steering);
    end

    % 归一化谱
    spectrum = abs(spectrum) / max(abs(spectrum));
end
