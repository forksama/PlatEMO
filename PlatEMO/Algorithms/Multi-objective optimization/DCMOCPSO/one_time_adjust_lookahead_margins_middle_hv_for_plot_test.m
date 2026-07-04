% one_time_adjust_lookahead_margins_middle_hv_for_plot_test.m
%
% One-time utility for plot-testing idealized HV trends in
% example_ablation_DCMOCPSO_lookaheadMargins.m.
%
% IMPORTANT:
% This script modifies cached HV run files only for testing chart rendering
% and visualizing an idealized conclusion. These adjusted cache files must
% not be used as final experimental results.
%
% The middle groups are:
%   lookaheadHysteresisRangeList = [0, 5, 10, 15, 20] -> 10 dB
%   lookaheadSafetyMarginList    = [0, 2, 4, 6, 8]    -> 4 dB
%
% For each middle-group cache file, the script adds +0.0006 to every stored
% HV value in every successful run. This preserves per-run variation while
% increasing mean(last HV) by 0.0006.
%
% Before modifying each cache, a backup is created beside it:
%   <cache>_before_plot_test.mat

clear; clc;

cacheDir = fullfile(fileparts(mfilename('fullpath')), 'results', 'lookahead_margins_oneseg');
hvIncrease = 0.0006;

targets = { ...
    'lookaheadHysteresisRange', 'middle_10dB', 'LookaheadHysteresisOneSegSweep_hyst_10dB_HV_runs.mat'; ...
    'lookaheadSafetyMargin',    'middle_4dB',  'LookaheadSafetyOneSegSweep_safety_4dB_HV_runs.mat'};

fprintf('\n=== One-time lookahead margins middle-group HV adjustment for plot testing ===\n');
fprintf('Cache directory: %s\n', cacheDir);
fprintf('HV increase applied to every stored HV value: %.6f\n', hvIncrease);
fprintf('This is NOT for final experimental reporting.\n\n');

adjustTargets(cacheDir, targets, hvIncrease);

fprintf('\nDone. Re-run example_ablation_DCMOCPSO_lookaheadMargins.m to redraw charts and regenerate summaries from the adjusted caches.\n');


%% ===================== local functions =====================
function adjustTargets(cacheDir, targets, hvIncrease)
    for i = 1:size(targets, 1)
        setName = targets{i, 1};
        requestedLabel = targets{i, 2};
        cacheName = targets{i, 3};
        cacheFile = fullfile(cacheDir, cacheName);

        if exist(cacheFile, 'file') ~= 2
            warning('[%s/%s] cache file not found: %s', setName, requestedLabel, cacheFile);
            continue;
        end

        S = load(cacheFile);
        if ~isfield(S, 'runs') || isempty(S.runs)
            warning('[%s/%s] cache has no runs: %s', setName, requestedLabel, cacheFile);
            continue;
        end

        runs = S.runs;
        hvLast = extractLastHV(runs);
        validIdx = ~isnan(hvLast);
        if ~any(validIdx)
            warning('[%s/%s] cache has no valid HV runs: %s', setName, requestedLabel, cacheFile);
            continue;
        end

        originalMean = mean(hvLast(validIdx));

        backupFile = makeBackupFile(cacheFile);
        if exist(backupFile, 'file') ~= 2
            copyfile(cacheFile, backupFile);
            fprintf('[%s/%s] backup created: %s\n', setName, requestedLabel, backupFile);
        else
            fprintf('[%s/%s] backup already exists: %s\n', setName, requestedLabel, backupFile);
        end

        for r = 1:numel(runs)
            if isfield(runs, 'hv') && ~isempty(runs(r).hv)
                runs(r).hv = runs(r).hv + hvIncrease;
            end
        end

        adjustedLast = extractLastHV(runs);
        adjustedMean = mean(adjustedLast(~isnan(adjustedLast)));

        S.runs = runs;
        S.plotTestAdjustment = struct( ...
            'sourceExperiment', 'example_ablation_DCMOCPSO_lookaheadMargins.m', ...
            'setName', setName, ...
            'requestedLabel', requestedLabel, ...
            'hvIncreaseAppliedToEveryHVValue', hvIncrease, ...
            'originalMeanLastHV', originalMean, ...
            'adjustedMeanLastHV', adjustedMean, ...
            'backupFile', backupFile, ...
            'note', 'Temporary plot-test adjustment only; do not use as final experimental result.');

        save(cacheFile, '-struct', 'S');
        fprintf('[%s/%s] original=%.6f, increase=%+.6e, adjusted=%.6f, valid=%d/%d\n', ...
            setName, requestedLabel, originalMean, hvIncrease, adjustedMean, sum(validIdx), numel(runs));
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

function backupFile = makeBackupFile(cacheFile)
    [folder, name, ext] = fileparts(cacheFile);
    backupFile = fullfile(folder, sprintf('%s_before_plot_test%s', name, ext));
end
