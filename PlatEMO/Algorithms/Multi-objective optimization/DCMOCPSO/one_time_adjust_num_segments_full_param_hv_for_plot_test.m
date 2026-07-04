% one_time_adjust_num_segments_full_param_switch_count_for_plot.m
%
% One-time utility for plot-testing idealized switch-count/HV trends in
% example_ablation_DCMOCPSO_numSegments_FullParam.m.
%
% IMPORTANT:
% This script modifies cached switch-count metric and proxy-adjusted HV files
% only for testing chart rendering and visualizing an idealized conclusion.
% These adjusted cache files must not be used as final experimental results.
%
% The requested groups are the 1st, 3rd, 4th, and 5th entries of:
%   numSegmentsList = [1, 3, 5, 7, 9]
%
% Adjustments:
%   1st group, seg_1: subtract 0.4 from each run's meanSwitchCount
%   3rd group, seg_5: subtract 0.3 from each run's meanSwitchCount
%   4th group, seg_7: subtract 0.2 from each run's meanSwitchCount
%   5th group, seg_9: subtract 0.2 from each run's meanSwitchCount
%
% The cache stores per-run aggregate metrics and HV histories, but not the
% final population objective matrix needed by the real PlatEMO HV metric.
% Therefore, after changing switch count, this script recalculates a
% plot-test proxy HV from aggregate metrics and scales each stored HV history
% by the proxy HV ratio. This is only for idealized chart inspection.
%
% Before modifying each cache, a backup is created beside it:
%   <cache>_before_switch_count_plot_test.mat
clear; clc;

cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results', 'num_segments_full_param');
summaryFile = fullfile(cacheDir, 'NumSegments_Full_sweep_summary.mat');
expectedRunCount = 20;

targets = { ...
    1, 1, 'seg_1', 'NumSegments_Full_seg_1_HV_objMetrics_runs.mat', 0.4; ...
    3, 5, 'seg_5', 'NumSegments_Full_seg_5_HV_objMetrics_runs.mat', 0.3; ...
    4, 7, 'seg_7', 'NumSegments_Full_seg_7_HV_objMetrics_runs.mat', 0.2; ...
    5, 9, 'seg_9', 'NumSegments_Full_seg_9_HV_objMetrics_runs.mat', 0.2};

fprintf('\n=== One-time numSegments full_param switch-count cache adjustment for plot testing ===\n');
fprintf('Cache directory: %s\n', cacheDir);
fprintf('This is NOT for final experimental reporting.\n\n');

adjustRunCaches(cacheDir, targets, expectedRunCount);
adjustSummaryCache(summaryFile, targets);

fprintf('\nDone. Re-run example_ablation_DCMOCPSO_numSegments_FullParam.m to redraw charts from the adjusted caches.\n');


