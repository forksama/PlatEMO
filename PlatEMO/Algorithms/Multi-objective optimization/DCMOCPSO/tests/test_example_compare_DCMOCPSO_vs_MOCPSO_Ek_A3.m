function tests = test_example_compare_DCMOCPSO_vs_MOCPSO_Ek_A3
% Static checks for the A3 group in example_compare_DCMOCPSO_vs_MOCPSO_Ek.
tests = functiontests(localfunctions);
end

function testA3ProblemParametersReuseBaseExceptSwitchMethod(testCase)
scriptText = readComparisonScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_A3\s*=\s*problemParameter_Base\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'problemParameter_A3\{7\}\s*=\s*3\s*;', 'once'));
end

function testA3RunUsesOneSegAlgorithmParameters(testCase)
scriptText = readComparisonScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    '''OneSeg_A3''[\s\S]*?runOne_DCMOCPSO\(N,\s*maxFE_OneSeg,\s*problemParameter_A3,\s*param_OneSeg\)', ...
    'once'));
end

function testA3IsIncludedInSummaryAndPlots(testCase)
scriptText = readComparisonScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'meanHV_OneSeg_A3\s*=\s*mean\(hvLast_OneSeg_A3\(validIdx_OneSeg_A3\)\)', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'categorical\(\{''OneSeg'',''OneSeg\\_A3'',''OneSeg\\_Lookahead'',''Seg\\_Lookahead'',''Full\\_Lookahead''\}\)', ...
    'once'));
end

function scriptText = readComparisonScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_compare_DCMOCPSO_vs_MOCPSO_Ek.m');
scriptText = fileread(scriptPath);
end
