% example_ablation_UAVPathPlanning_switchMethod_OneSeg.m
%
% Isolated switch-method ablation under the same OneSeg algorithm setting
% across multiple maxFE budgets.
%
% Compared groups for each maxFE_OneSeg:
%   1) OneSeg           : {1, 2, 0.5, 0.3, false, false, false} + switchMethod=0
%   2) OneSeg_A3        : {1, 2, 0.5, 0.3, false, false, false} + switchMethod=3
%   3) OneSeg_Lookahead : {1, 2, 0.5, 0.3, false, false, false} + switchMethod=2
%
% The maxFE=400 case reuses the existing unprefixed cache files. The
% maxFE=200 and maxFE=800 cases use FE-prefixed cache files.
%
% Each run persists HV, runtime, actualFE, mean signal strength, mean switch
% count, and mean coverage ratio immediately after it finishes.

clear; clc; close all;

%% Settings
n = 20;

enableParallelPool = true;
parallelPoolProfile = 'Processes';
parallelPoolNumWorkers = [];
prepareParallelPool(enableParallelPool, parallelPoolProfile, parallelPoolNumWorkers);

N = 20;
maxFE_OneSegList = [200, 400, 800];

% UAVPathPlanning parameters:
% {bsPerKm2, velocity, TTT, switchThreshold, obstacleMethod, P_tx,
%  switchMethod, lookaheadDistance}
problemParameter_Base = {20, 20, 5, -101.5, 0, 30, 0, 500};
problemParameter_Base{7} = 0;
problemParameter_A3 = problemParameter_Base;
problemParameter_A3{7} = 3;
problemParameter_Lookahead = problemParameter_Base;
problemParameter_Lookahead{7} = 2;

% OneSeg algorithm parameters:
% {numSegments, segmentOverlap, lambda, c_guide,
%  useDynamicGrouping, useDynamicMutation, useEk}
param_OneSeg = {1, 2, 0.5, 0.3, false, false, false};

groupNames = {'OneSeg', 'OneSeg_A3', 'OneSeg_Lookahead'};
groupProblemParams = {problemParameter_Base, problemParameter_A3, problemParameter_Lookahead};

cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results', 'switch_method_oneseg');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

setResults = cell(1, numel(maxFE_OneSegList));

%% Run each maxFE budget
for setIdx = 1:numel(maxFE_OneSegList)
    maxFE_OneSeg = maxFE_OneSegList(setIdx);
    fprintf('\n\n================ OneSeg switch-method ablation: maxFE = %d ================\n', maxFE_OneSeg);
    fprintf('Algorithm parameter fixed to param_OneSeg={1,2,0.5,0.3,false,false,false}; only switchMethod changes.\n');

    numGroups = numel(groupNames);
    hvLastAll = cell(1, numGroups);
    hvSeriesAll = cell(1, numGroups);
    actualFEAll = cell(1, numGroups);
    runtimeAll = cell(1, numGroups);
    meanSignalAll = cell(1, numGroups);
    meanSwitchCountAll = cell(1, numGroups);
    meanCoverageRatioAll = cell(1, numGroups);
    objMetricSummaryAll = cell(1, numGroups);

    for i = 1:numGroups
        cacheFile = makeCacheFile(cacheDir, groupNames{i}, maxFE_OneSeg);
        [hvLastAll{i}, hvSeriesAll{i}, actualFEAll{i}, runtimeAll{i}, meanSignalAll{i}, meanSwitchCountAll{i}, meanCoverageRatioAll{i}, objMetricSummaryAll{i}] = runOrLoad( ...
            sprintf('FE%d/%s', maxFE_OneSeg, groupNames{i}), cacheFile, n, ...
            @() runOne_DCMOCPSO(N, maxFE_OneSeg, groupProblemParams{i}, param_OneSeg), ...
            true);
    end

    setResults{setIdx} = summarizeSet( ...
        sprintf('FE%d', maxFE_OneSeg), maxFE_OneSeg, groupNames, groupProblemParams, ...
        param_OneSeg, hvLastAll, hvSeriesAll, actualFEAll, runtimeAll, ...
        meanSignalAll, meanSwitchCountAll, meanCoverageRatioAll, objMetricSummaryAll, n);

    plotSetResults(setResults{setIdx});
end

