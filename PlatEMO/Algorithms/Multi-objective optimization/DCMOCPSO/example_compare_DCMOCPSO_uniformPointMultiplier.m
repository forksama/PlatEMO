% example_compare_DCMOCPSO_uniformPointMultiplier.m
%
% Ablation study for DCMOCPSO on UAVPathPlanning.
%
% Compare different reference-vector multipliers used inside
% MOCPSO_Ek_Flexible:
%     [V,~] = UniformPoint(Problem.N * uniformPointMultiplier, Problem.M)
%
% Other DCMOCPSO parameters use the FULL configuration.

clear; clc; close all;

%% Settings
n = 8;

% Start and warm up the parallel pool before per-run timing begins, so the
% parpool startup cost is not counted in any algorithm runtime.
enableParallelPool = true;
parallelPoolProfile = 'Processes';
parallelPoolNumWorkers = [];
prepareParallelPool(enableParallelPool, parallelPoolProfile, parallelPoolNumWorkers);

% UAVPathPlanning parameters.
N = 20;
problemParameter_Lookahead = {20, 20, 5, -101.5, 0, 30, 2, 500};

% DCMOCPSO FULL settings.
maxFE_DCMOCPSO = 100;
numSegments = 5;
param_Full_Base = {numSegments, 2, 0.5, 0.3, true, true, true};

% Reference-vector multipliers to compare. The DCMOCPSO default is 3.
uniformPointMultipliers = [1, 3, 5, 10, 20];

% Result cache. Use multiplier-specific files to avoid mixing different
% parameter settings with older FULL cache results.
cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

%% Run or load groups
numGroups = numel(uniformPointMultipliers);
groupNames = cell(1, numGroups);
hvLastAll = cell(1, numGroups);
hvSeriesAll = cell(1, numGroups);
actualFEAll = cell(1, numGroups);
runtimeAll = cell(1, numGroups);
meanSignalAll = cell(1, numGroups);
meanSwitchCountAll = cell(1, numGroups);
meanCoverageRatioAll = cell(1, numGroups);
objMetricSummaryAll = cell(1, numGroups);

for i = 1:numGroups
    multiplier = uniformPointMultipliers(i);
    groupNames{i} = sprintf('UPx%d', multiplier);
    cacheFile = fullfile(cacheDir, sprintf('Full_Lookahead_UPx%d_HV_runs.mat', multiplier));
    param_Full = [param_Full_Base, {multiplier}];

    [hvLastAll{i}, hvSeriesAll{i}, actualFEAll{i}, runtimeAll{i}, meanSignalAll{i}, meanSwitchCountAll{i}, meanCoverageRatioAll{i}, objMetricSummaryAll{i}] = runOrLoad( ...
        groupNames{i}, cacheFile, n, ...
        @() runOne_DCMOCPSO(N, maxFE_DCMOCPSO, problemParameter_Lookahead, param_Full), ...
        true);
end

%% Summary
meanHV = nan(1, numGroups);
meanRuntime = nan(1, numGroups);
meanActualFE = nan(1, numGroups);
meanSignal = nan(1, numGroups);
meanSwitchCount = nan(1, numGroups);
meanCoverageRatio = nan(1, numGroups);
validCount = zeros(1, numGroups);

fprintf('\n=== UniformPoint multiplier ablation summary (n=%d) ===\n', n);
fprintf('All groups use DCMOCPSO FULL parameters and maxFE=%d.\n', maxFE_DCMOCPSO);
for i = 1:numGroups
    validIdx = ~isnan(hvLastAll{i});
    validCount(i) = sum(validIdx);
    meanHV(i) = mean(hvLastAll{i}(validIdx));
    meanRuntime(i) = mean(runtimeAll{i}(validIdx));
    meanActualFE(i) = mean(actualFEAll{i}(validIdx));
    meanSignal(i) = meanValid(meanSignalAll{i}(validIdx));
    meanSwitchCount(i) = meanValid(meanSwitchCountAll{i}(validIdx));
    meanCoverageRatio(i) = meanValid(meanCoverageRatioAll{i}(validIdx));

    fprintf('%-6s : mean(last HV) = %.6e (valid=%d/%d, multiplier=%d, actualFE mean=%.1f, runtime mean=%.2fs, signal mean=%.4f, switch mean=%.4f, coverage mean=%.4f)\n', ...
        groupNames{i}, meanHV(i), validCount(i), n, uniformPointMultipliers(i), meanActualFE(i), meanRuntime(i), meanSignal(i), meanSwitchCount(i), meanCoverageRatio(i));
