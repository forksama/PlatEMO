% example_compare_DCMOCPSO_vs_baselines.m
%
% Algorithm-level comparison on UAVPathPlanning under multiple FE budgets.
%
% Each maxFE_DCMOCPSO setting runs four groups:
% 1) DCMOCPSO    : segmented full_param, {5,2,0.5,0.3,true,true,true}
% 2) Base-MOCPSO : one-segment baseline, {1,2,0.5,0.3,false,false,false}
% 3) IMMOEAD     : competitor algorithm
% 4) DGEA        : competitor algorithm
%
% The maxFE=100 case reuses the existing unprefixed cache files. The
% maxFE=50 and maxFE=200 cases use FE-prefixed cache files.

clear; clc; close all;

%% Settings
n = 10;

% Set this to true only if the cached groups are missing and you really
% want to recompute them. Recomputing can take several hours.
allowRunCachedGroups = true;

% Start and warm up the parallel pool before per-run timing begins, so the
% parpool startup cost is not counted in any algorithm runtime.
enableParallelPool = true;
parallelPoolProfile = 'Processes';
parallelPoolNumWorkers = [];
prepareParallelPool(enableParallelPool, parallelPoolProfile, parallelPoolNumWorkers);

% UAVPathPlanning parameters shared by all groups.
N = 20;
problemParameter_Lookahead = {20, 20, 5, -101.5, 0, 30, 2, 500};

numSegments = 5;
maxFE_DCMOCPSOList = [50, 100, 200];
param_Full = {numSegments, 2, 0.5, 0.3, true, true, true};
param_OneSeg = {1, 2, 0.5, 0.3, false, false, false};
groupNames = {'DCMOCPSO', 'Base-MOCPSO', 'IMMOEAD', 'DGEA'};
cacheGroupNames = {'Full_Lookahead', 'OneSeg_Lookahead', 'IMMOEAD', 'DGEA'};

cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results', 'compare_vs_baselines');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

setResults = cell(1, numel(maxFE_DCMOCPSOList));