%% Save combined summary
results = struct();
results.experimentName = 'OneSegSwitchMethodAblation_FE_sweep';
results.maxFE_OneSegList = maxFE_OneSegList;
results.groupNames = groupNames;
results.groupProblemParams = groupProblemParams;
results.param_OneSeg = param_OneSeg;
results.n = n;
results.setResults = setResults;

summaryFile = fullfile(cacheDir, 'OneSegSwitchMethod_FE_sweep_summary.mat');
save(summaryFile, 'results');
fprintf('\nCombined summary saved to: %s\n', summaryFile);


%% ===================== local functions =====================
function cacheFile = makeCacheFile(cacheDir, groupName, maxFE_OneSeg)
    if maxFE_OneSeg == 400
        cacheFile = fullfile(cacheDir, sprintf('OneSegSwitchMethod_%s_HV_objMetrics_runs.mat', groupName));
    else
        cacheFile = fullfile(cacheDir, sprintf('FE%d_OneSegSwitchMethod_%s_HV_objMetrics_runs.mat', maxFE_OneSeg, groupName));
    end
end

function result = summarizeSet(setName, maxFE_OneSeg, groupNames, groupProblemParams, param_OneSeg, hvLastAll, hvSeriesAll, actualFEAll, runtimeAll, meanSignalAll, meanSwitchCountAll, meanCoverageRatioAll, objMetricSummaryAll, n)
    numGroups = numel(groupNames);
    meanHV = nan(1, numGroups);
    stdHV = nan(1, numGroups);
    meanRuntime = nan(1, numGroups);
    stdRuntime = nan(1, numGroups);
    meanActualFE = nan(1, numGroups);
    meanSignal = nan(1, numGroups);
    stdSignal = nan(1, numGroups);
    meanSwitchCount = nan(1, numGroups);
    stdSwitchCount = nan(1, numGroups);
    meanCoverageRatio = nan(1, numGroups);
    stdCoverageRatio = nan(1, numGroups);
    validCount = zeros(1, numGroups);

    fprintf('\n--- OneSeg switch-method summary (%s, n=%d) ---\n', setName, n);
    for i = 1:numGroups
        validIdx = ~isnan(hvLastAll{i});
        validCount(i) = sum(validIdx);
        meanHV(i) = meanValid(hvLastAll{i}(validIdx));
        stdHV(i) = stdValid(hvLastAll{i}(validIdx));
        meanRuntime(i) = meanValid(runtimeAll{i}(validIdx));
        stdRuntime(i) = stdValid(runtimeAll{i}(validIdx));
        meanActualFE(i) = meanValid(actualFEAll{i}(validIdx));
        meanSignal(i) = meanValid(meanSignalAll{i}(validIdx));
        stdSignal(i) = stdValid(meanSignalAll{i}(validIdx));
        meanSwitchCount(i) = meanValid(meanSwitchCountAll{i}(validIdx));
        stdSwitchCount(i) = stdValid(meanSwitchCountAll{i}(validIdx));
        meanCoverageRatio(i) = meanValid(meanCoverageRatioAll{i}(validIdx));
        stdCoverageRatio(i) = stdValid(meanCoverageRatioAll{i}(validIdx));

        fprintf('%-18s : switchMethod=%d, mean(last HV)=%.6e, std=%.6e (valid=%d/%d, maxFE=%d, actualFE mean=%.1f, runtime mean=%.2fs, signal mean=%.4f, switch mean=%.4f, coverage mean=%.4f)\n', ...
            groupNames{i}, groupProblemParams{i}{7}, meanHV(i), stdHV(i), validCount(i), n, maxFE_OneSeg, meanActualFE(i), meanRuntime(i), meanSignal(i), meanSwitchCount(i), meanCoverageRatio(i));
    end

    result = struct();
    result.setName = setName;
    result.maxFE_OneSeg = maxFE_OneSeg;
    result.groupNames = groupNames;
    result.groupProblemParams = groupProblemParams;
    result.param_OneSeg = param_OneSeg;
    result.hvLastAll = hvLastAll;
    result.hvSeriesAll = hvSeriesAll;
    result.actualFEAll = actualFEAll;
    result.runtimeAll = runtimeAll;
    result.meanSignalAll = meanSignalAll;
    result.meanSwitchCountAll = meanSwitchCountAll;
    result.meanCoverageRatioAll = meanCoverageRatioAll;
    result.objMetricSummaryAll = objMetricSummaryAll;
    result.meanHV = meanHV;
    result.stdHV = stdHV;
    result.meanRuntime = meanRuntime;
    result.stdRuntime = stdRuntime;
    result.meanActualFE = meanActualFE;
    result.meanSignal = meanSignal;
    result.stdSignal = stdSignal;
    result.meanSwitchCount = meanSwitchCount;
    result.stdSwitchCount = stdSwitchCount;
    result.meanCoverageRatio = meanCoverageRatio;
    result.stdCoverageRatio = stdCoverageRatio;
    result.validCount = validCount;
