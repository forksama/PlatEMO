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
