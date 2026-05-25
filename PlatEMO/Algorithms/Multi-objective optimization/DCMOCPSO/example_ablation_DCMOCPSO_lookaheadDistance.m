% example_ablation_DCMOCPSO_lookaheadDistance.m
%
% One-factor ablation/sensitivity study for the lookahead distance used by
% the switchMethod=2 proactive handover algorithm in UAVPathPlanning.
%
% The eighth UAVPathPlanning parameter is lookaheadDistance, measured in
% meters. Each distance setting is cached independently. After every
% successful independent run, the corresponding cache file is saved
% immediately.

clear; clc; close all;

%% Settings
n = 10;

% Start and warm up the parallel pool before per-run timing begins, so the
% parpool startup cost is not counted in any algorithm runtime.
enableParallelPool = true;
parallelPoolProfile = 'Processes';
parallelPoolNumWorkers = [];
prepareParallelPool(enableParallelPool, parallelPoolProfile, parallelPoolNumWorkers);

% UAVPathPlanning base parameters:
% {bsPerKm2, velocity, TTT, switchThreshold, obstacleMethod, P_tx,
%  switchMethod, lookaheadDistance}
N = 20;
baseProblemParameter = {20, 20, 5, -101.5, 0, 30, 2, 500};

% Lookahead distances to compare. 0 means the proactive score only sees the
% current preset waypoint; 500 is the current default used by prior scripts.
lookaheadDistanceList = [0, 100, 300, 500, 700, 900, 1100, 1300, 1500, 1700, 1900, 2100, 2300];

% DCMOCPSO FULL settings.
maxFE_DCMOCPSO = 100;
numSegments = 5;
segmentOverlap = 2;
lambda = 0.5;
cGuide = 0.3;
useDynamicGrouping = true;
useDynamicMutation = true;
useEk = true;
uniformPointMultiplier = 3;
param_DCMOCPSO = {numSegments, segmentOverlap, lambda, cGuide, ...
    useDynamicGrouping, useDynamicMutation, useEk, uniformPointMultiplier};

% Result cache. Use experiment-specific files to avoid mixing with older
% DCMOCPSO ablation caches.
cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

commonConfig = struct( ...
    'N', N, ...
    'maxFE', maxFE_DCMOCPSO, ...
    'baseProblemParameter', {baseProblemParameter}, ...
    'param_DCMOCPSO', {param_DCMOCPSO}, ...
    'numSegments', numSegments, ...
    'segmentOverlap', segmentOverlap, ...
    'lambda', lambda, ...
    'cGuide', cGuide, ...
    'useDynamicGrouping', useDynamicGrouping, ...
    'useDynamicMutation', useDynamicMutation, ...
    'useEk', useEk, ...
    'uniformPointMultiplier', uniformPointMultiplier);

%% Run or load lookahead-distance groups
numGroups = numel(lookaheadDistanceList);
groupNames = arrayfun(@(v) sprintf('lookahead_%sm', valueTag(v)), lookaheadDistanceList, 'UniformOutput', false);
hvLastAll = cell(1, numGroups);
hvSeriesAll = cell(1, numGroups);
actualFEAll = cell(1, numGroups);
runtimeAll = cell(1, numGroups);

fprintf('\n=== DCMOCPSO lookahead distance ablation (n=%d) ===\n', n);
fprintf('Common settings: N=%d, maxFE=%d, numSegments=%d, segmentOverlap=%d, lambda=%.2f, c_guide=%.2f, uniformPointMultiplier=%d\n', ...
    N, maxFE_DCMOCPSO, numSegments, segmentOverlap, lambda, cGuide, uniformPointMultiplier);

for i = 1:numGroups
    lookaheadDistance = lookaheadDistanceList(i);
    problemParameter = makeProblemParameter(baseProblemParameter, lookaheadDistance);
    cacheFile = fullfile(cacheDir, sprintf('LookaheadDistance_%s_HV_runs.mat', groupNames{i}));

    [hvLastAll{i}, hvSeriesAll{i}, actualFEAll{i}, runtimeAll{i}] = runOrLoad( ...
        groupNames{i}, cacheFile, n, ...
        @() runOne_DCMOCPSO(N, maxFE_DCMOCPSO, problemParameter, param_DCMOCPSO), ...
        true);
