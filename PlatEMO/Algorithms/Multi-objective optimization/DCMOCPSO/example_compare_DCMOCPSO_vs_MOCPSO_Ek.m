% example_compare_DCMOCPSO_vs_MOCPSO_Ek.m
%
% Three-stage ablation based on OneSeg_Lookahead under multiple maxFE
% budgets.
%
% Each maxFE_DCMOCPSO setting runs three groups:
% 1) OneSeg_Lookahead : {1, 2, 0.5, 0.3, false, false, false} + switchMethod=2
% 2) Seg_Lookahead    : {5, 2, 0.5, 0.3, false, false, false} + switchMethod=2
% 3) Full_Lookahead   : {5, 2, 0.5, 0.3, true,  true,  true}  + switchMethod=2
%
% The OneSeg_Lookahead maxFE is derived separately for each budget:
%   round(mean(validFE_Full_Lookahead) / numSegments)

clear; clc; close all;

%% Settings
n = 10;

N = 20;
problemParameter_Lookahead = {20, 20, 5, -101.5, 0, 30, 2, 500};

numSegments = 5;
maxFE_DCMOCPSOList = [50, 100, 200];

param_OneSeg = {1, 2, 0.5, 0.3, false, false, false};
param_Seg    = {numSegments, 2, 0.5, 0.3, false, false, false};
param_Full   = {numSegments, 2, 0.5, 0.3, true, true, true};
groupNames = {'OneSeg_Lookahead', 'Seg_Lookahead', 'Full_Lookahead'};

cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results', 'compare_vs_mocpso_ek');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

setResults = cell(1, numel(maxFE_DCMOCPSOList));

%% Run each maxFE budget
for setIdx = 1:numel(maxFE_DCMOCPSOList)
    maxFE_DCMOCPSO = maxFE_DCMOCPSOList(setIdx);
    fprintf('\n\n================ maxFE_DCMOCPSO = %d ================\n', maxFE_DCMOCPSO);

    cacheFile_Full_Lookahead = makeCacheFile(cacheDir, 'Full_Lookahead', maxFE_DCMOCPSO);
    cacheFile_Seg_Lookahead = makeCacheFile(cacheDir, 'Seg_Lookahead', maxFE_DCMOCPSO);
    cacheFile_OneSeg_Lookahead = makeCacheFile(cacheDir, 'OneSeg_Lookahead', maxFE_DCMOCPSO);

    % Run Full first to estimate the fair OneSeg maxFE from actualFE.
    [hvLast_Full, hvSeries_Full, actualFE_Full, runtime_Full, meanSignal_Full, meanSwitchCount_Full, meanCoverageRatio_Full, objMetricSummary_Full] = runOrLoad( ...
        sprintf('FE%d/Full_Lookahead', maxFE_DCMOCPSO), cacheFile_Full_Lookahead, n, ...
        @() runOne_DCMOCPSO(N, maxFE_DCMOCPSO, problemParameter_Lookahead, param_Full), ...
        true);

    validFE_Full = loadAllActualFE(cacheFile_Full_Lookahead);
    if isempty(validFE_Full)
        validFE_Full = actualFE_Full(~isnan(actualFE_Full));
    end
    if isempty(validFE_Full)
        maxFE_OneSeg = maxFE_DCMOCPSO;
    else
        maxFE_OneSeg = max(1, round(mean(validFE_Full) / numSegments));
    end

    [hvLast_Seg, hvSeries_Seg, actualFE_Seg, runtime_Seg, meanSignal_Seg, meanSwitchCount_Seg, meanCoverageRatio_Seg, objMetricSummary_Seg] = runOrLoad( ...
        sprintf('FE%d/Seg_Lookahead', maxFE_DCMOCPSO), cacheFile_Seg_Lookahead, n, ...
        @() runOne_DCMOCPSO(N, maxFE_DCMOCPSO, problemParameter_Lookahead, param_Seg), ...
        true);

    [hvLast_OneSeg, hvSeries_OneSeg, actualFE_OneSeg, runtime_OneSeg, meanSignal_OneSeg, meanSwitchCount_OneSeg, meanCoverageRatio_OneSeg, objMetricSummary_OneSeg] = runOrLoad( ...
        sprintf('FE%d/OneSeg_Lookahead', maxFE_DCMOCPSO), cacheFile_OneSeg_Lookahead, n, ...
        @() runOne_DCMOCPSO(N, maxFE_OneSeg, problemParameter_Lookahead, param_OneSeg), ...
        true);

    hvLastAll = {hvLast_OneSeg, hvLast_Seg, hvLast_Full};
    hvSeriesAll = {hvSeries_OneSeg, hvSeries_Seg, hvSeries_Full};
    actualFEAll = {actualFE_OneSeg, actualFE_Seg, actualFE_Full};
    runtimeAll = {runtime_OneSeg, runtime_Seg, runtime_Full};
    meanSignalAll = {meanSignal_OneSeg, meanSignal_Seg, meanSignal_Full};
    meanSwitchCountAll = {meanSwitchCount_OneSeg, meanSwitchCount_Seg, meanSwitchCount_Full};
    meanCoverageRatioAll = {meanCoverageRatio_OneSeg, meanCoverageRatio_Seg, meanCoverageRatio_Full};
    objMetricSummaryAll = {objMetricSummary_OneSeg, objMetricSummary_Seg, objMetricSummary_Full};
    algorithmParams = {param_OneSeg, param_Seg, param_Full};
    maxFEAll = [maxFE_OneSeg, maxFE_DCMOCPSO, maxFE_DCMOCPSO];

    setResults{setIdx} = summarizeSet( ...
        sprintf('FE%d', maxFE_DCMOCPSO), maxFE_DCMOCPSO, maxFE_OneSeg, ...
        groupNames, problemParameter_Lookahead, algorithmParams, maxFEAll, ...
        hvLastAll, hvSeriesAll, actualFEAll, runtimeAll, meanSignalAll, ...
        meanSwitchCountAll, meanCoverageRatioAll, objMetricSummaryAll, n, numSegments);

    plotSetResults(setResults{setIdx});
