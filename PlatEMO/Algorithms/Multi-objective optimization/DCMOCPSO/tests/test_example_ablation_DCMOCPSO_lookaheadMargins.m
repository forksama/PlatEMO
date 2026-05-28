function tests = test_example_ablation_DCMOCPSO_lookaheadMargins
% Static checks for one-factor lookahead margin ablations.
tests = functiontests(localfunctions);
end

function testUsesFiveValuesForEachOneFactorSweep(testCase)
scriptText = readLookaheadMarginsScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'lookaheadHysteresisRangeList\s*=\s*\[0,\s*5,\s*10,\s*15,\s*20\]\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'lookaheadSafetyMarginList\s*=\s*\[0,\s*2,\s*4,\s*6,\s*8\]\s*;', 'once'));
end

function testDoesNotUseCartesianProduct(testCase)
scriptText = readLookaheadMarginsScript();

verifyEmpty(testCase, regexp(scriptText, ...
    'numGroups\s*=\s*numHysteresis\s*\*\s*numSafety', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'for\s+\w+\s*=\s*1:numHysteresis[\s\S]*?for\s+\w+\s*=\s*1:numSafety', 'once'));
end

function testRunsNamedOneFactorExperiments(testCase)
scriptText = readLookaheadMarginsScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    '''LookaheadHysteresisOneSegSweep''', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    '''LookaheadSafetyOneSegSweep''', 'once'));
end

function testUsesOneSegAlgorithmSettingsOnly(testCase)
scriptText = readLookaheadMarginsScript();

verifyNotEmpty(testCase, regexp(scriptText, ...
    'n\s*=\s*10\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'param_OneSeg\s*=\s*\{1,\s*2,\s*0\.5,\s*0\.3,\s*false,\s*false,\s*false\}\s*;', 'once'));
verifyNotEmpty(testCase, regexp(scriptText, ...
    'commonConfig\.param_OneSeg', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'useDynamicGrouping\s*=', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'useDynamicMutation\s*=', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'useEk\s*=', 'once'));
verifyEmpty(testCase, regexp(scriptText, ...
    'uniformPointMultiplier\s*=', 'once'));
end

function scriptText = readLookaheadMarginsScript()
scriptDir = fileparts(fileparts(mfilename('fullpath')));
scriptPath = fullfile(scriptDir, 'example_ablation_DCMOCPSO_lookaheadMargins.m');
scriptText = fileread(scriptPath);
end
