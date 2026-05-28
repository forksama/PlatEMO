function tests = test_UAVPathPlanning_lookahead_margins
% Static checks for configurable lookahead handover margins.
tests = functiontests(localfunctions);
end

function testLookaheadMarginPropertiesExist(testCase)
sourceText = readUAVPathPlanningSource();

verifyNotEmpty(testCase, regexp(sourceText, ...
    'lookaheadHysteresisRange\s*;', 'once'));
verifyNotEmpty(testCase, regexp(sourceText, ...
    'lookaheadSafetyMargin\s*;', 'once'));
end

function testOptionalProblemParametersAreParsed(testCase)
sourceText = readUAVPathPlanningSource();

verifyNotEmpty(testCase, regexp(sourceText, ...
    'length\(params\)\s*>=\s*9[\s\S]*?lookaheadHysteresisRange\s*=\s*params\{9\}', 'once'));
verifyNotEmpty(testCase, regexp(sourceText, ...
    'length\(params\)\s*>=\s*10[\s\S]*?lookaheadSafetyMargin\s*=\s*params\{10\}', 'once'));
end

function testCurrentDefaultsArePreserved(testCase)
sourceText = readUAVPathPlanningSource();

verifyNotEmpty(testCase, regexp(sourceText, ...
    'lookaheadHysteresisRange\s*=\s*10\s*;', 'once'));
verifyNotEmpty(testCase, regexp(sourceText, ...
    'lookaheadSafetyMargin\s*=\s*4\s*;', 'once'));
end

function testLookaheadCaseUsesConfigurableMargins(testCase)
sourceText = readUAVPathPlanningSource();

verifyNotEmpty(testCase, regexp(sourceText, ...
    'case\s+2[\s\S]*?delta_hysteresis_range\s*=\s*obj\.lookaheadHysteresisRange', 'once'));
verifyNotEmpty(testCase, regexp(sourceText, ...
    'case\s+2[\s\S]*?condition2\s*=\s*currentSignal\s*<=\s*obj\.switchThreshold\s*\+\s*obj\.lookaheadSafetyMargin', 'once'));
end

function sourceText = readUAVPathPlanningSource()
testDir = fileparts(mfilename('fullpath'));
sourcePath = fullfile(fileparts(testDir), 'UAVPathPlanning.m');
sourceText = fileread(sourcePath);
end
