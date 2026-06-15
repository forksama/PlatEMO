function tests = test_DCMOCPSO_experiment_metric_persistence
% Static checks that experiment scripts persist objective-level metrics.
tests = functiontests(localfunctions);
end

function testCachedExperimentScriptsPersistObjectiveMetrics(testCase)
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptNames = {
    'example_ablation_DCMOCPSO_lambda_cguide.m'
    'example_ablation_DCMOCPSO_lookaheadDistance.m'
    'example_ablation_DCMOCPSO_lookaheadMargins.m'
    'example_compare_DCMOCPSO_uniformPointMultiplier.m'
    'example_compare_DCMOCPSO_vs_MOCPSO_Ek.m'
    'example_compare_DCMOCPSO_vs_baselines.m'
    'example_compare_UAVPathPlanning_lookahead_only_OneSeg.m'
    'example_ablation_UAVPathPlanning_switchMethod_OneSeg.m'
    'example_ablation_UAVPathPlanning_altitudeRange.m'
    'example_ablation_UAVPathPlanning_velocity_FullParam.m'
    'example_ablation_UAVPathPlanning_TTT_bsDensity_FullParam.m'
    'example_ablation_DCMOCPSO_numSegments_FullParam.m'
    };

for i = 1:numel(scriptNames)
    scriptText = fileread(fullfile(scriptDir, scriptNames{i}));
    verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.meanSignal\s*=', 'once'), scriptNames{i});
    verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.meanSwitchCount\s*=', 'once'), scriptNames{i});
    verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.meanCoverageRatio\s*=', 'once'), scriptNames{i});
    verifyNotEmpty(testCase, regexp(scriptText, 'runs\(i\)\.objMetricSummary\s*=', 'once'), scriptNames{i});
    verifyNotEmpty(testCase, regexp(scriptText, 'extractObjectiveMetrics', 'once'), scriptNames{i});
end
end

function testExperimentScriptsUseSeparateCacheDirectories(testCase)
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptAndCacheDirs = {
    'example_ablation_DCMOCPSO_lambda_cguide.m', 'lambda_cguide'
    'example_ablation_DCMOCPSO_lookaheadDistance.m', 'lookahead_distance_oneseg'
    'example_ablation_DCMOCPSO_lookaheadMargins.m', 'lookahead_margins_oneseg'
    'example_compare_DCMOCPSO_uniformPointMultiplier.m', 'uniform_point_multiplier'
    'example_compare_DCMOCPSO_vs_MOCPSO_Ek.m', 'compare_vs_mocpso_ek'
    'example_compare_DCMOCPSO_vs_baselines.m', 'compare_vs_baselines'
    'example_compare_UAVPathPlanning_lookahead_only_OneSeg.m', 'lookahead_only_oneseg'
    'example_ablation_UAVPathPlanning_switchMethod_OneSeg.m', 'switch_method_oneseg'
    'example_ablation_UAVPathPlanning_altitudeRange.m', 'altitude_range_full_param'
    'example_ablation_UAVPathPlanning_velocity_FullParam.m', 'velocity_full_param'
    'example_ablation_UAVPathPlanning_TTT_bsDensity_FullParam.m', 'ttt_bs_density_full_param'
    'example_ablation_DCMOCPSO_numSegments_FullParam.m', 'num_segments_full_param'
    };

for i = 1:size(scriptAndCacheDirs, 1)
    scriptText = fileread(fullfile(scriptDir, scriptAndCacheDirs{i, 1}));
    expectedPattern = sprintf('cacheDir\\s*=\\s*fullfile\\(fileparts\\(mfilename\\(''fullpath''\\)\\),\\s*''results'',\\s*''%s''\\)', scriptAndCacheDirs{i, 2});
    verifyNotEmpty(testCase, regexp(scriptText, expectedPattern, 'once'), scriptAndCacheDirs{i, 1});
    verifyEmpty(testCase, regexp(scriptText, ...
        'cacheDir\s*=\s*fullfile\(fileparts\(mfilename\(''fullpath''\)\),\s*''results''\)\s*;', 'once'), scriptAndCacheDirs{i, 1});
end
end

function testMissingObjectiveMetricsDoNotTriggerReruns(testCase)
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptNames = {
    'example_ablation_DCMOCPSO_lambda_cguide.m'
    'example_ablation_DCMOCPSO_lookaheadDistance.m'
    'example_ablation_DCMOCPSO_lookaheadMargins.m'
    'example_compare_DCMOCPSO_uniformPointMultiplier.m'
    'example_compare_DCMOCPSO_vs_MOCPSO_Ek.m'
    'example_compare_DCMOCPSO_vs_baselines.m'
    'example_compare_UAVPathPlanning_lookahead_only_OneSeg.m'
    'example_ablation_UAVPathPlanning_switchMethod_OneSeg.m'
    'example_ablation_UAVPathPlanning_altitudeRange.m'
    'example_ablation_UAVPathPlanning_velocity_FullParam.m'
    'example_ablation_UAVPathPlanning_TTT_bsDensity_FullParam.m'
    'example_ablation_DCMOCPSO_numSegments_FullParam.m'
    };

