function [IDX, isnoise] = DBSCANCluster(X, epsilon, MinPts)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : DBSCANCluster.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Simple DBSCAN for tracking centroid generation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if isempty(X)
    IDX = zeros(0, 1);
    isnoise = false(0, 1);
    return
end

C = 0;
n = size(X, 1);
IDX = zeros(n, 1);
isnoise = false(n, 1);
visited = false(n, 1);

D = zeros(n, n);
for dimIdex = 1:size(X, 2)
    diffNow = X(:,dimIdex) - X(:,dimIdex).';
    D = D + diffNow.^2;
end
D = sqrt(D);

for i = 1:n
    if ~visited(i)
        visited(i) = true;
        Neighbors = RegionQuery(i);
        if numel(Neighbors) < MinPts
            isnoise(i) = true;
        else
            C = C + 1;
            ExpandCluster(i, Neighbors, C);
        end
    end
end

    function ExpandCluster(i, Neighbors, C)
        IDX(i) = C;
        k = 1;
        while true
            j = Neighbors(k);
            if ~visited(j)
                visited(j) = true;
                Neighbors2 = RegionQuery(j);
                if numel(Neighbors2) >= MinPts
                    Neighbors = [Neighbors; Neighbors2(:)]; %#ok<AGROW>
                end
            end
            if IDX(j) == 0
                IDX(j) = C;
            end
            k = k + 1;
            if k > numel(Neighbors)
                break
            end
        end
    end

    function Neighbors = RegionQuery(i)
        Neighbors = find(D(i,:) <= epsilon).';
    end

end
