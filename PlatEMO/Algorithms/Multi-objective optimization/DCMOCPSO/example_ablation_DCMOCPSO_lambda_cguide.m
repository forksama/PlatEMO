% example_ablation_DCMOCPSO_lambda_cguide.m
%
% Four-group ablation study for the E_k mechanisms in DCMOCPSO.
%
% Groups:
% 1) Base_NoEk          : disable the whole E_k extension with useEk=false.
% 2) EkSelectionOnly    : keep only the E_k reward in APD selection.
% 3) EkGuideOnly        : keep only the E_k-based guide particle update.
% 4) Full_EkSelectionGuide : enable both mechanisms.
%
% Metric: mean/std of the last HV value across n independent runs.

clear; clc; close all;

%% Settings
n = 10;

% Start and warm up the parallel pool before per-run timing begins, so the
% parpool startup cost is not counted in any algorithm runtime.
enableParallelPool = true;
parallelPoolProfile = 'Processes';
parallelPoolNumWorkers = [];
prepareParallelPool(enableParallelPool, parallelPoolProfile, parallelPoolNumWorkers);

% UAVPathPlanning parameters.
N = 20;
problemParameter_Lookahead = {20, 20, 5, -101.5, 0, 30, 2, 500};

% DCMOCPSO settings.
maxFE_DCMOCPSO = 100;
numSegments = 5;
segmentOverlap = 2;
useDynamicGrouping = true;
useDynamicMutation = true;
uniformPointMultiplier = 3;

% param_DCMOCPSO:
% {numSegments, segmentOverlap, lambda, c_guide, useDynamicGrouping,
%  useDynamicMutation, useEk, uniformPointMultiplier}
groupNames = { ...
    'Base_NoEk', ...
    'EkSelectionOnly', ...
    'EkGuideOnly', ...
    'Full_EkSelectionGuide'};

groupParams = { ...
    {numSegments, segmentOverlap, 0.5, 0.3, useDynamicGrouping, useDynamicMutation, false, uniformPointMultiplier}, ...
    {numSegments, segmentOverlap, 0.5, 0.0, useDynamicGrouping, useDynamicMutation, true,  uniformPointMultiplier}, ...
    {numSegments, segmentOverlap, 0.0, 0.3, useDynamicGrouping, useDynamicMutation, true,  uniformPointMultiplier}, ...
    {numSegments, segmentOverlap, 0.5, 0.3, useDynamicGrouping, useDynamicMutation, true,  uniformPointMultiplier}};

groupDescriptions = { ...
    'E_k disabled; lambda/c_guide are ignored by MOCPSO_Ek_Flexible.', ...
    'Only E_k APD selection reward is enabled: lambda=0.5, c_guide=0.', ...
    'Only E_k guide-particle velocity term is enabled: lambda=0, c_guide=0.3.', ...
    'Both E_k APD selection reward and guide-particle velocity term are enabled.'};

% Result cache. Use experiment-specific files to avoid mixing with older
% DCMOCPSO ablation caches.
cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

%% Run or load groups
numGroups = numel(groupNames);
hvLastAll = cell(1, numGroups);
hvSeriesAll = cell(1, numGroups);
actualFEAll = cell(1, numGroups);
runtimeAll = cell(1, numGroups);

for i = 1:numGroups
    cacheFile = fullfile(cacheDir, sprintf('LambdaCGuide_%s_HV_runs.mat', groupNames{i}));
    [hvLastAll{i}, hvSeriesAll{i}, actualFEAll{i}, runtimeAll{i}] = runOrLoad( ...
        groupNames{i}, cacheFile, n, ...
        @() runOne_DCMOCPSO(N, maxFE_DCMOCPSO, problemParameter_Lookahead, groupParams{i}), ...
        true);
end

%% Summary
meanHV = nan(1, numGroups);
stdHV = nan(1, numGroups);
meanRuntime = nan(1, numGroups);
stdRuntime = nan(1, numGroups);
meanActualFE = nan(1, numGroups);
validCount = zeros(1, numGroups);

fprintf('\n=== DCMOCPSO lambda/c_guide ablation summary (n=%d) ===\n', n);
fprintf('Common settings: N=%d, maxFE=%d, numSegments=%d, segmentOverlap=%d, uniformPointMultiplier=%d\n', ...
    N, maxFE_DCMOCPSO, numSegments, segmentOverlap, uniformPointMultiplier);

for i = 1:numGroups
    validIdx = ~isnan(hvLastAll{i});
    validCount(i) = sum(validIdx);
    meanHV(i) = mean(hvLastAll{i}(validIdx));
    stdHV(i) = std(hvLastAll{i}(validIdx));
    meanRuntime(i) = mean(runtimeAll{i}(validIdx));
    stdRuntime(i) = std(runtimeAll{i}(validIdx));
    meanActualFE(i) = mean(actualFEAll{i}(validIdx));

    fprintf('%-24s : mean(last HV) = %.6e, std = %.6e (valid=%d/%d, actualFE mean=%.1f, runtime mean=%.2fs, std=%.2fs)\n', ...
        groupNames{i}, meanHV(i), stdHV(i), validCount(i), n, meanActualFE(i), meanRuntime(i), stdRuntime(i));
    fprintf('  %s\n', groupDescriptions{i});
end

summaryFile = fullfile(cacheDir, 'LambdaCGuide_ablation_summary.mat');
save(summaryFile, 'groupNames', 'groupDescriptions', 'groupParams', 'meanHV', 'stdHV', ...
    'meanRuntime', 'stdRuntime', 'meanActualFE', 'validCount', 'n', 'N', ...
    'maxFE_DCMOCPSO', 'problemParameter_Lookahead');
fprintf('\nSummary saved to: %s\n', summaryFile);

%% Plot comparisons
colors = [ ...
    0.78, 0.20, 0.18; ...
    0.93, 0.58, 0.12; ...
    0.24, 0.64, 0.38; ...
    0.20, 0.38, 0.78];

plotBarComparison('lambda/c_guide ablation HV', 'Mean of last HV', ...
    'DCMOCPSO lambda/c\_guide ablation: HV', groupNames, meanHV, stdHV, colors, [200, 200, 860, 520], true);

plotBarComparison('lambda/c_guide ablation runtime', 'Mean runtime (seconds)', ...
    'DCMOCPSO lambda/c\_guide ablation: Runtime', groupNames, meanRuntime, stdRuntime, colors, [1120, 200, 860, 520], false);


%% ===================== local functions =====================
function [hvLast, hvSeries, actualFE, runtime, lastAlgorithm, lastProblem] = runOrLoad(algName, cacheFile, n, runOneFn, allowRun)
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
    runs = struct('hv', {}, 'actualFE', {}, 'runtime', {});
    if exist(cacheFile, 'file') == 2
        S = load(cacheFile);
        if isfield(S, 'runs')
            runs = S.runs;
        end
    end

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
    Algorithm = DCMOCPSO('parameter', param_DCMOCPSO);
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
