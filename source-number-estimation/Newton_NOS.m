function [ k_guji] = Newton_NOS( EVA,Rf )
%牛顿插值法信源数估计
%EVA为特征值,Rf为截断误差
[E_i,~]= sort(EVA);%从小到大
for i = 1:length(E_i)
    f_x0_i = E_i(i);
    delta_1_i = E_i(i+1) - E_i(i);%一阶差商
    delta_2_i = E_i(i+2) - E_i(i+1);
    delta2_0_i = delta_1_i - delta_2_i;%二阶差商
%     N_guji = f_x0 + delta_1*(i+3-i) + delta2_0*(i+3-(i+1));
    t = i+3-i;
    N_guji_i = f_x0_i + delta_1_i*t + delta2_0_i*t*(t-1)/2;
    if i >= length(E_i)-3
        k_i = length(E_i);
        break
    elseif abs(N_guji_i-E_i(i+3)) >= Rf
        k_i = (i+2);
        break
    end
end

[E_a,~]= sort(EVA,'descend');%从大到小
for i = length(E_a):-1:1
    f_x0_a = E_a(i);
    delta_1_a = E_a(i-1) - E_a(i);%一阶差商
    delta_2_a = E_a(i-2) - E_a(i-1);
    delta2_0_a = (delta_1_a - delta_2_a);%二阶差商
    t = i-(i-3);
    N_guji_a = f_x0_a + delta_1_a*t + delta2_0_a*t*(t-1)/2;
    if i <= 3
        k_a = length(E_a);
        break
    elseif abs(N_guji_a-E_a(i-3)) <= Rf
        if i ~= length(E_a)
            k_a = i;
            break        
        end
    end
end
k_guji = length(E_a)-min([k_i,k_a]);


end