end

%% Summary
meanHV = nan(1, numGroups);
stdHV = nan(1, numGroups);
meanRuntime = nan(1, numGroups);
stdRuntime = nan(1, numGroups);
meanActualFE = nan(1, numGroups);
validCount = zeros(1, numGroups);

fprintf('\n--- Lookahead distance summary ---\n');
for i = 1:numGroups
    validIdx = ~isnan(hvLastAll{i});
    validCount(i) = sum(validIdx);
    meanHV(i) = mean(hvLastAll{i}(validIdx));
    stdHV(i) = std(hvLastAll{i}(validIdx));
    meanRuntime(i) = mean(runtimeAll{i}(validIdx));
    stdRuntime(i) = std(runtimeAll{i}(validIdx));
    meanActualFE(i) = mean(actualFEAll{i}(validIdx));

    fprintf('%-18s : lookaheadDistance=%g m, mean(last HV)=%.6e, std=%.6e (valid=%d/%d, actualFE mean=%.1f, runtime mean=%.2fs, std=%.2fs)\n', ...
        groupNames{i}, lookaheadDistanceList(i), meanHV(i), stdHV(i), validCount(i), n, meanActualFE(i), meanRuntime(i), stdRuntime(i));
end

results = struct();
results.experimentName = 'LookaheadDistanceSweep';
results.groupNames = groupNames;
results.lookaheadDistanceList = lookaheadDistanceList;
results.commonConfig = commonConfig;
results.hvLastAll = hvLastAll;
results.hvSeriesAll = hvSeriesAll;
results.actualFEAll = actualFEAll;
results.runtimeAll = runtimeAll;
results.meanHV = meanHV;
results.stdHV = stdHV;
results.meanRuntime = meanRuntime;
results.stdRuntime = stdRuntime;
results.meanActualFE = meanActualFE;
results.validCount = validCount;

summaryFile = fullfile(cacheDir, 'LookaheadDistance_sweep_summary.mat');
save(summaryFile, 'results');
fprintf('\nSummary saved to: %s\n', summaryFile);

%% Plot comparisons
colors = lines(numGroups);

plotBarComparison('lookahead distance sweep HV', 'Mean of last HV', ...
    'DCMOCPSO lookahead distance sweep: HV', groupNames, meanHV, stdHV, colors, [200, 200, 860, 520], true);

plotBarComparison('lookahead distance sweep runtime', 'Mean runtime (seconds)', ...
    'DCMOCPSO lookahead distance sweep: Runtime', groupNames, meanRuntime, stdRuntime, colors, [1120, 200, 860, 520], false);


%% ===================== local functions =====================
function problemParameter = makeProblemParameter(baseProblemParameter, lookaheadDistance)
    problemParameter = baseProblemParameter;
    problemParameter{7} = 2;
    problemParameter{8} = lookaheadDistance;
end

function tag = valueTag(value)
    tag = strrep(sprintf('%g', value), '.', 'p');
end

