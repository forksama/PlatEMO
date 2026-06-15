function tests = test_example_compare_DCMOCPSO_vs_MOCPSO_Ek_three_stage
% Static checks for the three-stage lookahead/segmentation/full-param ablation.
tests = functiontests(localfunctions);
end

function testUsesThreeStageLookaheadAblationOnly(testCase)
scriptText = readComparisonScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'groupNames\s*=\s*\{''OneSeg_Lookahead'',\s*''Seg_Lookahead'',\s*''Full_Lookahead''\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_DCMOCPSOList\s*=\s*\[50,\s*100,\s*200\]\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'n\s*=\s*10\s*;', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'problemParameter_Base|problemParameter_A3|cacheFile_OneSeg\s*=|cacheFile_OneSeg_A3|hvLast_OneSeg_A3|meanHV_OneSeg_A3', 'once'));
end

function testRunsEachMaxFEAsSeparateExperimentSet(testCase)
scriptText = readComparisonScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'for\s+setIdx\s*=\s*1:numel\(maxFE_DCMOCPSOList\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_DCMOCPSO\s*=\s*maxFE_DCMOCPSOList\(setIdx\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'makeCacheFile\(cacheDir,\s*''Full_Lookahead'',\s*maxFE_DCMOCPSO\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'makeCacheFile\(cacheDir,\s*''Seg_Lookahead'',\s*maxFE_DCMOCPSO\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'makeCacheFile\(cacheDir,\s*''OneSeg_Lookahead'',\s*maxFE_DCMOCPSO\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'if\s+maxFE_DCMOCPSO\s*==\s*100[\s\S]*?sprintf\(''%s_HV_runs\.mat'',\s*groupName\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'sprintf\(''FE%d_%s_HV_runs\.mat'',\s*maxFE_DCMOCPSO,\s*groupName\)', 'once'));
end

function testAllGroupsUseLookaheadSwitchMethod(testCase)
scriptText = readComparisonScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_Lookahead\s*=\s*\{20,\s*20,\s*5,\s*-101\.5,\s*0,\s*30,\s*2,\s*500\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    '''OneSeg_Lookahead''[\s\S]*?problemParameter_Lookahead[\s\S]*?param_OneSeg', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    '''Seg_Lookahead''[\s\S]*?problemParameter_Lookahead[\s\S]*?param_Seg', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    '''Full_Lookahead''[\s\S]*?problemParameter_Lookahead[\s\S]*?param_Full', 'once'));
end

function testSummaryAndPlotsUseThreeGroups(testCase)
scriptText = readComparisonScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.groupNames\s*=\s*groupNames\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'figure\(''Name'',\s*sprintf\(''%s metrics'',\s*result\.setName\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'tiledlayout\(1,\s*2,\s*''TileSpacing'',\s*''compact'',\s*''Padding'',\s*''compact''\)', 'once'));
verifyEqual(testCase, numel(regexp(scriptText, ...
    'plotBarComparison\(nexttile\(layout\)', 'match')), 2);
verifyEmpty(testCase, regexp(scriptText, ...
    'function\s+plotBarComparison\(figName', 'once'));
end

function scriptText = readComparisonScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_compare_DCMOCPSO_vs_MOCPSO_Ek.m');
scriptText = fileread(scriptPath);
end