%% Run each maxFE budget
for setIdx = 1:numel(maxFE_DCMOCPSOList)
    maxFE_DCMOCPSO = maxFE_DCMOCPSOList(setIdx);
    fprintf('\n\n================ Baseline comparison: maxFE_DCMOCPSO = %d ================\n', maxFE_DCMOCPSO);

    cacheFile_DCMOCPSO = makeCacheFile(cacheDir, cacheGroupNames{1}, maxFE_DCMOCPSO);
    cacheFile_BaseMOCPSO = makeCacheFile(cacheDir, cacheGroupNames{2}, maxFE_DCMOCPSO);
    cacheFile_IMMOEAD = makeCacheFile(cacheDir, cacheGroupNames{3}, maxFE_DCMOCPSO);
    cacheFile_DGEA = makeCacheFile(cacheDir, cacheGroupNames{4}, maxFE_DCMOCPSO);

    [hvLast_DCMOCPSO, hvSeries_DCMOCPSO, actualFE_DCMOCPSO, runtime_DCMOCPSO, meanSignal_DCMOCPSO, meanSwitchCount_DCMOCPSO, meanCoverageRatio_DCMOCPSO, objMetricSummary_DCMOCPSO] = runOrLoad( ...
        sprintf('FE%d/DCMOCPSO', maxFE_DCMOCPSO), cacheFile_DCMOCPSO, n, ...
        @() runOneAlgorithm(@() DCMOCPSO('parameter', param_Full, 'outputFcn', @(~,~)[]), N, maxFE_DCMOCPSO, problemParameter_Lookahead), ...
        allowRunCachedGroups);

    validFE_DCMOCPSO = loadAllActualFE(cacheFile_DCMOCPSO);
    if isempty(validFE_DCMOCPSO)
        validFE_DCMOCPSO = actualFE_DCMOCPSO(~isnan(actualFE_DCMOCPSO));
    end
    if isempty(validFE_DCMOCPSO)
        competitorMaxFE = maxFE_DCMOCPSO;
        maxFE_BaseMOCPSO = maxFE_DCMOCPSO;
    else
        competitorMaxFE = round(mean(validFE_DCMOCPSO));
        maxFE_BaseMOCPSO = max(1, round(competitorMaxFE / numSegments));
    end

    [hvLast_BaseMOCPSO, hvSeries_BaseMOCPSO, actualFE_BaseMOCPSO, runtime_BaseMOCPSO, meanSignal_BaseMOCPSO, meanSwitchCount_BaseMOCPSO, meanCoverageRatio_BaseMOCPSO, objMetricSummary_BaseMOCPSO] = runOrLoad( ...
        sprintf('FE%d/Base-MOCPSO', maxFE_DCMOCPSO), cacheFile_BaseMOCPSO, n, ...
        @() runOneAlgorithm(@() DCMOCPSO('parameter', param_OneSeg, 'outputFcn', @(~,~)[]), N, maxFE_BaseMOCPSO, problemParameter_Lookahead), ...
        allowRunCachedGroups);

    [hvLast_DGEA, hvSeries_DGEA, actualFE_DGEA, runtime_DGEA, meanSignal_DGEA, meanSwitchCount_DGEA, meanCoverageRatio_DGEA, objMetricSummary_DGEA] = runOrLoad( ...
        sprintf('FE%d/DGEA', maxFE_DCMOCPSO), cacheFile_DGEA, n, ...
        @() runOneAlgorithm(@() DGEA('outputFcn', @(~,~)[]), N, competitorMaxFE, problemParameter_Lookahead), ...
        true);

    [hvLast_IMMOEAD, hvSeries_IMMOEAD, actualFE_IMMOEAD, runtime_IMMOEAD, meanSignal_IMMOEAD, meanSwitchCount_IMMOEAD, meanCoverageRatio_IMMOEAD, objMetricSummary_IMMOEAD] = runOrLoad( ...
        sprintf('FE%d/IMMOEAD', maxFE_DCMOCPSO), cacheFile_IMMOEAD, n, ...
        @() runOneAlgorithm(@() IMMOEAD('outputFcn', @(~,~)[]), N, competitorMaxFE, problemParameter_Lookahead), ...
        true);

    hvLastAll = {hvLast_DCMOCPSO, hvLast_BaseMOCPSO, hvLast_IMMOEAD, hvLast_DGEA};
    hvSeriesAll = {hvSeries_DCMOCPSO, hvSeries_BaseMOCPSO, hvSeries_IMMOEAD, hvSeries_DGEA};
    actualFEAll = {actualFE_DCMOCPSO, actualFE_BaseMOCPSO, actualFE_IMMOEAD, actualFE_DGEA};
    runtimeAll = {runtime_DCMOCPSO, runtime_BaseMOCPSO, runtime_IMMOEAD, runtime_DGEA};
    meanSignalAll = {meanSignal_DCMOCPSO, meanSignal_BaseMOCPSO, meanSignal_IMMOEAD, meanSignal_DGEA};
    meanSwitchCountAll = {meanSwitchCount_DCMOCPSO, meanSwitchCount_BaseMOCPSO, meanSwitchCount_IMMOEAD, meanSwitchCount_DGEA};
    meanCoverageRatioAll = {meanCoverageRatio_DCMOCPSO, meanCoverageRatio_BaseMOCPSO, meanCoverageRatio_IMMOEAD, meanCoverageRatio_DGEA};
    objMetricSummaryAll = {objMetricSummary_DCMOCPSO, objMetricSummary_BaseMOCPSO, objMetricSummary_IMMOEAD, objMetricSummary_DGEA};
    maxFEAll = [maxFE_DCMOCPSO, maxFE_BaseMOCPSO, competitorMaxFE, competitorMaxFE];

    setResults{setIdx} = summarizeSet( ...
        sprintf('FE%d', maxFE_DCMOCPSO), maxFE_DCMOCPSO, competitorMaxFE, ...
        maxFE_BaseMOCPSO, groupNames, cacheGroupNames, problemParameter_Lookahead, ...
        {param_Full, param_OneSeg, 'IMMOEAD', 'DGEA'}, maxFEAll, ...
        hvLastAll, hvSeriesAll, actualFEAll, runtimeAll, meanSignalAll, ...
        meanSwitchCountAll, meanCoverageRatioAll, objMetricSummaryAll, n, numSegments);

    plotSetResults(setResults{setIdx});
end

%% Save combined summary
results = struct();
results.experimentName = 'DCMOCPSO_vs_baselines_FE_sweep';
results.maxFE_DCMOCPSOList = maxFE_DCMOCPSOList;
results.groupNames = groupNames;
results.cacheGroupNames = cacheGroupNames;
results.problemParameter_Lookahead = problemParameter_Lookahead;
results.param_Full = param_Full;
results.param_OneSeg = param_OneSeg;
results.numSegments = numSegments;
results.n = n;
results.setResults = setResults;

summaryFile = fullfile(cacheDir, 'DCMOCPSO_vs_baselines_FE_sweep_summary.mat');
save(summaryFile, 'results');
fprintf('\nCombined summary saved to: %s\n', summaryFile);


%% ===================== local functions =====================
function cacheFile = makeCacheFile(cacheDir, groupName, maxFE_DCMOCPSO)
    if maxFE_DCMOCPSO == 100
        cacheFile = fullfile(cacheDir, sprintf('%s_HV_runs.mat', groupName));
    else
        cacheFile = fullfile(cacheDir, sprintf('FE%d_%s_HV_runs.mat', maxFE_DCMOCPSO, groupName));
    end