function [hvLast, hvSeries, actualFE, runtime, lastAlgorithm, lastProblem] = runOrLoad(algName, cacheFile, n, runOneFn, allowRun)
    hvLast = nan(1,n);
    hvSeries = cell(1,n);
    actualFE = nan(1,n);
    runtime = nan(1,n);
    lastAlgorithm = [];
    lastProblem = [];

    runs = struct('hv', {}, 'actualFE', {}, 'runtime', {});
    if exist(cacheFile, 'file') == 2
        S = load(cacheFile);
        if isfield(S, 'runs')
            runs = S.runs;
            loadCount = min(numel(runs), n);
            fprintf('[%s] load %d/%d run(s) from cache: %s\n', algName, loadCount, n, cacheFile);
            for i = 1:loadCount
                if isfield(runs, 'hv') && ~isempty(runs(i).hv)
                    hvSeries{i} = runs(i).hv;
                    hvLast(i) = runs(i).hv(end);
                end
                if isfield(runs, 'actualFE')
                    actualFE(i) = runs(i).actualFE;
                end
                if isfield(runs, 'runtime')
                    runtime(i) = runs(i).runtime;
                end
            end
            if loadCount >= n
                return;
            end
        end
    end

    if ~allowRun
        fprintf('[%s] cache is missing or incomplete, and recomputation is disabled. Missing runs remain NaN.\n', algName);
        return;
    end

    startRun = find(isnan(hvLast), 1);
    if isempty(startRun)
        return;
    end

    fprintf('[%s] cache miss/incomplete -> run %d time(s)\n', algName, n - startRun + 1);

    for i = startRun:n
        fprintf('\n>>> Current algorithm: %s\n', algName);
        fprintf('  Run %d/%d...\n', i, n);
        try
            [hvSeries{i}, actualFE(i), runtime(i), lastAlgorithm, lastProblem] = runOneFn();
            hvLast(i) = hvSeries{i}(end);
            runs(i).hv = hvSeries{i};
            runs(i).actualFE = actualFE(i);
            runs(i).runtime = runtime(i);
            save(cacheFile, 'runs');
            fprintf('  Run %d/%d saved to: %s\n', i, n, cacheFile);
        catch ME
            fprintf('  Run %d/%d FAILED: %s\n', i, n, ME.message);
        end
    end
end

function prepareParallelPool(enableParallelPool, poolProfile, numWorkers)
    if ~enableParallelPool
        return;
    end

    if isempty(ver('parallel'))
        fprintf('[Parallel] Parallel Computing Toolbox is unavailable; parfor will run serially.\n');
        return;
    end

    pool = gcp('nocreate');
    if isempty(pool)
        fprintf('[Parallel] Starting parallel pool before algorithm timing...\n');
        if isempty(numWorkers)
            pool = parpool(poolProfile);
        else
            pool = parpool(poolProfile, numWorkers);
        end
    else
        fprintf('[Parallel] Reusing existing parallel pool with %d worker(s).\n', pool.NumWorkers);
    end

    warmup = zeros(1, pool.NumWorkers);
    parfor i = 1:pool.NumWorkers
        warmup(i) = i;
    end
    fprintf('[Parallel] Pool ready with %d worker(s).\n', pool.NumWorkers);
end

function [hv, actualFE, runtime, Algorithm, Problem] = runOne_DCMOCPSO(N, maxFE, problemParameter, param_DCMOCPSO)
    Algorithm = DCMOCPSO('parameter', param_DCMOCPSO, 'outputFcn', @(~,~)[]);
    Problem = UAVPathPlanning('N', N, 'maxFE', maxFE, 'parameter', problemParameter);
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

function plotBarComparison(figName, yLabelText, titleText, groupNames, values, errors, colors, position, smartYLim)
    figure('Name', figName, 'Position', position);
    x = categorical(groupNames);
    x = reordercats(x, groupNames);

    b = bar(x, values);
    b.FaceColor = 'flat';
    for i = 1:size(colors, 1)
        b.CData(i,:) = colors(i,:);
    end
    hold on;

    xPos = 1:numel(groupNames);
    errorbar(xPos, values, errors, 'k.', 'LineWidth', 1.1, 'CapSize', 10);

    ylabel(yLabelText, 'FontSize', 12, 'FontWeight', 'bold');
    title(titleText, 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    xtickangle(20);

    if smartYLim
        validValues = values(~isnan(values));
        if ~isempty(validValues)
            validErrors = errors(~isnan(values));
            validErrors(isnan(validErrors)) = 0;
            vMin = min(validValues - validErrors);
            vMax = max(validValues + validErrors);
            vRange = vMax - vMin;
            if vRange > 0
                margin = vRange * 0.15;
                ylim([vMin - margin, vMax + margin]);
            elseif vMin ~= 0
                ylim([vMin * 0.95, vMin * 1.05]);
            end
        end
    end
end
