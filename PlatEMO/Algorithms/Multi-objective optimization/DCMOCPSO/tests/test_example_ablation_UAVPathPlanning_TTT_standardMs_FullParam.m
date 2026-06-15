function tests = test_example_ablation_UAVPathPlanning_TTT_standardMs_FullParam
% Static checks for the standard-like TTT millisecond ablation.
tests = functiontests(localfunctions);
end

function testUsesRequestedMillisecondValuesAndConvertsToSeconds(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'TTTListMs\s*=\s*\[320,\s*512,\s*1024,\s*2560,\s*5120\]\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'TTTList\s*=\s*TTTListMs\s*/\s*1000\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter\{3\}\s*=\s*TTTSeconds', 'once'));
end

function testKeepsOriginalFullParamSettings(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'n\s*=\s*20\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_Full\s*=\s*100\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'baseProblemParameter\s*=\s*\{20,\s*20,\s*5,\s*-101\.5,\s*0,\s*30,\s*2,\s*500,\s*10,\s*4\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'param_Full\s*=\s*\{5,\s*2,\s*0\.5,\s*0\.3,\s*true,\s*true,\s*true\}\s*;', 'once'));
end

function testUsesSeparateCacheAndMillisecondLabels(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    '''ttt_standard_ms_full_param''', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'sprintf\(''ttt_%dms'',\s*v\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'TTT_StandardMs_Full_ttt_%dms_HV_objMetrics_runs\.mat', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'TTT_StandardMs_Full_summary\.mat', 'once'));
end

function testPersistsEachRunAndUsesNoPopupOutputFunction(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'save\(cacheFile,\s*''runs''\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'outputFcn'',\s*@\(~,~\)\[\]', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'if\s+loadCount\s*>=\s*n\s*[\r\n]+\s*return\s*;', 'once'));
end

function testPlotsAllMetricsInOneFigure(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'figure\(''Name'',\s*sprintf\(''%s metrics'',\s*results\.experimentName\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'tiledlayout\(2,\s*3,\s*''TileSpacing'',\s*''compact'',\s*''Padding'',\s*''compact''\)', 'once'));
verifyEqual(testCase, numel(regexp(scriptText, ...
    'plotBarComparison\(nexttile\(layout\)', 'match')), 5);
verifyEmpty(testCase, regexp(scriptText, ...
    'function\s+plotBarComparison\(figName', 'once'));
end

function scriptText = readScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_ablation_UAVPathPlanning_TTT_standardMs_FullParam.m');
scriptText = fileread(scriptPath);
end