end

results = struct();
results.experimentName = 'UniformPointMultiplierSweep';
results.groupNames = groupNames;
results.uniformPointMultipliers = uniformPointMultipliers;
results.hvLastAll = hvLastAll;
results.hvSeriesAll = hvSeriesAll;
results.actualFEAll = actualFEAll;
results.runtimeAll = runtimeAll;
results.meanSignalAll = meanSignalAll;
results.meanSwitchCountAll = meanSwitchCountAll;
results.meanCoverageRatioAll = meanCoverageRatioAll;
results.objMetricSummaryAll = objMetricSummaryAll;
results.meanHV = meanHV;
results.meanRuntime = meanRuntime;
results.meanActualFE = meanActualFE;
results.meanSignal = meanSignal;
results.meanSwitchCount = meanSwitchCount;
results.meanCoverageRatio = meanCoverageRatio;
results.validCount = validCount;
summaryFile = fullfile(cacheDir, 'UniformPointMultiplier_summary.mat');
save(summaryFile, 'results');
fprintf('\nSummary saved to: %s\n', summaryFile);

%% Plot comparisons
colors = lines(numGroups);

plotBarComparison('HV comparison', 'Mean of last HV', ...
    'DCMOCPSO FULL: UniformPoint Multiplier HV', groupNames, meanHV, colors, [200, 200, 760, 500], true);

plotBarComparison('Runtime comparison', 'Mean runtime (seconds)', ...
    'DCMOCPSO FULL: UniformPoint Multiplier Runtime', groupNames, meanRuntime, colors, [980, 200, 760, 500], false);


%% ===================== local functions =====================
function [hvLast, hvSeries, actualFE, runtime, meanSignal, meanSwitchCount, meanCoverageRatio, objMetricSummary, lastAlgorithm, lastProblem] = runOrLoad(algName, cacheFile, n, runOneFn, allowRun)
    hvLast = nan(1,n);
    hvSeries = cell(1,n);
    actualFE = nan(1,n);
    runtime = nan(1,n);
    meanSignal = nan(1,n);
    meanSwitchCount = nan(1,n);
    meanCoverageRatio = nan(1,n);
    objMetricSummary = cell(1,n);
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
                if isfield(runs, 'meanSignal') && ~isempty(runs(i).meanSignal)
                    meanSignal(i) = runs(i).meanSignal;
                end
                if isfield(runs, 'meanSwitchCount') && ~isempty(runs(i).meanSwitchCount)
                    meanSwitchCount(i) = runs(i).meanSwitchCount;
                end
                if isfield(runs, 'meanCoverageRatio') && ~isempty(runs(i).meanCoverageRatio)
                    meanCoverageRatio(i) = runs(i).meanCoverageRatio;
                end
                if isfield(runs, 'objMetricSummary') && ~isempty(runs(i).objMetricSummary)
                    objMetricSummary{i} = runs(i).objMetricSummary;
                end
            end
            if loadCount >= n && all(~isnan(hvLast)) && all(~isnan(meanSignal)) && all(~isnan(meanSwitchCount)) && all(~isnan(meanCoverageRatio))
                return;
            end
        end
    end

    if ~allowRun
        fprintf('[%s] cache is missing or incomplete, and recomputation is disabled. Missing runs remain NaN.\n', algName);
        return;
    end

    startRun = find(isnan(hvLast) | isnan(meanSignal) | isnan(meanSwitchCount) | isnan(meanCoverageRatio), 1);
    if isempty(startRun)
        return;
    end

    fprintf('[%s] cache miss/incomplete -> run %d time(s)\n', algName, n - startRun + 1);
    runs = struct('hv', {}, 'actualFE', {}, 'runtime', {}, 'meanSignal', {}, 'meanSwitchCount', {}, 'meanCoverageRatio', {}, 'objMetricSummary', {});
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
            [hvSeries{i}, actualFE(i), runtime(i), objMetricSummary{i}, lastAlgorithm, lastProblem] = runOneFn();
            hvLast(i) = hvSeries{i}(end);
            meanSignal(i) = objMetricSummary{i}.meanSignal;
            meanSwitchCount(i) = objMetricSummary{i}.meanSwitchCount;
            meanCoverageRatio(i) = objMetricSummary{i}.meanCoverageRatio;
            runs(i).hv = hvSeries{i};
            runs(i).actualFE = actualFE(i);
            runs(i).runtime = runtime(i);
            runs(i).meanSignal = meanSignal(i);
            runs(i).meanSwitchCount = meanSwitchCount(i);
            runs(i).meanCoverageRatio = meanCoverageRatio(i);
            runs(i).objMetricSummary = objMetricSummary{i};
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

