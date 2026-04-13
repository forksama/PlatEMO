% example_compare_DCMOCPSO_vs_MOCPSO_Ek.m
% 
% Ablation study for DCMOCPSO on UAVPathPlanning
%
% Compare three DCMOCPSO configurations:
% 1) {5, 2, 0.5, 0.3, true,  true,  true}
% 2) {5, 2, 0.5, 0.3, false, false, false}
% 3) {1, 2, 0.5, 0.3, false, false, false}
% Metric: mean of the last HV value across n runs

clear; clc; close all;

%% Settings
n = 10;

% UAVPathPlanning parameters (same as example_DCMOCPSO requirement)
N = 20;
problemParameter = {20, 20, 5, -85, 0};

% DCMOCPSO settings
maxFE_DCMOCPSO = 100;
% param_DCMOCPSO: {numSegments, segmentOverlap, lambda, c_guide, useDynamicGrouping, useDynamicMutation, useEk}
param_DCMOCPSO_Full = {5, 2, 0.5, 0.3, true, true, true};
param_DCMOCPSO_Base = {5, 2, 0.5, 0.3, false, false, false};
param_DCMOCPSO_OneSeg = {1, 2, 0.5, 0.3, false, false, false};

% Result cache
cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

cacheFile_DCMOCPSO_Full = fullfile(cacheDir, 'DCMOCPSO_Full_HV_runs.mat');
cacheFile_DCMOCPSO_Base = fullfile(cacheDir, 'DCMOCPSO_Base_HV_runs.mat');
cacheFile_DCMOCPSO_OneSeg = fullfile(cacheDir, 'DCMOCPSO_OneSeg_HV_runs.mat');

%% Run three DCMOCPSO ablation settings (or load cache)
[hvLast_DCMOCPSO_Full, hvSeries_DCMOCPSO_Full, actualFE_DCMOCPSO_Full] = runOrLoad( ...
    'DCMOCPSO_Full', cacheFile_DCMOCPSO_Full, n, @() runOne_DCMOCPSO(N, maxFE_DCMOCPSO, problemParameter, param_DCMOCPSO_Full));

[hvLast_DCMOCPSO_Base, hvSeries_DCMOCPSO_Base, actualFE_DCMOCPSO_Base] = runOrLoad( ...
    'DCMOCPSO_Base', cacheFile_DCMOCPSO_Base, n, @() runOne_DCMOCPSO(N, maxFE_DCMOCPSO, problemParameter, param_DCMOCPSO_Base));

% DCMOCPSO_OneSeg uses mean(actualFE) from DCMOCPSO_Full runs as maxFE
% maxFE_DCMOCPSO_OneSeg = round(mean(actualFE_DCMOCPSO_Full));
maxFE_DCMOCPSO_OneSeg = 1000;

[hvLast_DCMOCPSO_OneSeg, hvSeries_DCMOCPSO_OneSeg, actualFE_DCMOCPSO_OneSeg] = runOrLoad( ...
    'DCMOCPSO_OneSeg', cacheFile_DCMOCPSO_OneSeg, n, @() runOne_DCMOCPSO(N, maxFE_DCMOCPSO_OneSeg, problemParameter, param_DCMOCPSO_OneSeg));

%% Score
meanHV_DCMOCPSO_Full   = mean(hvLast_DCMOCPSO_Full);
meanHV_DCMOCPSO_Base   = mean(hvLast_DCMOCPSO_Base);
meanHV_DCMOCPSO_OneSeg = mean(hvLast_DCMOCPSO_OneSeg);

fprintf('\n=== Summary (n=%d) ===\n', n);
fprintf('DCMOCPSO_Full   : mean(last HV) = %.6e (maxFE=%d, actualFE mean=%.1f)\n', meanHV_DCMOCPSO_Full, maxFE_DCMOCPSO, mean(actualFE_DCMOCPSO_Full));
fprintf('DCMOCPSO_Base   : mean(last HV) = %.6e (maxFE=%d, actualFE mean=%.1f)\n', meanHV_DCMOCPSO_Base, maxFE_DCMOCPSO, mean(actualFE_DCMOCPSO_Base));
fprintf('DCMOCPSO_OneSeg : mean(last HV) = %.6e (maxFE=%d, actualFE mean=%.1f)\n', meanHV_DCMOCPSO_OneSeg, maxFE_DCMOCPSO_OneSeg, mean(actualFE_DCMOCPSO_OneSeg));

