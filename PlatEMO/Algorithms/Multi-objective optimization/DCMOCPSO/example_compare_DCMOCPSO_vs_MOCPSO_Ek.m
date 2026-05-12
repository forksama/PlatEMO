% example_compare_DCMOCPSO_vs_MOCPSO_Ek.m
% 
% Ablation study for DCMOCPSO on UAVPathPlanning
%
% Compare four configurations (incremental ablation):
% 1) OneSeg:            {1, 2, 0.5, 0.3, false, false, false} + switchMethod=0 (基准)
% 2) OneSeg_Lookahead:  {1, 2, 0.5, 0.3, false, false, false} + switchMethod=2 (加前瞻性算法)
% 3) Seg_Lookahead:     {5, 2, 0.5, 0.3, false, false, false} + switchMethod=2 (加分段)
% 4) Full_Lookahead:    {5, 2, 0.5, 0.3, true,  true,  true}  + switchMethod=2 (加full增强)
% Metric: mean of the last HV value across n runs

clear; clc; close all;

%% Settings
n = 30;

% UAVPathPlanning parameters
N = 20;
problemParameter_Base      = {20, 20, 5, -101.5, 0, 30, 0, 500};  % switchMethod=0（基准）
problemParameter_Lookahead = {20, 20, 5, -101.5, 0, 30, 2, 500};  % switchMethod=2（前瞻性）

% DCMOCPSO settings
maxFE_DCMOCPSO = 100;
numSegments = 5;
% param_DCMOCPSO: {numSegments, segmentOverlap, lambda, c_guide, useDynamicGrouping, useDynamicMutation, useEk}
param_OneSeg      = {1, 2, 0.5, 0.3, false, false, false};
param_Seg         = {numSegments, 2, 0.5, 0.3, false, false, false};
param_Full        = {numSegments, 2, 0.5, 0.3, true, true, true};

% Result cache
cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

cacheFile_OneSeg           = fullfile(cacheDir, 'OneSeg_HV_runs.mat');
cacheFile_OneSeg_Lookahead = fullfile(cacheDir, 'OneSeg_Lookahead_HV_runs.mat');
cacheFile_Seg_Lookahead    = fullfile(cacheDir, 'Seg_Lookahead_HV_runs.mat');
cacheFile_Full_Lookahead   = fullfile(cacheDir, 'Full_Lookahead_HV_runs.mat');

%% Run ablation settings (or load cache)

% 4) Full_Lookahead: Full配置+前瞻性切换算法（先运行，用于计算单段配置的maxFE）
[hvLast_Full_Lookahead, hvSeries_Full_Lookahead, actualFE_Full_Lookahead, runtime_Full_Lookahead, Algorithm_Full_Lookahead, Problem_Full_Lookahead] = runOrLoad( ...
    'Full_Lookahead', cacheFile_Full_Lookahead, n, @() runOne_DCMOCPSO(N, maxFE_DCMOCPSO, problemParameter_Lookahead, param_Full));

% OneSeg的maxFE基于Full_Lookahead的实际FE按段均分（确保公平对比）
maxFE_OneSeg = round(mean(actualFE_Full_Lookahead(~isnan(actualFE_Full_Lookahead))) / numSegments);

% 3) Seg_Lookahead: 添加分段算法（Base配置）+前瞻性切换算法
[hvLast_Seg_Lookahead, hvSeries_Seg_Lookahead, actualFE_Seg_Lookahead, runtime_Seg_Lookahead, Algorithm_Seg_Lookahead, Problem_Seg_Lookahead] = runOrLoad( ...
    'Seg_Lookahead', cacheFile_Seg_Lookahead, n, @() runOne_DCMOCPSO(N, maxFE_DCMOCPSO, problemParameter_Lookahead, param_Seg));

% 1) OneSeg: 基准（单段+无增强+switchMethod=0）
[hvLast_OneSeg, hvSeries_OneSeg, actualFE_OneSeg, runtime_OneSeg, Algorithm_OneSeg, Problem_OneSeg] = runOrLoad( ...
    'OneSeg', cacheFile_OneSeg, n, @() runOne_DCMOCPSO(N, maxFE_OneSeg, problemParameter_Base, param_OneSeg));