function [hv, actualFE, runtime, objMetricSummary, Algorithm, Problem] = runOne_DCMOCPSO(N, maxFE, problemParameter, param_DCMOCPSO)
    Algorithm = DCMOCPSO('parameter', param_DCMOCPSO, 'outputFcn', @(~,~)[]);
    Problem = UAVPathPlanning('N', N, 'maxFE', maxFE, 'parameter', problemParameter);
    tStart = tic;
    Algorithm.Solve(Problem);
    runtime = toc(tStart);
    hv = extractHV(Algorithm);
    objMetricSummary = extractObjectiveMetrics(Algorithm);
    actualFE = Problem.FE;
end

function hv = extractHV(Algorithm)
    m = Algorithm.Metric('HV');
    hv = m(:,2)';
    if isempty(hv)
        error('No HV metric captured. Ensure Problem.M>1 and Algorithm saved results.');
    end
end

function objMetricSummary = extractObjectiveMetrics(Algorithm)
    objMetricSummary = struct('meanSignal', NaN, 'meanSwitchCount', NaN, ...
        'meanCoverageRatio', NaN, 'finalPopulationSize', 0);
    if isempty(Algorithm.result)
        return;
    end

    finalPopulation = Algorithm.result{end, 2};
    if isempty(finalPopulation)
        return;
    end

    popObj = finalPopulation.objs;
    if isempty(popObj)
        return;
    end

    objMetricSummary.finalPopulationSize = size(popObj, 1);
    objMetricSummary.meanSignal = meanValid(-popObj(:, 1));
    objMetricSummary.meanSwitchCount = meanValid(popObj(:, 2));
    if size(popObj, 2) >= 3
        objMetricSummary.meanCoverageRatio = meanValid(-popObj(:, 3));
    end
end

function value = meanValid(values)
    values = values(~isnan(values) & isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = mean(values);
    end
end

function plotBarComparison(figName, yLabelText, titleText, groupNames, values, colors, position, smartYLim)
    figure('Name', figName, 'Position', position);
    x = categorical(groupNames);
    x = reordercats(x, groupNames);

    b = bar(x, values);
    b.FaceColor = 'flat';
    for i = 1:size(colors, 1)
        b.CData(i,:) = colors(i,:);
    end

    ylabel(yLabelText, 'FontSize', 12, 'FontWeight', 'bold');
    title(titleText, 'FontSize', 14, 'FontWeight', 'bold');
    grid on;

    if smartYLim
        validValues = values(~isnan(values));
        if ~isempty(validValues)
            vMin = min(validValues);
            vMax = max(validValues);
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