end

%% Save combined summary
results = struct();
results.experimentName = 'DCMOCPSO_three_stage_lookahead_ablation_FE_sweep';
results.maxFE_DCMOCPSOList = maxFE_DCMOCPSOList;
results.groupNames = groupNames;
results.problemParameter_Lookahead = problemParameter_Lookahead;
results.param_OneSeg = param_OneSeg;
results.param_Seg = param_Seg;
results.param_Full = param_Full;
results.numSegments = numSegments;
results.n = n;
results.setResults = setResults;

summaryFile = fullfile(cacheDir, 'DCMOCPSO_vs_MOCPSO_Ek_FE_sweep_summary.mat');
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

function result = summarizeSet(setName, maxFE_DCMOCPSO, maxFE_OneSeg, groupNames, problemParameter_Lookahead, algorithmParams, maxFEAll, hvLastAll, hvSeriesAll, actualFEAll, runtimeAll, meanSignalAll, meanSwitchCountAll, meanCoverageRatioAll, objMetricSummaryAll, n, numSegments)
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

    fprintf('\n--- Three-stage lookahead ablation summary (%s, n=%d) ---\n', setName, n);
    fprintf('Derived maxFE_OneSeg = %d from Full_Lookahead actualFE / %d.\n', maxFE_OneSeg, numSegments);
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

        fprintf('%-18s : mean(last HV)=%.6e, std=%.6e (valid=%d/%d, maxFE=%d, actualFE mean=%.1f, runtime mean=%.2fs, signal mean=%.4f, switch mean=%.4f, coverage mean=%.4f)\n', ...
            groupNames{i}, meanHV(i), stdHV(i), validCount(i), n, maxFEAll(i), meanActualFE(i), meanRuntime(i), meanSignal(i), meanSwitchCount(i), meanCoverageRatio(i));
    end

    result = struct();
    result.setName = setName;
    result.maxFE_DCMOCPSO = maxFE_DCMOCPSO;
    result.maxFE_OneSeg = maxFE_OneSeg;
    result.groupNames = groupNames;
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
        0.90, 0.60, 0.10
        0.20, 0.70, 0.30
        0.20, 0.40, 0.80
    ];
    titlePrefix = sprintf('Three-stage lookahead ablation %s', result.setName);

    figure('Name', sprintf('%s metrics', result.setName), ...
        'Color', 'w', 'Position', [200, 200, 1200, 520]);
    layout = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, titlePrefix, 'FontSize', 14, 'FontWeight', 'bold');

    plotBarComparison(nexttile(layout), 'Mean of last HV', ...
        'HV', result.groupNames, result.meanHV, result.stdHV, colors, true);

    plotBarComparison(nexttile(layout), 'Mean runtime (seconds)', ...
        'Runtime', result.groupNames, result.meanRuntime, result.stdRuntime, colors, false);
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