% 2) OneSeg_Lookahead: OneSeg基础上使用前瞻性切换算法
[hvLast_OneSeg_Lookahead, hvSeries_OneSeg_Lookahead, actualFE_OneSeg_Lookahead, runtime_OneSeg_Lookahead, Algorithm_OneSeg_Lookahead, Problem_OneSeg_Lookahead] = runOrLoad( ...
    'OneSeg_Lookahead', cacheFile_OneSeg_Lookahead, n, @() runOne_DCMOCPSO(N, maxFE_OneSeg, problemParameter_Lookahead, param_OneSeg));

%% Score（忽略NaN）
validIdx_OneSeg           = ~isnan(hvLast_OneSeg);
validIdx_OneSeg_Lookahead = ~isnan(hvLast_OneSeg_Lookahead);
validIdx_Seg_Lookahead    = ~isnan(hvLast_Seg_Lookahead);
validIdx_Full_Lookahead   = ~isnan(hvLast_Full_Lookahead);

meanHV_OneSeg           = mean(hvLast_OneSeg(validIdx_OneSeg));
meanHV_OneSeg_Lookahead = mean(hvLast_OneSeg_Lookahead(validIdx_OneSeg_Lookahead));
meanHV_Seg_Lookahead    = mean(hvLast_Seg_Lookahead(validIdx_Seg_Lookahead));
meanHV_Full_Lookahead   = mean(hvLast_Full_Lookahead(validIdx_Full_Lookahead));

meanRuntime_OneSeg           = mean(runtime_OneSeg(validIdx_OneSeg));
meanRuntime_OneSeg_Lookahead = mean(runtime_OneSeg_Lookahead(validIdx_OneSeg_Lookahead));
meanRuntime_Seg_Lookahead    = mean(runtime_Seg_Lookahead(validIdx_Seg_Lookahead));
meanRuntime_Full_Lookahead   = mean(runtime_Full_Lookahead(validIdx_Full_Lookahead));

meanActualFE_OneSeg           = mean(actualFE_OneSeg(validIdx_OneSeg));
meanActualFE_OneSeg_Lookahead = mean(actualFE_OneSeg_Lookahead(validIdx_OneSeg_Lookahead));
meanActualFE_Seg_Lookahead    = mean(actualFE_Seg_Lookahead(validIdx_Seg_Lookahead));
meanActualFE_Full_Lookahead   = mean(actualFE_Full_Lookahead(validIdx_Full_Lookahead));

fprintf('\n=== Summary (n=%d) ===\n', n);
fprintf('OneSeg           : mean(last HV) = %.6e (valid=%d/%d, maxFE=%d, actualFE mean=%.1f, runtime mean=%.2fs)\n', ...
    meanHV_OneSeg, sum(validIdx_OneSeg), n, maxFE_OneSeg, meanActualFE_OneSeg, meanRuntime_OneSeg);
fprintf('OneSeg_Lookahead : mean(last HV) = %.6e (valid=%d/%d, maxFE=%d, actualFE mean=%.1f, runtime mean=%.2fs)\n', ...
    meanHV_OneSeg_Lookahead, sum(validIdx_OneSeg_Lookahead), n, maxFE_OneSeg, meanActualFE_OneSeg_Lookahead, meanRuntime_OneSeg_Lookahead);
fprintf('Seg_Lookahead    : mean(last HV) = %.6e (valid=%d/%d, maxFE=%d, actualFE mean=%.1f, runtime mean=%.2fs)\n', ...
    meanHV_Seg_Lookahead, sum(validIdx_Seg_Lookahead), n, maxFE_DCMOCPSO, meanActualFE_Seg_Lookahead, meanRuntime_Seg_Lookahead);
fprintf('Full_Lookahead   : mean(last HV) = %.6e (valid=%d/%d, maxFE=%d, actualFE mean=%.1f, runtime mean=%.2fs)\n', ...
    meanHV_Full_Lookahead, sum(validIdx_Full_Lookahead), n, maxFE_DCMOCPSO, meanActualFE_Full_Lookahead, meanRuntime_Full_Lookahead);

%% Plot bar chart with smart y-axis
figure('Name', 'HV comparison', 'Position', [200, 200, 700, 500]);

colorOneSeg           = [0.8, 0.2, 0.2];  % Red
colorOneSeg_Lookahead = [0.9, 0.6, 0.1];  % Orange
colorSeg_Lookahead    = [0.2, 0.7, 0.3];  % Green
colorFull_Lookahead   = [0.2, 0.4, 0.8];  % Blue

