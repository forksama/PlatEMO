function tests = test_example_compare_DCMOCPSO_vs_baselines_FE_sweep
% Static checks for FE-sweep baseline comparison.
tests = functiontests(localfunctions);
end

function testUsesRequestedFEBudgetsAndFullParamDCMOCPSO(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_DCMOCPSOList\s*=\s*\[50,\s*100,\s*200\]\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'param_Full\s*=\s*\{numSegments,\s*2,\s*0\.5,\s*0\.3,\s*true,\s*true,\s*true\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'for\s+setIdx\s*=\s*1:numel\(maxFE_DCMOCPSOList\)', 'once'));
end

function testReusesBudget100CacheNamesAndPrefixesOthers(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'function\s+cacheFile\s*=\s*makeCacheFile\(cacheDir,\s*groupName,\s*maxFE_DCMOCPSO\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'if\s+maxFE_DCMOCPSO\s*==\s*100[\s\S]*?sprintf\(''%s_HV_runs\.mat'',\s*groupName\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'sprintf\(''FE%d_%s_HV_runs\.mat'',\s*maxFE_DCMOCPSO,\s*groupName\)', 'once'));
end

function testEachBudgetRunsAllBaselineGroups(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'runOrLoad\([\s\S]*?sprintf\(''FE%d/DCMOCPSO'',\s*maxFE_DCMOCPSO\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runOrLoad\([\s\S]*?sprintf\(''FE%d/Base-MOCPSO'',\s*maxFE_DCMOCPSO\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runOrLoad\([\s\S]*?sprintf\(''FE%d/DGEA'',\s*maxFE_DCMOCPSO\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'runOrLoad\([\s\S]*?sprintf\(''FE%d/IMMOEAD'',\s*maxFE_DCMOCPSO\)', 'once'));
end

function testSavesCombinedFEGroups(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'setResults\s*=\s*cell\(1,\s*numel\(maxFE_DCMOCPSOList\)\)\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.setResults\s*=\s*setResults\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'DCMOCPSO_vs_baselines_FE_sweep_summary\.mat', 'once'));
end

function testFairFEBudgetDerivedPerSet(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'validFE_DCMOCPSO\s*=\s*loadAllActualFE\(cacheFile_DCMOCPSO\)\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'competitorMaxFE\s*=\s*round\(mean\(validFE_DCMOCPSO\)\)\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_BaseMOCPSO\s*=\s*max\(1,\s*round\(competitorMaxFE\s*/\s*numSegments\)\)\s*;', 'once'));
end

function testPlotsEachFEComparisonSetInOneFigure(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'figure\(''Name'',\s*sprintf\(''%s metrics comparison'',\s*result\.setName\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'tiledlayout\(2,\s*3,\s*''TileSpacing'',\s*''compact'',\s*''Padding'',\s*''compact''\)', 'once'));
verifyEqual(testCase, numel(regexp(scriptText, ...
    'plotBarComparison\(nexttile\(layout\)', 'match')), 5);
verifyEmpty(testCase, regexp(scriptText, ...
    'function\s+plotBarComparison\(figName', 'once'));
end

function scriptText = readScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_compare_DCMOCPSO_vs_baselines.m');
scriptText = fileread(scriptPath);
end
