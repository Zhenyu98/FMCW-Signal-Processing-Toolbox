function [ k_ES ] = ES_NOS( Rxx,V )
%特征子空间投影法信源数估计
%   Rxx为协方差矩阵，V为特征向量从大到小
N = length(V);
for i = 1:N
    Ti = V(:,N-i+1:N);
    for j = 1:N
        Ci(:,j) = Ti'*Rxx(:,j);
    end
    Ci_ba = mean(Ci,2);
    vi(i) = var(Ci_ba);
    clear Ci
end

alpha_tz = 0.2;%理论上与信噪比有关，SNR越大值越趋近于0，取0.2
vi_mean = mean(vi);
for i = 1:N
    derta(i) = vi(i)-alpha_tz*vi_mean;
end
k_ES = 0.2;%特征子空间投影预分配
for k=1:N
    if derta(k)>0
        k_ES = k_ES+1;
    end
end

end