x = categorical({'OneSeg','OneSeg\_Lookahead','Seg\_Lookahead','Full\_Lookahead'});
x = reordercats(x, {'OneSeg','OneSeg\_Lookahead','Seg\_Lookahead','Full\_Lookahead'});

b = bar(x, [meanHV_OneSeg, meanHV_OneSeg_Lookahead, meanHV_Seg_Lookahead, meanHV_Full_Lookahead]);
b.FaceColor = 'flat';
b.CData(1,:) = colorOneSeg;
b.CData(2,:) = colorOneSeg_Lookahead;
b.CData(3,:) = colorSeg_Lookahead;
b.CData(4,:) = colorFull_Lookahead;

ylabel('Mean of last HV', 'FontSize', 12, 'FontWeight', 'bold');
title('Ablation Study: HV Metric', 'FontSize', 14, 'FontWeight', 'bold');
grid on;

allHV = [meanHV_OneSeg, meanHV_OneSeg_Lookahead, meanHV_Seg_Lookahead, meanHV_Full_Lookahead];
allHV = allHV(~isnan(allHV));
if numel(allHV) > 0
    hvMin = min(allHV); hvMax = max(allHV); hvRange = hvMax - hvMin;
    if hvRange > 0
        margin = hvRange * 0.15;
        ylim([hvMin - margin, hvMax + margin]);
    else
        ylim([hvMin * 0.95, hvMin * 1.05]);
    end
end

%% Plot runtime comparison
figure('Name', 'Runtime comparison', 'Position', [950, 200, 700, 500]);

xRuntime = categorical({'OneSeg','OneSeg\_Lookahead','Seg\_Lookahead','Full\_Lookahead'});
xRuntime = reordercats(xRuntime, {'OneSeg','OneSeg\_Lookahead','Seg\_Lookahead','Full\_Lookahead'});

br = bar(xRuntime, [meanRuntime_OneSeg, meanRuntime_OneSeg_Lookahead, meanRuntime_Seg_Lookahead, meanRuntime_Full_Lookahead]);
br.FaceColor = 'flat';
br.CData(1,:) = colorOneSeg;
br.CData(2,:) = colorOneSeg_Lookahead;
br.CData(3,:) = colorSeg_Lookahead;
br.CData(4,:) = colorFull_Lookahead;

ylabel('Mean runtime (seconds)', 'FontSize', 12, 'FontWeight', 'bold');
title('Ablation Study: Runtime', 'FontSize', 14, 'FontWeight', 'bold');
grid on;


%% ===================== local functions =====================
function [hvLast, hvSeries, actualFE, runtime, lastAlgorithm, lastProblem] = runOrLoad(algName, cacheFile, n, runOneFn)
    hvLast = nan(1,n);
    hvSeries = cell(1,n);
    actualFE = nan(1,n);
    runtime = nan(1,n);
    lastAlgorithm = [];
    lastProblem = [];

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
                    if isfield(runs, 'runtime')
                        runtime(i) = runs(i).runtime;
                    end
                end
                return;
            end
        end
    end

    fprintf('[%s] cache miss -> run %d time(s)\n', algName, n);
    runs = struct('hv', {}, 'actualFE', {}, 'runtime', {});
    for i = 1:n
        fprintf('  Run %d/%d...\n', i, n);
        try
            [hvSeries{i}, actualFE(i), runtime(i), lastAlgorithm, lastProblem] = runOneFn();
            hvLast(i) = hvSeries{i}(end);
            runs(i).hv = hvSeries{i};
            runs(i).actualFE = actualFE(i);
            runs(i).runtime = runtime(i);
        catch ME
            fprintf('  Run %d/%d FAILED: %s\n', i, n, ME.message);
            % 保留 NaN 值，继续运行下一次
        end
    end
    save(cacheFile, 'runs');
end

function [hv, actualFE, runtime, Algorithm, Problem] = runOne_DCMOCPSO(N, maxFE, problemParameter, param_DCMOCPSO)
    Algorithm = DCMOCPSO('parameter', param_DCMOCPSO);
    Problem   = UAVPathPlanning('N', N, 'maxFE', maxFE, 'parameter', problemParameter);
    tStart = tic;
    Algorithm.Solve(Problem);
    runtime = toc(tStart);
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
