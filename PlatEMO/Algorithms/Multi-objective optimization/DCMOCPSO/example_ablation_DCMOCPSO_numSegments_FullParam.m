% example_ablation_DCMOCPSO_numSegments_FullParam.m
%
% Paired ablation for DCMOCPSO segment count under Full_Lookahead.
%
% The segmented groups reuse existing caches for numSegments = 3, 5, 7, 9:
%   {numSegments, 2, 0.5, 0.3, true, true, true} + switchMethod=2
%
% For each segmented group, this script creates a corresponding OneSeg
% comparison group:
%   {1, 2, 0.5, 0.3, true, true, true} + switchMethod=2
%
% The OneSeg comparison maxFE is derived from the segmented group's actual
% FE: round(mean(actualFE_segmented) / numSegments). The old seg_1 group is
% not used because its maxFE=100 budget is not comparable.

clear; clc; close all;

%% Settings
n = 20;

enableParallelPool = true;
parallelPoolProfile = 'Processes';
parallelPoolNumWorkers = [];
prepareParallelPool(enableParallelPool, parallelPoolProfile, parallelPoolNumWorkers);

N = 20;
baseProblemParameter = {20, 20, 5, -101.5, 0, 30, 2, 500, 10, 4};

segmentedNumSegmentsList = [3, 5, 7, 9];

maxFE_Segmented = 100;
baseParam_Full = {5, 2, 0.5, 0.3, true, true, true};

cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results', 'num_segments_full_param');
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end

commonConfig = struct( ...
    'N', N, ...
    'maxFE_Segmented', maxFE_Segmented, ...
    'baseProblemParameter', {baseProblemParameter}, ...
    'baseParam_Full', {baseParam_Full});

%% Run or load paired groups
numPairs = numel(segmentedNumSegmentsList);
numGroups = numPairs * 2;

groupNames = cell(1, numGroups);
sourceSegmentList = nan(1, numGroups);
numSegmentsPerGroup = nan(1, numGroups);
segmentRoleList = cell(1, numGroups);
maxFEAll = nan(1, numGroups);
algorithmParams = cell(1, numGroups);

hvLastAll = cell(1, numGroups);
hvSeriesAll = cell(1, numGroups);
actualFEAll = cell(1, numGroups);
runtimeAll = cell(1, numGroups);
meanSignalAll = cell(1, numGroups);
meanSwitchCountAll = cell(1, numGroups);
meanCoverageRatioAll = cell(1, numGroups);
objMetricSummaryAll = cell(1, numGroups);

fprintf('\n=== Full_Lookahead paired numSegments ablation (n=%d) ===\n', n);
fprintf('Segmented groups reuse maxFE=%d caches; each OneSeg comparison uses mean(actualFE_segmented)/numSegments.\n', ...
    commonConfig.maxFE_Segmented);