end

function result = summarizeSet(setName, maxFE_DCMOCPSO, competitorMaxFE, maxFE_BaseMOCPSO, groupNames, cacheGroupNames, problemParameter_Lookahead, algorithmParams, maxFEAll, hvLastAll, hvSeriesAll, actualFEAll, runtimeAll, meanSignalAll, meanSwitchCountAll, meanCoverageRatioAll, objMetricSummaryAll, n, numSegments)
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

    fprintf('\n--- Algorithm comparison summary (%s, n=%d) ---\n', setName, n);
    fprintf('DCMOCPSO maxFE=%d; competitor maxFE=%d; Base-MOCPSO maxFE=%d derived by competitor FE / %d.\n', ...
        maxFE_DCMOCPSO, competitorMaxFE, maxFE_BaseMOCPSO, numSegments);
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

        fprintf('%-12s : mean(last HV)=%.6e, std=%.6e (valid=%d/%d, maxFE=%d, actualFE mean=%.1f, runtime mean=%.2fs, signal mean=%.4f, switch mean=%.4f, coverage mean=%.4f)\n', ...
            groupNames{i}, meanHV(i), stdHV(i), validCount(i), n, maxFEAll(i), meanActualFE(i), meanRuntime(i), meanSignal(i), meanSwitchCount(i), meanCoverageRatio(i));
    end

    result = struct();
    result.setName = setName;
    result.maxFE_DCMOCPSO = maxFE_DCMOCPSO;
    result.competitorMaxFE = competitorMaxFE;
    result.maxFE_BaseMOCPSO = maxFE_BaseMOCPSO;
    result.groupNames = groupNames;
    result.cacheGroupNames = cacheGroupNames;
    result.problemParameter_Lookahead = problemParameter_Lookahead;
    result.algorithmParams = algorithmParams;
    result.maxFEAll = maxFEAll;
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
        0.20, 0.40, 0.80
        0.90, 0.60, 0.10
        0.35, 0.55, 0.70
        0.75, 0.35, 0.20
    ];
    titlePrefix = sprintf('Algorithm comparison %s', result.setName);

    figure('Name', sprintf('%s metrics comparison', result.setName), ...
        'Color', 'w', 'Position', [200, 200, 1500, 900]);
    layout = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, titlePrefix, 'FontSize', 14, 'FontWeight', 'bold');

    plotBarComparison(nexttile(layout), 'Mean of last HV', ...
        'HV Metric', result.groupNames, result.meanHV, result.stdHV, colors, true);

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

function actualFE = loadAllActualFE(cacheFile)
    actualFE = [];
    if exist(cacheFile, 'file') ~= 2
        return;
    end

    S = load(cacheFile);
    if ~isfield(S, 'runs')
        return;
    end

    runs = S.runs;
    for i = 1:numel(runs)
        if isfield(runs, 'actualFE') && ~isempty(runs(i).actualFE) && ~isnan(runs(i).actualFE)
            actualFE(end+1) = runs(i).actualFE; %#ok<AGROW>
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

function [hv, actualFE, runtime, objMetricSummary, Algorithm, Problem] = runOneAlgorithm(createAlgorithmFn, N, maxFE, problemParameter)
    Algorithm = createAlgorithmFn();
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
    if numel(values) <= 1
        value = 0;
    else
        value = std(values);
    end
end

function plotBarComparison(ax, yLabelText, titleText, groupNames, values, stdValues, colors, smartYLim)
    x = 1:numel(groupNames);

    b = bar(ax, x, values);
    b.FaceColor = 'flat';
    for i = 1:size(colors, 1)
        b.CData(i,:) = colors(i,:);
    end

    hold(ax, 'on');
    errorbar(ax, x, values, stdValues, 'k', 'LineStyle', 'none', 'LineWidth', 1.1);
    hold(ax, 'off');

    set(ax, 'XTick', x, 'XTickLabel', groupNames, 'FontSize', 10);
    ylabel(ax, yLabelText, 'FontSize', 11, 'FontWeight', 'bold');
    title(ax, titleText, 'FontSize', 12, 'FontWeight', 'bold');
    grid(ax, 'on');

    if smartYLim
        validValues = values(~isnan(values));
        validStd = stdValues(~isnan(values));
        if ~isempty(validValues)
            lower = min(validValues - validStd);
            upper = max(validValues + validStd);
            vRange = upper - lower;
            if vRange > 0
                margin = vRange * 0.15;
                ylim(ax, [lower - margin, upper + margin]);
            elseif lower ~= 0
                ylim(ax, [lower * 0.95, lower * 1.05]);
            end
        end
    end
end