for i = 1:numel(scriptNames)
    scriptText = fileread(fullfile(scriptDir, scriptNames{i}));
    verifyNotEmpty(testCase, regexp(scriptText, ...
        'if\s+loadCount\s*>=\s*n\s*[\r\n]+\s*return\s*;', 'once'), scriptNames{i});
    verifyNotEmpty(testCase, regexp(scriptText, ...
        'startRun\s*=\s*loadCount\s*\+\s*1\s*;', 'once'), scriptNames{i});
    verifyEmpty(testCase, regexp(scriptText, ...
        'all\(~isnan\(hvLast\)\)', 'once'), scriptNames{i});
    verifyEmpty(testCase, regexp(scriptText, ...
        'startRun\s*=\s*find\(isnan\(hvLast\),\s*1\)', 'once'), scriptNames{i});
    verifyEmpty(testCase, regexp(scriptText, ...
        'loadCount\s*>=\s*n[\s\S]*?isnan\(meanSignal\)', 'once'), scriptNames{i});
    verifyEmpty(testCase, regexp(scriptText, ...
        'startRun\s*=\s*find\([^\n]*meanSignal', 'once'), scriptNames{i});
end
end

function testOneSegSwitchMethodAblationUsesOnlyThreeGroups(testCase)
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptText = fileread(fullfile(scriptDir, 'example_ablation_UAVPathPlanning_switchMethod_OneSeg.m'));

verifyNotEmpty(testCase, regexp(scriptText, ...
    'param_OneSeg\s*=\s*\{1,\s*2,\s*0\.5,\s*0\.3,\s*false,\s*false,\s*false\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'groupNames\s*=\s*\{''OneSeg'',\s*''OneSeg_A3'',\s*''OneSeg_Lookahead''\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_Base\{7\}\s*=\s*0\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_A3\{7\}\s*=\s*3\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_Lookahead\{7\}\s*=\s*2\s*;', 'once'));
verifyEmpty(testCase, regexp(scriptText, '''Seg_Lookahead''|''Full_Lookahead''', 'once'));
end

function testLookaheadDistanceUsesOneSegLookaheadSettings(testCase)
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptText = fileread(fullfile(scriptDir, 'example_ablation_DCMOCPSO_lookaheadDistance.m'));

verifyNotEmpty(testCase, regexp(scriptText, ...
    'param_OneSeg\s*=\s*\{1,\s*2,\s*0\.5,\s*0\.3,\s*false,\s*false,\s*false\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'commonConfig\.param_OneSeg', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'LookaheadDistance_OneSeg_', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'useDynamicGrouping\s*=', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'useDynamicMutation\s*=', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'useEk\s*=', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'uniformPointMultiplier\s*=', 'once'));
end

function testLookaheadAblationsPlotObjectiveMetrics(testCase)
scriptDir = fileparts(fileparts(mfilename('fullpath')));
distanceText = fileread(fullfile(scriptDir, 'example_ablation_DCMOCPSO_lookaheadDistance.m'));
marginsText = fileread(fullfile(scriptDir, 'example_ablation_DCMOCPSO_lookaheadMargins.m'));

verifyNotEmpty(testCase, regexp(distanceText, ...
    'plotBarComparison\(''lookahead distance sweep signal''[\s\S]*?meanSignal,\s*stdSignal', 'once'));
verifyNotEmpty(testCase, regexp(distanceText, ...
    'plotBarComparison\(''lookahead distance sweep switch count''[\s\S]*?meanSwitchCount,\s*stdSwitchCount', 'once'));
verifyNotEmpty(testCase, regexp(distanceText, ...
    'plotBarComparison\(''lookahead distance sweep coverage''[\s\S]*?meanCoverageRatio,\s*stdCoverageRatio', 'once'));

verifyNotEmpty(testCase, regexp(marginsText, ...
    'plotBarComparison\(''lookahead hysteresis sweep signal''[\s\S]*?hysteresisResults\.meanSignal,\s*hysteresisResults\.stdSignal', 'once'));
verifyNotEmpty(testCase, regexp(marginsText, ...
    'plotBarComparison\(''lookahead hysteresis sweep switch count''[\s\S]*?hysteresisResults\.meanSwitchCount,\s*hysteresisResults\.stdSwitchCount', 'once'));
verifyNotEmpty(testCase, regexp(marginsText, ...
    'plotBarComparison\(''lookahead hysteresis sweep coverage''[\s\S]*?hysteresisResults\.meanCoverageRatio,\s*hysteresisResults\.stdCoverageRatio', 'once'));
verifyNotEmpty(testCase, regexp(marginsText, ...
    'plotBarComparison\(''lookahead safety sweep signal''[\s\S]*?safetyResults\.meanSignal,\s*safetyResults\.stdSignal', 'once'));
verifyNotEmpty(testCase, regexp(marginsText, ...
    'plotBarComparison\(''lookahead safety sweep switch count''[\s\S]*?safetyResults\.meanSwitchCount,\s*safetyResults\.stdSwitchCount', 'once'));
verifyNotEmpty(testCase, regexp(marginsText, ...
    'plotBarComparison\(''lookahead safety sweep coverage''[\s\S]*?safetyResults\.meanCoverageRatio,\s*safetyResults\.stdCoverageRatio', 'once'));
end
