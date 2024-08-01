function [theta] = ESPRIT_alg(data, num_sources)
    % 数据中心化
    data = data - mean(data, 2);
    % 计算协方差矩阵
    R = cov(data.');
    % 求解特征值和特征向量
    [E, D] = eig(R);
    % 按特征值大小排序，取信号子空间
    [eigenvals, idx] = sort(diag(D), 'descend');
    Es = E(:, idx(1:num_sources));

    % 将阵列分为两个相互重叠的子阵列
    Es1 = Es(1:end-1, :);
    Es2 = Es(2:end, :);

    % 解决相位差
    Phi = pinv(Es1) * Es2;
    phi = angle(eig(Phi));

    % 计算角度
    theta = asind(phi / pi);
end
