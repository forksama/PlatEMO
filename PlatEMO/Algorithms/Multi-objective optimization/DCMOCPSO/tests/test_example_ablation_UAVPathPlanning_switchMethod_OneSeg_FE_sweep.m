function tests = test_example_ablation_UAVPathPlanning_switchMethod_OneSeg_FE_sweep
% Static checks for OneSeg switch-method FE-sweep ablation.
tests = functiontests(localfunctions);
end

function testUsesRequestedFEBudgetsAndOneSegParam(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_OneSegList\s*=\s*\[200,\s*400,\s*800\]\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'param_OneSeg\s*=\s*\{1,\s*2,\s*0\.5,\s*0\.3,\s*false,\s*false,\s*false\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'for\s+setIdx\s*=\s*1:numel\(maxFE_OneSegList\)', 'once'));
end

function testReusesBudget400CacheNamesAndPrefixesOthers(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'function\s+cacheFile\s*=\s*makeCacheFile\(cacheDir,\s*groupName,\s*maxFE_OneSeg\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'if\s+maxFE_OneSeg\s*==\s*400[\s\S]*?sprintf\(''OneSegSwitchMethod_%s_HV_objMetrics_runs\.mat'',\s*groupName\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'sprintf\(''FE%d_OneSegSwitchMethod_%s_HV_objMetrics_runs\.mat'',\s*maxFE_OneSeg,\s*groupName\)', 'once'));
end

function testAllThreeSwitchMethodGroupsStillRun(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'groupNames\s*=\s*\{''OneSeg'',\s*''OneSeg_A3'',\s*''OneSeg_Lookahead''\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_Base\{7\}\s*=\s*0\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_A3\{7\}\s*=\s*3\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_Lookahead\{7\}\s*=\s*2\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runOne_DCMOCPSO\(N,\s*maxFE_OneSeg,\s*groupProblemParams\{i\},\s*param_OneSeg\)', 'once'));
end

function testSavesCombinedFEGroups(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'setResults\s*=\s*cell\(1,\s*numel\(maxFE_OneSegList\)\)\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.setResults\s*=\s*setResults\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'OneSegSwitchMethod_FE_sweep_summary\.mat', 'once'));
end

function testPlotsEachFEGroupInOneFigure(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'figure\(''Name'',\s*sprintf\(''%s switch-method metrics'',\s*result\.setName\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'tiledlayout\(2,\s*3,\s*''TileSpacing'',\s*''compact'',\s*''Padding'',\s*''compact''\)', 'once'));
verifyEqual(testCase, numel(regexp(scriptText, ...
    'plotBarComparison\(nexttile\(layout\)', 'match')), 5);
verifyEmpty(testCase, regexp(scriptText, ...
    'function\s+plotBarComparison\(figName', 'once'));
end

function scriptText = readScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_ablation_UAVPathPlanning_switchMethod_OneSeg.m');
scriptText = fileread(scriptPath);
end