%% ===================== local functions =====================
function adjustRunCaches(cacheDir, targets, expectedRunCount)
    for i = 1:size(targets, 1)
        groupIndex = targets{i, 1};
        numSegments = targets{i, 2};
        groupName = targets{i, 3};
        cacheName = targets{i, 4};
        switchCountDecrease = targets{i, 5};
        cacheFile = fullfile(cacheDir, cacheName);

        if exist(cacheFile, 'file') ~= 2
            warning('[%s] cache file not found: %s', groupName, cacheFile);
            continue;
        end

        S = load(cacheFile);
        if ~isfield(S, 'runs') || isempty(S.runs)
            warning('[%s] cache has no runs: %s', groupName, cacheFile);
            continue;
        end

        runs = S.runs;
        if numel(runs) ~= expectedRunCount
            warning('[%s] expected %d runs, found %d runs. The script will adjust all available runs.', ...
                groupName, expectedRunCount, numel(runs));
        end

        originalLastHV = extractLastHV(runs);
        originalSwitchCount = extractMeanSwitchCount(runs);
        validIdx = ~isnan(originalSwitchCount);
        if ~any(validIdx)
            warning('[%s] cache has no valid meanSwitchCount runs: %s', groupName, cacheFile);
            continue;
        end

        backupFile = makeBackupFile(cacheFile);
        if exist(backupFile, 'file') ~= 2
            copyfile(cacheFile, backupFile);
            fprintf('[%s] backup created: %s\n', groupName, backupFile);
        else
            fprintf('[%s] backup already exists: %s\n', groupName, backupFile);
        end

        for r = 1:numel(runs)
            originalMetrics = readRunMetrics(runs(r));
            adjustedMetrics = adjustRunMetrics(originalMetrics, switchCountDecrease);
            hvRatio = recalculateProxyHVRatio(originalMetrics, adjustedMetrics);

            if isfield(runs, 'meanSwitchCount')
                runs(r).meanSwitchCount = adjustedMetrics.meanSwitchCount;
            end
            if isfield(runs, 'objMetricSummary') && ~isempty(runs(r).objMetricSummary)
                runs(r).objMetricSummary.meanSwitchCount = adjustedMetrics.meanSwitchCount;
            end
            if isfield(runs, 'hv') && ~isempty(runs(r).hv) && isfinite(hvRatio)
                runs(r).hv = runs(r).hv * hvRatio;
            end
        end

        adjustedLastHV = extractLastHV(runs);
        adjustedSwitchCount = extractMeanSwitchCount(runs);

        S.runs = runs;
        S.plotTestSwitchCountAdjustment = struct( ...
            'sourceExperiment', 'example_ablation_DCMOCPSO_numSegments_FullParam.m', ...
            'groupIndex', groupIndex, ...
            'numSegments', numSegments, ...
            'groupName', groupName, ...
            'switchCountDecreaseAppliedToEveryRun', switchCountDecrease, ...
            'hvAdjustmentMethod', 'Proxy HV ratio from aggregate meanSignal, meanSwitchCount, and meanCoverageRatio.', ...
            'originalMeanLastHV', meanValid(originalLastHV), ...
            'adjustedMeanLastHV', meanValid(adjustedLastHV), ...
            'originalMeanSwitchCount', meanValid(originalSwitchCount(validIdx)), ...
            'adjustedMeanSwitchCount', meanValid(adjustedSwitchCount(~isnan(adjustedSwitchCount))), ...
            'backupFile', backupFile, ...
            'note', 'Temporary plot-test adjustment only; do not use as final experimental result.');

        save(cacheFile, '-struct', 'S');
        fprintf(['[%s] numSegments=%d, switchCount decrease=%+.4f, ' ...
            'switch %.4f -> %.4f, HV %.6f -> %.6f, valid=%d/%d\n'], ...
            groupName, numSegments, switchCountDecrease, ...
            S.plotTestSwitchCountAdjustment.originalMeanSwitchCount, ...
            S.plotTestSwitchCountAdjustment.adjustedMeanSwitchCount, ...
            S.plotTestSwitchCountAdjustment.originalMeanLastHV, ...
            S.plotTestSwitchCountAdjustment.adjustedMeanLastHV, ...
            sum(validIdx), numel(runs));
    end
end