for pairIdx = 1:numPairs
    numSegments = segmentedNumSegmentsList(pairIdx);
    segmentedGroupIdx = (pairIdx - 1) * 2 + 1;
    oneSegGroupIdx = segmentedGroupIdx + 1;

    groupNames{segmentedGroupIdx} = sprintf('Seg%d_Full', numSegments);
    groupNames{oneSegGroupIdx} = sprintf('OneSeg_for_Seg%d', numSegments);
    sourceSegmentList([segmentedGroupIdx, oneSegGroupIdx]) = numSegments;
    numSegmentsPerGroup(segmentedGroupIdx) = numSegments;
    numSegmentsPerGroup(oneSegGroupIdx) = 1;
    segmentRoleList{segmentedGroupIdx} = 'Segmented';
    segmentRoleList{oneSegGroupIdx} = 'OneSegBaseline';

    algorithmParams{segmentedGroupIdx} = makeAlgorithmParameter(baseParam_Full, numSegments);
    cacheFile_Segmented = fullfile(cacheDir, sprintf('NumSegments_Full_seg_%s_HV_objMetrics_runs.mat', valueTag(numSegments)));

    [hvLastAll{segmentedGroupIdx}, hvSeriesAll{segmentedGroupIdx}, actualFEAll{segmentedGroupIdx}, runtimeAll{segmentedGroupIdx}, meanSignalAll{segmentedGroupIdx}, meanSwitchCountAll{segmentedGroupIdx}, meanCoverageRatioAll{segmentedGroupIdx}, objMetricSummaryAll{segmentedGroupIdx}] = runOrLoad( ...
        groupNames{segmentedGroupIdx}, cacheFile_Segmented, n, ...
        @() runOne_DCMOCPSO(commonConfig.N, commonConfig.maxFE_Segmented, commonConfig.baseProblemParameter, algorithmParams{segmentedGroupIdx}), ...
        true);
    maxFEAll(segmentedGroupIdx) = commonConfig.maxFE_Segmented;

    validFE_Segmented = loadAllActualFE(cacheFile_Segmented);
    if isempty(validFE_Segmented)
        validFE_Segmented = actualFEAll{segmentedGroupIdx}(~isnan(actualFEAll{segmentedGroupIdx}));
    end
    if isempty(validFE_Segmented)
        maxFE_OneSeg = commonConfig.maxFE_Segmented;
        warning('[%s] no valid segmented actualFE found; fallback OneSeg maxFE=%d.', ...
            groupNames{segmentedGroupIdx}, maxFE_OneSeg);
    else
        maxFE_OneSeg = max(1, round(meanValid(validFE_Segmented) / numSegments));
    end

    algorithmParams{oneSegGroupIdx} = makeAlgorithmParameter(baseParam_Full, 1);
    maxFEAll(oneSegGroupIdx) = maxFE_OneSeg;
    cacheFile_OneSeg = fullfile(cacheDir, sprintf('NumSegments_Full_oneSeg_for_seg_%s_FE_%s_HV_objMetrics_runs.mat', ...
        valueTag(numSegments), valueTag(maxFE_OneSeg)));

    [hvLastAll{oneSegGroupIdx}, hvSeriesAll{oneSegGroupIdx}, actualFEAll{oneSegGroupIdx}, runtimeAll{oneSegGroupIdx}, meanSignalAll{oneSegGroupIdx}, meanSwitchCountAll{oneSegGroupIdx}, meanCoverageRatioAll{oneSegGroupIdx}, objMetricSummaryAll{oneSegGroupIdx}] = runOrLoad( ...
        groupNames{oneSegGroupIdx}, cacheFile_OneSeg, n, ...
        @() runOne_DCMOCPSO(commonConfig.N, maxFE_OneSeg, commonConfig.baseProblemParameter, algorithmParams{oneSegGroupIdx}), ...
        true);

    fprintf('[Pair Seg%d] segmented maxFE=%d, derived OneSeg maxFE=%d from actualFE mean / %d.\n', ...
        numSegments, commonConfig.maxFE_Segmented, maxFE_OneSeg, numSegments);
end

%% Summary
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

fprintf('\n--- paired numSegments summary ---\n');
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

    fprintf('%-18s : sourceSeg=%d, numSegments=%d, role=%s, maxFE=%d, mean(last HV)=%.6e, std=%.6e (valid=%d/%d, actualFE mean=%.1f, runtime mean=%.2fs, signal mean=%.4f, switch mean=%.4f, coverage mean=%.4f)\n', ...
        groupNames{i}, sourceSegmentList(i), numSegmentsPerGroup(i), segmentRoleList{i}, maxFEAll(i), ...
        meanHV(i), stdHV(i), validCount(i), n, meanActualFE(i), meanRuntime(i), meanSignal(i), meanSwitchCount(i), meanCoverageRatio(i));
end

results = struct();
results.experimentName = 'NumSegmentsFullParamPairedOneSegAblation';
results.groupNames = groupNames;
results.segmentedNumSegmentsList = segmentedNumSegmentsList;
results.sourceSegmentList = sourceSegmentList;
results.numSegmentsPerGroup = numSegmentsPerGroup;
results.segmentRoleList = segmentRoleList;
results.commonConfig = commonConfig;
results.algorithmParams = algorithmParams;
results.maxFEAll = maxFEAll;
results.hvLastAll = hvLastAll;
results.hvSeriesAll = hvSeriesAll;
results.actualFEAll = actualFEAll;
results.runtimeAll = runtimeAll;
results.meanSignalAll = meanSignalAll;
results.meanSwitchCountAll = meanSwitchCountAll;
results.meanCoverageRatioAll = meanCoverageRatioAll;
results.objMetricSummaryAll = objMetricSummaryAll;
results.meanHV = meanHV;
results.stdHV = stdHV;
results.meanRuntime = meanRuntime;
results.stdRuntime = stdRuntime;
results.meanActualFE = meanActualFE;
results.meanSignal = meanSignal;
results.stdSignal = stdSignal;
results.meanSwitchCount = meanSwitchCount;
results.stdSwitchCount = stdSwitchCount;
results.meanCoverageRatio = meanCoverageRatio;
results.stdCoverageRatio = stdCoverageRatio;
results.validCount = validCount;