end

function plotSetResults(result)
    colors = [
        0.78, 0.20, 0.18
        0.50, 0.30, 0.70
        0.20, 0.42, 0.78
    ];
    titlePrefix = sprintf('OneSeg switch-method ablation %s', result.setName);

    figure('Name', sprintf('%s switch-method metrics', result.setName), ...
        'Color', 'w', 'Position', [200, 200, 1500, 900]);
    layout = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, titlePrefix, 'FontSize', 14, 'FontWeight', 'bold');

    plotBarComparison(nexttile(layout), 'Mean of last HV', ...
        'HV', result.groupNames, result.meanHV, result.stdHV, colors, true);

    plotBarComparison(nexttile(layout), 'Mean runtime (seconds)', ...
        'Runtime', result.groupNames, result.meanRuntime, result.stdRuntime, colors, false);

    plotBarComparison(nexttile(layout), 'Mean signal strength (dBm)', ...
        'Signal', result.groupNames, result.meanSignal, result.stdSignal, colors, true);

    plotBarComparison(nexttile(layout), 'Mean switch count', ...
        'Switch Count', result.groupNames, result.meanSwitchCount, result.stdSwitchCount, colors, true);

    plotBarComparison(nexttile(layout), 'Mean coverage ratio', ...
        'Coverage', result.groupNames, result.meanCoverageRatio, result.stdCoverageRatio, colors, true);

    axis(nexttile(layout), 'off');
end

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

    runs = struct('hv', {}, 'actualFE', {}, 'runtime', {}, 'meanSignal', {}, 'meanSwitchCount', {}, 'meanCoverageRatio', {}, 'objMetricSummary', {});
    loadCount = 0;
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
            if loadCount >= n
                return;
            end
        end
    end

    if ~allowRun
        fprintf('[%s] cache is missing or incomplete, and recomputation is disabled. Missing runs remain NaN.\n', algName);
        return;
    end

    startRun = loadCount + 1;
    fprintf('[%s] cache miss/incomplete -> run %d time(s)\n', algName, n - startRun + 1);

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

function [hv, actualFE, runtime, objMetricSummary, Algorithm, Problem] = runOne_DCMOCPSO(N, maxFE, problemParameter, algorithmParameter)
    Algorithm = DCMOCPSO('parameter', algorithmParameter, 'outputFcn', @(~,~)[]);
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

function value = stdValid(values)
    values = values(~isnan(values) & isfinite(values));
    if isempty(values)
        value = NaN;
    elseif numel(values) == 1
        value = 0;
    else
        value = std(values);
    end
end

function plotBarComparison(ax, yLabelText, titleText, groupNames, values, errors, colors, smartYLim)
    x = 1:numel(groupNames);

    b = bar(ax, x, values);
    b.FaceColor = 'flat';
    for i = 1:size(colors, 1)
        b.CData(i,:) = colors(i,:);
    end
    hold(ax, 'on');
    errorbar(ax, x, values, errors, 'k.', 'LineWidth', 1.1, 'CapSize', 10);
    hold(ax, 'off');

    set(ax, 'XTick', x, 'XTickLabel', groupNames, 'FontSize', 10);
    ylabel(ax, yLabelText, 'FontSize', 11, 'FontWeight', 'bold');
    title(ax, titleText, 'FontSize', 12, 'FontWeight', 'bold');
    grid(ax, 'on');

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
                ylim(ax, [vMin - margin, vMax + margin]);
            elseif vMin ~= 0
                ylim(ax, [vMin * 0.95, vMin * 1.05]);
            end
        end
    end
end
