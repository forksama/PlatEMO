function tests = test_UAVPathPlanning_altitude_range
% Static checks for optional preset altitude and altitude bounds.
tests = functiontests(localfunctions);
end

function testOptionalAltitudeParametersAreParsed(testCase)
sourceText = readUAVPathPlanningSource();

verifyNotEmpty(testCase, regexp(sourceText, ...
    'length\(params\)\s*>=\s*11[\s\S]*?presetAltitude\s*=\s*params\{11\}', 'once'));
verifyNotEmpty(testCase, regexp(sourceText, ...
    'length\(params\)\s*>=\s*12[\s\S]*?altitudeBounds\s*=\s*params\{12\}', 'once'));
end

function testEmptyLookaheadMarginParametersUseDefaults(testCase)
sourceText = readUAVPathPlanningSource();

verifyNotEmpty(testCase, regexp(sourceText, ...
    'length\(params\)\s*>=\s*9\s*&&\s*~isempty\(params\{9\}\)[\s\S]*?lookaheadHysteresisRange\s*=\s*params\{9\}', 'once'));
verifyNotEmpty(testCase, regexp(sourceText, ...
    'length\(params\)\s*>=\s*10\s*&&\s*~isempty\(params\{10\}\)[\s\S]*?lookaheadSafetyMargin\s*=\s*params\{10\}', 'once'));
end

function testPresetPathAltitudeCanBeOverridden(testCase)
sourceText = readUAVPathPlanningSource();

verifyNotEmpty(testCase, regexp(sourceText, ...
    'if\s+~isnan\(presetAltitude\)[\s\S]*?obj\.presetPath\(:,\s*3\)\s*=\s*presetAltitude', 'once'));
end

function testAltitudeBoundsReplaceDefaultZBounds(testCase)
sourceText = readUAVPathPlanningSource();

verifyNotEmpty(testCase, regexp(sourceText, ...
    'if\s+isempty\(altitudeBounds\)[\s\S]*?zLower\s*=\s*30[\s\S]*?zUpper\s*=\s*70', 'once'));
verifyNotEmpty(testCase, regexp(sourceText, ...
    'else[\s\S]*?zLower\s*=\s*altitudeBounds\(1\)[\s\S]*?zUpper\s*=\s*altitudeBounds\(2\)', 'once'));
verifyNotEmpty(testCase, regexp(sourceText, ...
    'obj\.lower\(i\)\s*=\s*zLower', 'once'));
verifyNotEmpty(testCase, regexp(sourceText, ...
    'obj\.upper\(i\)\s*=\s*zUpper', 'once'));
end

function sourceText = readUAVPathPlanningSource()
testDir = fileparts(mfilename('fullpath'));
sourcePath = fullfile(fileparts(testDir), 'UAVPathPlanning.m');
sourceText = fileread(sourcePath);
end