summaryFile = fullfile(cacheDir, 'NumSegments_Full_paired_oneSeg_summary.mat');
save(summaryFile, 'results');
fprintf('\nSummary saved to: %s\n', summaryFile);

%% Plot comparisons
colors = pairedColors(numGroups);
plotMetricSet('Full_Lookahead paired numSegments ablation', groupNames, ...
    meanHV, stdHV, meanRuntime, stdRuntime, meanSignal, stdSignal, ...
    meanSwitchCount, stdSwitchCount, meanCoverageRatio, stdCoverageRatio, ...
    colors, [200, 200], true);


%% ===================== local functions =====================
function algorithmParameter = makeAlgorithmParameter(baseParam_Full, numSegments)
    algorithmParameter = baseParam_Full;
    algorithmParameter{1} = numSegments;
    algorithmParameter{2} = 2;
    algorithmParameter{5} = true;
    algorithmParameter{6} = true;
    algorithmParameter{7} = true;
end

function tag = valueTag(value)
    tag = strrep(sprintf('%g', value), '.', 'p');
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

    warmupFuture = parfeval(pool, @() 1, 1);
    fetchOutputs(warmupFuture);
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

    if isempty(Algorithm.result) || isempty(Algorithm.result{end})
        return;
    end

    finalPopulation = Algorithm.result{end};
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

function colors = pairedColors(numGroups)
    colors = zeros(numGroups, 3);
    segmentedColor = [0.20, 0.42, 0.78];
    baselineColor = [0.90, 0.60, 0.10];
    for i = 1:numGroups
        if mod(i, 2) == 1
            colors(i,:) = segmentedColor;
        else
            colors(i,:) = baselineColor;
        end
    end
end

function plotMetricSet(titlePrefix, groupNames, meanHV, stdHV, meanRuntime, stdRuntime, meanSignal, stdSignal, meanSwitchCount, stdSwitchCount, meanCoverageRatio, stdCoverageRatio, colors, basePosition, smartHVYLim)
    x0 = basePosition(1);
    y0 = basePosition(2);
    figure('Name', sprintf('%s metrics', titlePrefix), ...
        'Color', 'w', 'Position', [x0, y0, 1600, 900]);
    layout = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(layout, titlePrefix, 'FontSize', 14, 'FontWeight', 'bold');

    plotBarComparison(nexttile(layout), 'Mean of last HV', ...
        'HV', groupNames, meanHV, stdHV, colors, smartHVYLim);

    plotBarComparison(nexttile(layout), 'Mean runtime (seconds)', ...
        'Runtime', groupNames, meanRuntime, stdRuntime, colors, false);

    plotBarComparison(nexttile(layout), 'Mean signal strength (dBm)', ...
        'Signal', groupNames, meanSignal, stdSignal, colors, true);

    plotBarComparison(nexttile(layout), 'Mean switch count', ...
        'Switch Count', groupNames, meanSwitchCount, stdSwitchCount, colors, true);

    plotBarComparison(nexttile(layout), 'Mean coverage ratio', ...
        'Coverage', groupNames, meanCoverageRatio, stdCoverageRatio, colors, true);

    axis(nexttile(layout), 'off');
end

function plotBarComparison(ax, yLabelText, titleText, groupNames, values, errors, colors, smartYLim)
    x = 1:numel(groupNames);
    b = bar(ax, x, values);
    b.FaceColor = 'flat';
    for i = 1:numel(values)
        b.CData(i,:) = colors(i,:);
    end
    hold(ax, 'on');
    errorbar(ax, x, values, errors, 'k', 'linestyle', 'none', 'LineWidth', 1.2);
    hold(ax, 'off');
    set(ax, 'XTick', x, 'XTickLabel', groupNames, 'FontSize', 10);
    xtickangle(ax, 30);
    ylabel(ax, yLabelText);
    title(ax, titleText);
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
            end
        end
    end
end