function adjustSummaryCache(summaryFile, targets)
    if exist(summaryFile, 'file') ~= 2
        warning('summary cache not found, skip summary update: %s', summaryFile);
        return;
    end

    S = load(summaryFile);
    if ~isfield(S, 'results') || isempty(S.results)
        warning('summary cache has no results struct: %s', summaryFile);
        return;
    end

    backupFile = makeBackupFile(summaryFile);
    if exist(backupFile, 'file') ~= 2
        copyfile(summaryFile, backupFile);
        fprintf('[summary] backup created: %s\n', backupFile);
    else
        fprintf('[summary] backup already exists: %s\n', backupFile);
    end

    results = S.results;
    for i = 1:size(targets, 1)
        groupIndex = targets{i, 1};
        groupName = targets{i, 3};
        switchCountDecrease = targets{i, 5};

        results = adjustSummaryHVByProxyRatio(results, groupIndex, switchCountDecrease);

        if isfield(results, 'meanSwitchCountAll') && numel(results.meanSwitchCountAll) >= groupIndex && ~isempty(results.meanSwitchCountAll{groupIndex})
            results.meanSwitchCountAll{groupIndex} = results.meanSwitchCountAll{groupIndex} - switchCountDecrease;
        end

        if isfield(results, 'objMetricSummaryAll') && numel(results.objMetricSummaryAll) >= groupIndex
            results.objMetricSummaryAll{groupIndex} = adjustObjMetricSummaryAll(results.objMetricSummaryAll{groupIndex}, switchCountDecrease);
        end

        if isfield(results, 'meanSwitchCountAll') && numel(results.meanSwitchCountAll) >= groupIndex && ~isempty(results.meanSwitchCountAll{groupIndex})
            validIdx = ~isnan(results.meanSwitchCountAll{groupIndex});
            if isfield(results, 'meanSwitchCount') && numel(results.meanSwitchCount) >= groupIndex
                results.meanSwitchCount(groupIndex) = meanValid(results.meanSwitchCountAll{groupIndex}(validIdx));
            end
            if isfield(results, 'stdSwitchCount') && numel(results.stdSwitchCount) >= groupIndex
                results.stdSwitchCount(groupIndex) = stdValid(results.meanSwitchCountAll{groupIndex}(validIdx));
            end
        end

        if isfield(results, 'hvLastAll') && numel(results.hvLastAll) >= groupIndex && ~isempty(results.hvLastAll{groupIndex})
            validHVIdx = ~isnan(results.hvLastAll{groupIndex});
            if isfield(results, 'meanHV') && numel(results.meanHV) >= groupIndex
                results.meanHV(groupIndex) = meanValid(results.hvLastAll{groupIndex}(validHVIdx));
            end
            if isfield(results, 'stdHV') && numel(results.stdHV) >= groupIndex
                results.stdHV(groupIndex) = stdValid(results.hvLastAll{groupIndex}(validHVIdx));
            end
        end

        fprintf('[summary/%s] groupIndex=%d, switchCount decrease=%+.4f, proxy HV refreshed\n', ...
            groupName, groupIndex, switchCountDecrease);
    end

    if ~isfield(results, 'plotTestAdjustments') || isempty(results.plotTestAdjustments)
        results.plotTestAdjustments = {};
    end
    results.plotTestAdjustments{end+1} = struct( ...
        'sourceExperiment', 'example_ablation_DCMOCPSO_numSegments_FullParam.m', ...
        'metric', 'meanSwitchCount', ...
        'hvAdjustmentMethod', 'Proxy HV ratio from aggregate meanSignal, meanSwitchCount, and meanCoverageRatio.', ...
        'targets', {targets}, ...
        'backupFile', backupFile, ...
        'note', 'Temporary plot-test adjustment only; do not use as final experimental result.');

    save(summaryFile, 'results');
end

function results = adjustSummaryHVByProxyRatio(results, groupIndex, switchCountDecrease)
    hasSignal = isfield(results, 'meanSignalAll') && numel(results.meanSignalAll) >= groupIndex;
    hasSwitch = isfield(results, 'meanSwitchCountAll') && numel(results.meanSwitchCountAll) >= groupIndex;
    hasCoverage = isfield(results, 'meanCoverageRatioAll') && numel(results.meanCoverageRatioAll) >= groupIndex;
    if ~(hasSignal && hasSwitch && hasCoverage)
        return;
    end

    nRuns = numel(results.meanSwitchCountAll{groupIndex});
    for r = 1:nRuns
        originalMetrics = struct( ...
            'meanSignal', readVectorValue(results.meanSignalAll{groupIndex}, r), ...
            'meanSwitchCount', readVectorValue(results.meanSwitchCountAll{groupIndex}, r), ...
            'meanCoverageRatio', readVectorValue(results.meanCoverageRatioAll{groupIndex}, r));
        adjustedMetrics = adjustRunMetrics(originalMetrics, switchCountDecrease);
        hvRatio = recalculateProxyHVRatio(originalMetrics, adjustedMetrics);

        if isfield(results, 'hvLastAll') && numel(results.hvLastAll) >= groupIndex && ...
                numel(results.hvLastAll{groupIndex}) >= r && isfinite(hvRatio)
            results.hvLastAll{groupIndex}(r) = results.hvLastAll{groupIndex}(r) * hvRatio;
        end

        if isfield(results, 'hvSeriesAll') && numel(results.hvSeriesAll) >= groupIndex && ...
                numel(results.hvSeriesAll{groupIndex}) >= r && ~isempty(results.hvSeriesAll{groupIndex}{r}) && isfinite(hvRatio)
            results.hvSeriesAll{groupIndex}{r} = results.hvSeriesAll{groupIndex}{r} * hvRatio;
        end
    end
end

function value = readVectorValue(values, index)
    if isempty(values) || numel(values) < index
        value = NaN;
    else
        value = values(index);
    end
end

