%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Copyright(C) 2026 Southwest University, Chongqing
% College of Electronic and Information Engineering
% -------------------------------------------------------------------------
% Developed By        : Zhenyu Wu
% Code name           : generate_readme_gallery.m
% Date & time         : Sep. 2026
% Version             : 1.0
% Purpose             : Export README figures from existing simulation demos
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Run from the repository root: run('docs/generate_readme_gallery.m')
% Existing demos clear the workspace and close figures. Save your work first.
% Only presentation is changed here; all data come from existing demos.

%% range-azimuth detections
rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'startup.m'))
demo_pointcloud_ra_sim
close all
assert(size(frame_data, 2) == 8 && ~isempty(frame_data))

fig = figure('Color', 'w', 'Position', [80, 80, 1420, 540]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact')
nexttile
map = abs(pointcloudInfo.RAM);
% angle_axis is nonuniform in degrees; use its actual bin coordinates.
surf(pointcloudInfo.angle_axis, range_axis, map / max(map(:)), 'EdgeColor', 'none')
view(2)
axis xy
xlim([-45, 45])
ylim([2, 12])
clim([0, 1])
colormap(parula)
cb = colorbar;
cb.Label.String = 'Normalized amplitude';
xlabel('Azimuth (degree)')
ylabel('Range (m)')
title('Range-azimuth spectrum')
nexttile
hold on
scatter(targetParams.range .* sind(targetParams.azimuth), ...
    targetParams.range .* cosd(targetParams.azimuth), 150, [0.85, 0.33, 0.10], ...
    'o', 'LineWidth', 2, 'DisplayName', 'True target')
scatter(frame_data(:, 1), frame_data(:, 2), 45, [0, 0.45, 0.70], ...
    'filled', 'DisplayName', 'Detected point')
xlabel('X (m)')
ylabel('Y (m)')
title('From spectrum to point cloud')
axis equal
xlim([-4, 5])
ylim([0, 11])
grid on
legend('Location', 'northwest')
set(findall(fig, 'Type', 'axes'), 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 1)
exportgraphics(fig, fullfile(fileparts(mfilename('fullpath')), 'assets', 'gallery_range_azimuth.png'), 'Resolution', 160)
fprintf('GALLERY_RA_POINTS=%d\n', size(frame_data, 1))

%% human scatterer motion and micro-Doppler
demo_human_motion_radar_echo
close all
fig = figure('Color', 'w', 'Position', [80, 60, 1440, 1000]);
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact')
poseIdx = [1, round(radarParams.PulseNum / 2), radarParams.PulseNum];
poseColor = [0.10, 0.36, 0.52];
scatterColor = [0.96, 0.62, 0.13];
for pIdex = 1:3
    ax = nexttile;
    hold(ax, 'on')
    P = targetParams.position_m(:, :, poseIdx(pIdex));
    % Body-centered views separate the poses without changing input data.
    P(:, 1:2) = P(:, 1:2) - humanInfo.body_center(poseIdx(pIdex), 1:2);
    neck = mean(P(3:4, :), 1);
    hipMid = P(2, :) - [0, 0, 0.18];
    hipLeft = [P(9, 1), hipMid(2:3)];
    hipRight = [P(10, 1), hipMid(2:3)];
    % The shaded body is a visual aid, not an additional radar scatterer.
    DrawGalleryEllipsoid(ax, (neck + hipMid) / 2, [0.23, 0.12, 0.30], poseColor)
    DrawGalleryEllipsoid(ax, hipMid, [0.20, 0.12, 0.12], poseColor)
    DrawGallerySegment(ax, neck, P(1, :), 0.05, poseColor)
    DrawGallerySegment(ax, neck, P(3, :), 0.05, poseColor)
    DrawGallerySegment(ax, neck, P(4, :), 0.05, poseColor)
    DrawGalleryEllipsoid(ax, P(1, :), [0.10, 0.10, 0.13], poseColor)
    bodyLinks = [3 5; 5 7; 4 6; 6 8; 9 11; 11 13; 10 12; 12 14];
    DrawGallerySegment(ax, hipLeft, P(9, :), 0.060, poseColor)
    DrawGallerySegment(ax, hipRight, P(10, :), 0.060, poseColor)
    for linkIdex = 1:size(bodyLinks, 1)
        DrawGallerySegment(ax, P(bodyLinks(linkIdex, 1), :), ...
            P(bodyLinks(linkIdex, 2), :), 0.047, poseColor)
    end
    for footIdex = [13, 14]
        DrawGalleryEllipsoid(ax, P(footIdex, :) + [0, -0.035, 0], [0.060, 0.13, 0.045], poseColor)
    end
    % Mark the real 14 scattering centers over the schematic body surface.
    scatter3(ax, P(:, 1), P(:, 2), P(:, 3), 28, scatterColor, 'filled', ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.5)
    axis(ax, 'equal')
    xlim(ax, [-0.50, 0.50])
    ylim(ax, [-0.60, 0.60])
    zlim(ax, [-0.05, 1.90])
    view(ax, [65, 14])
    axis(ax, 'off')
    camlight(ax, 'headlight')
    lighting(ax, 'gouraud')
    material(ax, 'dull')
    title(ax, sprintf('%.3f s', humanInfo.time_axis(poseIdx(pIdex))), ...
        'FontSize', 16, 'FontWeight', 'normal', 'Color', [0.24, 0.30, 0.36])
end
sgtitle({'Human motion to radar signature', ...
    '14 scattering centers  |  Body-centered poses with schematic body overlay'}, ...
    'FontName', 'Arial', 'FontSize', 20, 'FontWeight', 'normal')
ax = nexttile([1, 3]);
imagesc(ax, specTime, velocityAxis, specMap_dB)
axis(ax, 'xy')
ylim(ax, [floor(radialVelocitySpan(1)) - 1, ceil(radialVelocitySpan(2)) + 1])
clim(ax, [-45, 0])
colormap(ax, parula)
cb = colorbar(ax);
cb.Label.String = 'Relative magnitude (dB)';
xlabel(ax, 'Time (s)')
ylabel(ax, 'Velocity (m/s)')
title(ax, 'Micro-Doppler from the simulated echoes', 'FontWeight', 'normal')
set(findall(fig, 'Type', 'axes'), 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 0.8)
exportgraphics(fig, fullfile(fileparts(mfilename('fullpath')), 'assets', 'gallery_human_motion.png'), 'Resolution', 160)
fprintf('GALLERY_HUMAN_RANGE_INSIDE=%.6f\n', rangeInsideRatio)

%% tracking two targets from simulated radar echoes
rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'validation', 'validate_tracking_pointcloud_integration.m'))
close all
fig = figure('Color', 'w', 'Position', [80, 80, 1420, 540]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact')
tracks = [trackResult.finishedTracks, trackResult.tracks];
for targetIdex = 1:TargetNum
    nexttile
    hold on
    xyTrue = squeeze(truePosition(targetIdex, 1:2, :)).';
    startDistance = zeros(length(tracks), 1);
    for trackIdex = 1:length(tracks)
        startDistance(trackIdex) = norm(tracks(trackIdex).historyState(1, 1:2) - xyTrue(1,:));
    end
    % Ground truth is used only to match tracks for this display.
    [~, trackIdex] = min(startDistance);
    trackXY = tracks(trackIdex).historyState(:, 1:2);
    rawXY = measurementSeq.rawXYAll;
    keep = vecnorm(rawXY - mean(xyTrue, 1), 2, 2) < 1.0;
    scatter(rawXY(keep, 1), rawXY(keep, 2), 25, [0.55, 0.60, 0.65], ...
        'filled', 'DisplayName', 'Radar detections')
    plot(xyTrue(:, 1), xyTrue(:, 2), '--', 'Color', [0.85, 0.33, 0.10], ...
        'LineWidth', 2, 'DisplayName', 'True trajectory')
    plot(trackXY(:, 1), trackXY(:, 2), '-', 'Color', [0, 0.45, 0.70], ...
        'LineWidth', 2, 'DisplayName', 'EKF track')
    scatter(trackXY(1, 1), trackXY(1, 2), 60, [0, 0.45, 0.70], ...
        'o', 'LineWidth', 1.5, 'DisplayName', 'Track start')
    xlabel('X (m)')
    ylabel('Y (m)')
    title(sprintf('Target %d: %d frames', targetIdex, FrameNum))
    axis equal
    xlim([min(xyTrue(:,1)) - 0.2, max(xyTrue(:,1)) + 0.2])
    ylim([min(xyTrue(:,2)) - 0.25, max(xyTrue(:,2)) + 0.25])
    grid on
    legend('Location', 'best')
end
set(findall(fig, 'Type', 'axes'), 'FontName', 'Arial', 'FontSize', 14, 'LineWidth', 1)
exportgraphics(fig, fullfile(fileparts(mfilename('fullpath')), 'assets', 'gallery_tracking.png'), 'Resolution', 160)
fprintf('GALLERY_TRACKS=%d FRAMES=%d\n', length(tracks), FrameNum)
disp('README_GALLERY_EXPORTED')

% -------------------------- Subfunctions -------------------------------
function DrawGalleryEllipsoid(ax, center, radius, color)
[x, y, z] = sphere(20);
surf(ax, center(1) + radius(1) * x, center(2) + radius(2) * y, ...
    center(3) + radius(3) * z, 'FaceColor', color, 'EdgeColor', 'none', ...
    'AmbientStrength', 0.55, 'DiffuseStrength', 0.65, 'FaceAlpha', 0.38);
end

function DrawGallerySegment(ax, first, last, radius, color)
direction = (last - first).';
segmentLength = norm(direction);
if segmentLength < eps
    return
end
u = direction / segmentLength;
basis = null(u.');
[x, y, z] = cylinder(radius, 16);
xyz = basis(:, 1) * x(:).' + basis(:, 2) * y(:).' + u * (z(:).' * segmentLength);
surf(ax, reshape(xyz(1, :), size(x)) + first(1), ...
    reshape(xyz(2, :), size(y)) + first(2), ...
    reshape(xyz(3, :), size(z)) + first(3), ...
    'FaceColor', color, 'EdgeColor', 'none', 'AmbientStrength', 0.55, 'FaceAlpha', 0.38);
DrawGalleryEllipsoid(ax, first, [radius, radius, radius], color)
DrawGalleryEllipsoid(ax, last, [radius, radius, radius], color)
end
