function [rd_peak_list, rd_peak] = peakFocus(RDM, cfar_out_list, cfgDOA)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Purpose : Refine CFAR survivors into range-Doppler peaks
% -------------------------------------------------------------------------
% Default mode keeps the original 4-neighbor local maximum behavior.
% Optional py_doppler mode follows the Doppler-wrap grouping idea from
% OpenRadar noise_removal.py::prune_to_peaks.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 3
    cfgDOA = struct();
end

peakFocusMode = getStructText(cfgDOA, 'PeakFocusMode', 'legacy_4neighbor');

switch lower(peakFocusMode)
    case {'legacy_4neighbor', 'legacy', '4neighbor'}
        [rd_peak_list, rd_peak] = legacyPeakFocus(RDM, cfar_out_list);
    case {'py_doppler', 'doppler', 'py'}
        reserveNeighbor = getStructLogical(cfgDOA, 'ReservePeakNeighbor', false);
        [rd_peak_list, rd_peak] = pyDopplerPeakFocus(RDM, cfar_out_list, reserveNeighbor);
    otherwise
        error('Unknown PeakFocusMode: %s', peakFocusMode)
end

end

function [rd_peak_list, rd_peak] = legacyPeakFocus(RDM, cfar_out_list)

rd_peak = zeros(size(RDM));
rd_peak_list = [];
data_length = size(cfar_out_list, 1);

for target_idx = 1:data_length
    range_idx = cfar_out_list(target_idx, 1);
    doppler_idx = cfar_out_list(target_idx, 2);

    if range_idx > 1 && range_idx < size(RDM, 1) && ...
            doppler_idx > 1 && doppler_idx < size(RDM, 2)
        if RDM(range_idx, doppler_idx) > RDM(range_idx-1, doppler_idx) && ...
                RDM(range_idx, doppler_idx) > RDM(range_idx+1, doppler_idx) && ...
                RDM(range_idx, doppler_idx) > RDM(range_idx, doppler_idx-1) && ...
                RDM(range_idx, doppler_idx) > RDM(range_idx, doppler_idx+1)

            rd_peak(range_idx, doppler_idx) = RDM(range_idx, doppler_idx);
            rd_peak_list = [rd_peak_list, [range_idx; doppler_idx]]; %#ok<AGROW>
        end
    end
end

end

function [rd_peak_list, rd_peak] = pyDopplerPeakFocus(RDM, cfar_out_list, reserveNeighbor)

rd_peak = zeros(size(RDM));
rd_peak_list = [];
data_length = size(cfar_out_list, 1);
numDopplerBins = size(RDM, 2);

for target_idx = 1:data_length
    range_idx = cfar_out_list(target_idx, 1);
    doppler_idx = cfar_out_list(target_idx, 2);

    if range_idx < 1 || range_idx > size(RDM, 1) || ...
            doppler_idx < 1 || doppler_idx > numDopplerBins
        continue
    end

    prev_idx = mod(doppler_idx - 2, numDopplerBins) + 1;
    next_idx = mod(doppler_idx, numDopplerBins) + 1;
    current_val = RDM(range_idx, doppler_idx);
    prev_val = RDM(range_idx, prev_idx);
    next_val = RDM(range_idx, next_idx);

    keep = current_val > prev_val && current_val > next_val;

    if reserveNeighbor
        prev_prev_idx = mod(prev_idx - 2, numDopplerBins) + 1;
        next_next_idx = mod(next_idx, numDopplerBins) + 1;
        prev_prev_val = RDM(range_idx, prev_prev_idx);
        next_next_val = RDM(range_idx, next_next_idx);

        is_neighbor_of_peak_next = current_val > next_next_val && current_val > prev_val;
        is_neighbor_of_peak_prev = current_val > prev_prev_val && current_val > next_val;
        keep = keep || is_neighbor_of_peak_next || is_neighbor_of_peak_prev;
    end

    if keep
        rd_peak(range_idx, doppler_idx) = current_val;
        rd_peak_list = [rd_peak_list, [range_idx; doppler_idx]]; %#ok<AGROW>
    end
end

end

function value = getStructText(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = char(string(s.(fieldName)));
else
    value = defaultValue;
end
end

function value = getStructLogical(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = logical(s.(fieldName));
else
    value = defaultValue;
end
end