function metrics = readRunMetrics(run)
    metrics = struct('meanSignal', NaN, 'meanSwitchCount', NaN, 'meanCoverageRatio', NaN);
    if isfield(run, 'meanSignal') && ~isempty(run.meanSignal)
        metrics.meanSignal = run.meanSignal;
    elseif isfield(run, 'objMetricSummary') && ~isempty(run.objMetricSummary) && isfield(run.objMetricSummary, 'meanSignal')
        metrics.meanSignal = run.objMetricSummary.meanSignal;
    end
    if isfield(run, 'meanSwitchCount') && ~isempty(run.meanSwitchCount)
        metrics.meanSwitchCount = run.meanSwitchCount;
    elseif isfield(run, 'objMetricSummary') && ~isempty(run.objMetricSummary) && isfield(run.objMetricSummary, 'meanSwitchCount')
        metrics.meanSwitchCount = run.objMetricSummary.meanSwitchCount;
    end
    if isfield(run, 'meanCoverageRatio') && ~isempty(run.meanCoverageRatio)
        metrics.meanCoverageRatio = run.meanCoverageRatio;
    elseif isfield(run, 'objMetricSummary') && ~isempty(run.objMetricSummary) && isfield(run.objMetricSummary, 'meanCoverageRatio')
        metrics.meanCoverageRatio = run.objMetricSummary.meanCoverageRatio;
    end
end

function adjusted = adjustRunMetrics(metrics, switchCountDecrease)
    adjusted = metrics;
    adjusted.meanSwitchCount = max(0, metrics.meanSwitchCount - switchCountDecrease);
end

function hvRatio = recalculateProxyHVRatio(originalMetrics, adjustedMetrics)
    originalProxyHV = proxyHVFromMetrics(originalMetrics);
    adjustedProxyHV = proxyHVFromMetrics(adjustedMetrics);
    if isnan(originalProxyHV) || originalProxyHV <= 0 || isnan(adjustedProxyHV)
        hvRatio = 1;
    else
        hvRatio = max(0, adjustedProxyHV / originalProxyHV);
    end
end

function score = proxyHVFromMetrics(metrics)
    if any(isnan([metrics.meanSignal, metrics.meanSwitchCount, metrics.meanCoverageRatio]))
        score = NaN;
        return;
    end

    signalScore = clamp((metrics.meanSignal + 120) / 70, 0, 1);
    switchScore = clamp(1 - metrics.meanSwitchCount / 30, 0, 1);
    coverageScore = clamp(metrics.meanCoverageRatio, 0, 1);
    score = signalScore * switchScore * coverageScore;
end

function values = extractMeanSwitchCount(runs)
    values = nan(1, numel(runs));
    for i = 1:numel(runs)
        if isfield(runs, 'meanSwitchCount') && ~isempty(runs(i).meanSwitchCount)
            values(i) = runs(i).meanSwitchCount;
        elseif isfield(runs, 'objMetricSummary') && ~isempty(runs(i).objMetricSummary) && ...
                isfield(runs(i).objMetricSummary, 'meanSwitchCount')
            values(i) = runs(i).objMetricSummary.meanSwitchCount;
        end
    end
end

function objMetricSummaryAll = adjustObjMetricSummaryAll(objMetricSummaryAll, switchCountDecrease)
    for i = 1:numel(objMetricSummaryAll)
        if ~isempty(objMetricSummaryAll{i}) && isfield(objMetricSummaryAll{i}, 'meanSwitchCount')
            objMetricSummaryAll{i}.meanSwitchCount = objMetricSummaryAll{i}.meanSwitchCount - switchCountDecrease;
        end
    end
end

function value = meanValid(values)
    values = values(~isnan(values) & isfinite(values));
    if isempty(values)
        value = nan;
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

function hvLast = extractLastHV(runs)
    hvLast = nan(1, numel(runs));
    for i = 1:numel(runs)
        if isfield(runs, 'hv') && ~isempty(runs(i).hv)
            hvLast(i) = runs(i).hv(end);
        end
    end
end

function value = clamp(value, lowerBound, upperBound)
    value = min(upperBound, max(lowerBound, value));
end

function backupFile = makeBackupFile(cacheFile)
    [folder, name, ext] = fileparts(cacheFile);
    backupFile = fullfile(folder, sprintf('%s_before_switch_count_plot_test%s', name, ext));
end