%% Plot bar chart only with smart y-axis
figure('Name', 'HV comparison', 'Position', [200, 200, 600, 500]);

% Algorithm colors
colorDCMOCPSO_Full = [0.2, 0.4, 0.8];    % Blue
colorDCMOCPSO_Base = [0.2, 0.7, 0.3];    % Green
colorDCMOCPSO_OneSeg = [0.8, 0.2, 0.2];  % Red

x = categorical({'DCMOCPSO\_Full','DCMOCPSO\_Base','DCMOCPSO\_OneSeg'});
x = reordercats(x, {'DCMOCPSO\_Full','DCMOCPSO\_Base','DCMOCPSO\_OneSeg'});

b = bar(x, [meanHV_DCMOCPSO_Full, meanHV_DCMOCPSO_Base, meanHV_DCMOCPSO_OneSeg]);
b.FaceColor = 'flat';
b.CData(1,:) = colorDCMOCPSO_Full;
b.CData(2,:) = colorDCMOCPSO_Base;
b.CData(3,:) = colorDCMOCPSO_OneSeg;

ylabel('Mean of last HV', 'FontSize', 12, 'FontWeight', 'bold');
title('Algorithm Comparison: HV Metric', 'FontSize', 14, 'FontWeight', 'bold');
grid on;

% Smart y-axis: set limits near min/max values instead of starting from 0
allHV = [meanHV_DCMOCPSO_Full, meanHV_DCMOCPSO_Base, meanHV_DCMOCPSO_OneSeg];
hvMin = min(allHV);
hvMax = max(allHV);
hvRange = hvMax - hvMin;

if hvRange > 0
    % Expand by 15% margin on both sides
    margin = hvRange * 0.15;
    ylim([hvMin - margin, hvMax + margin]);
else
    % If values are identical, show a small range around the value
    ylim([hvMin * 0.95, hvMin * 1.05]);
end


%% ===================== local functions =====================
function [hvLast, hvSeries, actualFE] = runOrLoad(algName, cacheFile, n, runOneFn)
    hvLast = nan(1,n);
    hvSeries = cell(1,n);
    actualFE = nan(1,n);

    if exist(cacheFile, 'file') == 2
        S = load(cacheFile);
        if isfield(S, 'runs')
            runs = S.runs;
            if numel(runs) >= n
                fprintf('[%s] load %d run(s) from cache: %s\n', algName, n, cacheFile);
                for i = 1:n
                    hvSeries{i} = runs(i).hv;
                    hvLast(i)   = runs(i).hv(end);
                    actualFE(i) = runs(i).actualFE;
                end
                return;
            end
        end
    end

    fprintf('[%s] cache miss -> run %d time(s)\n', algName, n);
    runs = struct('hv', {}, 'actualFE', {});
    for i = 1:n
        fprintf('  Run %d/%d...\n', i, n);
        [hvSeries{i}, actualFE(i)] = runOneFn();
        hvLast(i) = hvSeries{i}(end);
        runs(i).hv = hvSeries{i};
        runs(i).actualFE = actualFE(i);
    end
    save(cacheFile, 'runs');
end

function [hv, actualFE] = runOne_DCMOCPSO(N, maxFE, problemParameter, param_DCMOCPSO)
    Algorithm = DCMOCPSO('parameter', param_DCMOCPSO);
    Problem   = UAVPathPlanning('N', N, 'maxFE', maxFE, 'parameter', problemParameter);
    Algorithm.Solve(Problem);
    hv = extractHV(Algorithm);
    actualFE = Problem.FE;
end

function hv = extractHV(Algorithm)
    m = Algorithm.Metric('HV');
    hv = m(:,2)';
    if isempty(hv)
        error('No HV metric captured. Ensure Problem.M>1 and Algorithm saved results.');
    end
end
