function tests = test_example_ablation_DCMOCPSO_numSegments_FullParam
% Static checks for the paired full_param numSegments ablation.
tests = functiontests(localfunctions);
end

function testUsesSegmentedGroupsOnlyAndKeepsFullParamBudget(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'n\s*=\s*20\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_Segmented\s*=\s*100\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'segmentedNumSegmentsList\s*=\s*\[3,\s*5,\s*7,\s*9\]\s*;', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'segmentedNumSegmentsList\s*=\s*\[1,', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'baseParam_Full\s*=\s*\{5,\s*2,\s*0\.5,\s*0\.3,\s*true,\s*true,\s*true\}\s*;', 'once'));
end

function testSegmentedCachesAreReusedAndOriginalSeg1IsNotUsed(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'NumSegments_Full_seg_%s_HV_objMetrics_runs\.mat', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'NumSegments_Full_oneSeg_for_seg_%s_FE_%s_HV_objMetrics_runs\.mat', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'NumSegments_Full_seg_1_HV_objMetrics_runs\.mat', 'once'));
end

function testOneSegBudgetIsDerivedFromSegmentedActualFE(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'validFE_Segmented\s*=\s*loadAllActualFE\(cacheFile_Segmented\)\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'maxFE_OneSeg\s*=\s*max\(1,\s*round\(meanValid\(validFE_Segmented\)\s*/\s*numSegments\)\)\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'makeAlgorithmParameter\(baseParam_Full,\s*1\)', 'once'));
end

function testSummaryTracksPairMetadataAndPlotsMetrics(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.sourceSegmentList\s*=\s*sourceSegmentList\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.segmentRoleList\s*=\s*segmentRoleList\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'results\.maxFEAll\s*=\s*maxFEAll\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'NumSegments_Full_paired_oneSeg_summary\.mat', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'plotMetricSet\(''Full_Lookahead paired numSegments ablation''[\s\S]*?meanSignal,\s*stdSignal,[\s\S]*?meanSwitchCount,\s*stdSwitchCount,[\s\S]*?meanCoverageRatio,\s*stdCoverageRatio', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'tiledlayout\(2,\s*3,\s*''TileSpacing'',\s*''compact'',\s*''Padding'',\s*''compact''\)', 'once'));
verifyEqual(testCase, numel(regexp(scriptText, ...
    'plotBarComparison\(nexttile\(layout\)', 'match')), 5);
verifyEmpty(testCase, regexp(scriptText, ...
    'function\s+plotBarComparison\(figName', 'once'));
end

function testCacheCompletionUsesRunCountOnly(testCase)
scriptText = readScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'if\s+loadCount\s*>=\s*n\s*[\r\n]+\s*return\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'startRun\s*=\s*loadCount\s*\+\s*1\s*;', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'all\(~isnan\(hvLast\)\)', 'once'));
end

function scriptText = readScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_ablation_DCMOCPSO_numSegments_FullParam.m');
scriptText = fileread(scriptPath);
end
