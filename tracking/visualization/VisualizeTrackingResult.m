function fig = VisualizeTrackingResult(trackResult, measurementSeq, plotParams)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : VisualizeTrackingResult.m
% Date & time         : May. 2026
% Version             : 1.0
% Purpose             : Plot centroid and EKF tracking result
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3
    plotParams = struct();
end

showRawPoints = getStructLogical(plotParams, 'ShowRawPoints', true);
showCentroid = getStructLogical(plotParams, 'ShowCentroid', true);
showVelocity = getStructLogical(plotParams, 'ShowVelocity', true);

fig = figure('Color', 'w');
if showVelocity
    tiledlayout(1, 2)
    ax1 = nexttile;
else
    ax1 = axes(fig);
end

hold(ax1, 'on')
if showRawPoints && isfield(measurementSeq, 'rawXYAll') && ~isempty(measurementSeq.rawXYAll)
    scatter(ax1, measurementSeq.rawXYAll(:,1), measurementSeq.rawXYAll(:,2), ...
        8, [0.70 0.70 0.70], 'filled', 'MarkerFaceAlpha', 0.20)
end

if showCentroid && isfield(measurementSeq, 'centroidXY')
    centroidMask = all(isfinite(measurementSeq.centroidXY), 2);
    plot(ax1, measurementSeq.centroidXY(centroidMask,1), ...
        measurementSeq.centroidXY(centroidMask,2), 'ko', ...
        'MarkerSize', 4, 'LineWidth', 1.0)
end

tracks = [trackResult.finishedTracks, trackResult.tracks];
colorMap = lines(max(length(tracks), 1));
for trackIdex = 1:length(tracks)
    xy = tracks(trackIdex).historyState(:,1:2);
    plot(ax1, xy(:,1), xy(:,2), '-', 'LineWidth', 1.5, ...
        'Color', colorMap(trackIdex,:))
    startIdex = find(all(isfinite(xy), 2), 1, 'first');
    endIdex = find(all(isfinite(xy), 2), 1, 'last');
    if ~isempty(startIdex)
        plot(ax1, xy(startIdex,1), xy(startIdex,2), 'o', ...
            'Color', colorMap(trackIdex,:), 'MarkerFaceColor', colorMap(trackIdex,:))
        plot(ax1, xy(endIdex,1), xy(endIdex,2), 's', ...
            'Color', colorMap(trackIdex,:), 'MarkerFaceColor', colorMap(trackIdex,:))
    end
end

xlabel(ax1, 'X (m)')
ylabel(ax1, 'Y (m)')
title(ax1, 'Point cloud tracking')
grid(ax1, 'on')
axis(ax1, 'equal')

if showVelocity
    ax2 = nexttile;
    hold(ax2, 'on')
    for trackIdex = 1:length(tracks)
        t = tracks(trackIdex).historyFrame;
        v = sqrt(sum(tracks(trackIdex).historyState(:,4:6).^2, 2));
        plot(ax2, t, v, '-', 'LineWidth', 1.5, 'Color', colorMap(trackIdex,:))
    end
    xlabel(ax2, 'Frame')
    ylabel(ax2, 'Speed (m/s)')
    title(ax2, 'Track velocity')
    grid(ax2, 'on')
end

end

function value = getStructLogical(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = logical(s.(fieldName));
else
    value = defaultValue;
end
end
