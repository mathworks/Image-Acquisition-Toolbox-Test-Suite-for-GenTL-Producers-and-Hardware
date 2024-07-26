function [testResults, logfile] = runGenTLTestSuite(tests, options)
% RUNGENTLTESTSUITE Wrapper function for runtests to run tests in the Image
% Acquisition Toolbox Test Suite for GenTL Producers and Hardware
%
% TESTRESULTS = runGenTLTestSuite() runs all tests on all available
% producers and hardware
%
% TESTRESULTS = runGenTLTestSuite(TESTS) runs the specified tests on all
% available producers and hardware. This can be specified as a cell array
% of test file names with or without procedure names
%
% TESTRESULTS = runGenTLTestSuite("ProducerDirs", PRODUCERDIRS) runs all
% available tests on the specified producers using all available
% hardware. PRODUCERDIRS is specified as a string array, character vector,
% or cell array of character vectors of absolute paths to directories
% containing .CTI files on the machine. Usually these will be among entries
% contained in the GENICAM_GENTL64_PATH environment variable on the machine
% being used, but any path can be used as long as it contains a .CTI file.
%
% TESTRESULTS = runGenTLTestSuite("LogDirectory", LOGDIR) specifies where
% the log file is to be saved as a relative or absolute path. If not
% specified, the log file will be saved to tempdir. The name of the file is
% always "logXXXXXXXXXXXXXX.txt" where the X values are replaced by a
% datetime string of the form MMddyyyhhmmss
%
% Examples:
%
% % Run a variety of tests with individual calls
% >> result = runGenTLTestSuite("tVideoinput") % run all tVideoinput test points
% >> result = runGenTLTestSuite("tAcquisition/verifySnapshot") % run only verifySnapshot from tAcquisition
%
% % Run all of the above in one function call
% >> result = runGenTLTestSuite({'tVideoinput', 'tAcquisition/verifySnapshot'})
%
% % Run tAcquisition.m using producer paths stored in cell array "p"
% >> result = runGenTLTestSuite("tAcquisition", "ProducerDirs", p)
%

% Copyright 2024 The MathWorks, Inc.

arguments
    tests {mustBeText} = "."
    options.ProducerDirs {mustBeText} = {}
    options.DeviceIDs {mustBeNumeric} = [] % TODO: Remove arg validation
    options.Formats {mustBeText} = {}
    options.LogDirectory {mustBeFolder} = tempdir
end

import matlab.unittest.TestSuite
import matlab.unittest.parameters.Parameter

% Image Acquisition Toolbox Support Package for GenICam Interface must be
% installed in order to run this test suite.
spkgs = matlabshared.supportpkg.getInstalled;
spkgName = "Image Acquisition Toolbox Support Package for GenICam Interface";
if isempty(spkgs) || ~any(contains({spkgs.Name}, spkgName))
    error("Image Acquisition Toolbox Support Package for GenICam Interface " + ...
        "not found" + newline + "Please install the the Support Package to " + ...
        "use this test suite");
end

% Set up log file
logfile = fullfile(options.LogDirectory, ...
    "log" + string(datetime("now", "Format", "MMddyyyyhhmmss")) + ".txt");
diary(logfile);

% If no name-value input arguments are specified (other than LogDirectory),
% then just use runtests! Parameter injection is not required.
if isempty(options.ProducerDirs) && isempty(options.DeviceIDs) && isempty(options.Formats)
    testResults = runtests(tests);
    diary off;
    fprintf("Log file is located in: " + newline + ...
        "<a href=""matlab: matlab.desktop.editor.openDocument('%s');"">%s</a>\n", ...
        logfile, logfile);
    return
end

% The "tests" input arg must be broken down into the actual test points to
% be run, stored as struct array "testFiles" with a length equal to the
% number of test files being used. Each element in the array will have the
% following fields:
% 1. fileName = name of test file
% 2. procedures = cell array of specific test point names to be run
testFiles = hCreateTestProcedures(tests);

% Some name-value input arguments may be ignored by a few specific test
% points. Throw a warning if this is going to happen.
if any(contains({testFiles.fileName}, "tDevices", "IgnoreCase", true)) && ...
        (~isempty(options.ProducerDirs) || ~isempty(options.DeviceIDs))
    % tDevices does not take any Name-Value pairs into account
    warning("Test points in tDevices always use default options for " + ...
        "ProducerDir and DeviceID parameters. User-supplied values for " + ...
        "these arguments will be ignored for tDevices.")
end
if any(contains({testFiles.fileName}, "tProducer", "IgnoreCase", true)) && ...
        ~isempty(options.DeviceIDs)
    % tProducer does not take DeviceIDs Name-Value pair into account
    warning("Test points in tProducer always use default options for the " + ...
        "DeviceID parameter. User-supplied values for this argument will " + ...
        "be ignored for tProducer.")
end
if ~any(contains({testFiles.fileName}, "tFormats", "IgnoreCase", true)) && ...
        ~isempty(options.Formats)
    % Formats Name-Value pair will be ignored when supplied if tFormats is
    % part of the list of tests to be run.
    warning("Values specified in the Formats argument will be ignored as " + ...
        "tFormats is not among the tests to be run.")
end

% When input args other than Producers are specified, set ProducerDirs to the
% default value: a cell array of every value stored in GENICAM_GENTL64_PATH
if isempty(options.ProducerDirs)
    options.ProducerDirs = hGetAllProducers();
else
    % Make sure producers are in a cell array of character vectors
    options.ProducerDirs = cellstr(options.ProducerDirs);
end

% If runGenTLTestSuite was run with any combination of Producer, DeviceID, or
% Format input arguments, then those inputs must be parsed and organizaed
% into a paramter array "params". The loop below will do the following:
% 1. Figure out which Name-Value pairs were specified
% 2. Allocate a matlab.unittest.parameters.Parameter array
% 3. Add parameters to "params" array using user-specified values
optNames = fieldnames(options);
populatedFields = optNames(~structfun(@isempty, options));
params = [];
formatParam = [];
formatSpecified = false;
for n=1:length(populatedFields)
    switch populatedFields{n}
        case "Formats"
            % Create parameter for formats tests
            formatSpecified = true;
            options.Formats = cellstr(options.Formats);
            formatParam = Parameter.fromData("TestFormat", options.Formats);
        case "LogDirectory"
            % Don't do anything, this has already been handled.
            continue
        case {"ProducerDirs", "DeviceIDs"}
            % Create a DeviceConfig struct array from Producer and Device
            % values (assuming at least one was specified) using
            % hConstructParams. Then create a Parameter entry with it.
            % This only needs to be created once, so if both Producers
            % and DeviceIDs are specified by the user, skip whichever case
            % comes second (usually DeviceIDs)
            hasDeviceConfigStruct = false;
            if ~isempty(params)
                % Determine if the existing parameter array contains the
                % DeviceConfig parameter
                paramValues = {params.Value};
                hasDeviceConfigStruct = any(cellfun(@isstruct, paramValues));
            end
            if hasDeviceConfigStruct
                % hConstructParams has already been run and created the
                % desired configuration. Skip this iteration.
                continue;
            else
                devConf = hConstructParams("ProducerDirs", options.ProducerDirs, ...
                    "DeviceIDs", options.DeviceIDs);
                param = Parameter.fromData("DeviceConfig", devConf);
                params = [params param];
            end
        otherwise
            error("Specified Name-Value pair not supported")
    end
end

% Create a TestSuite object for each test file then run the test points
allParamsUsed = [];
result = [];
for k=1:length(testFiles)
    % Get all test points to be run per test file. These will comprise the
    % "ProcedureName" arg to TestSuite.fromClass
    % If tFormats is to be run AND a format list was specified, add in the
    % formats parameter created earlier
    if testFiles(k).fileName=="tFormats" && formatSpecified
        % This test takes producers and device IDs as parameters like
        % others, but it also takes an additional formats parameter.
        updatedParams = [params formatParam];
    elseif testFiles(k).fileName=="tProducer"
        % This test takes only producers as parameters, and ignores other
        % parameters like device IDs and formats.
        updatedParams = Parameter.fromData("Producer", options.ProducerDirs);
    else
        % All other tests can take both producers and device IDs as params
        updatedParams = params;
    end
    allParamsUsed = [allParamsUsed updatedParams];
    suite = TestSuite.fromClass(meta.class.fromName(testFiles(k).fileName), ...
        "ExternalParameters", updatedParams, ...
        "ProcedureName", testFiles(k).procedures);
    r = suite.run;
    result = [result r];
end
% Remove repeats from allParamsUsed
[~,idxs,~] = unique({allParamsUsed.Name});
allParamsUsed = allParamsUsed(idxs);

% Display test result table
home;
[testResults, testTable] = hProcessTestResult(result, allParamsUsed);

% Wrap up log file
diary off;
fprintf("Log file is located in: " + newline + ...
    "<a href=""matlab: matlab.desktop.editor.openDocument('%s');"">%s</a>\n", ...
    logfile, logfile);
end

function testStruct = hCreateTestProcedures(testArray)
% testArray is the cell array of char vectors input to runGenTLTestSuite.
% Each element must either be a test class name or a test class name
% appended with a procedure name like so:
%   <class name>/<procedure name>
% So to run verifySnapshot from tAcquisition, the vector would be:
%   tAcquisition/verifySnapshot
% EXAMPLE:
% testArray = {'tAcquisition', ...
%              'tDevices/verifyDeviceSequence', ...
%              'tFormats', ...
%              'tDevices/verifyAllDevices'}
% The above test array would run all test points in tAcquisition, all
% test points in tFormats, and verifyDeviceSequence and
% verifyAllDevices from tDevices.
%
% testStruct output is a structure with fields fileName and procedures
% with a length equal to the number of distinct test files included in
% the testArray input.

% defaultArray = struct("fileName",{},"procedures",{});
defaultArray = struct("fileName",[],"procedures",[]);
availTests = ["tAcquisition", "tDevices", "tFormats", "tProducer", "tVideoinput"];
[defaultArray(1:length(availTests)).fileName] = availTests{:};
defaultArray(1).procedures = ["verifyAcquisition", "verifySnapshot", "verifyPreview", "verifyTestPattern"];
defaultArray(2).procedures = ["verifyDeviceSequence", "verifyAllDevices"];
defaultArray(3).procedures = ["verifyFormat"];
defaultArray(4).procedures = ["verifyProducerListed", "verifyVendorDriver"];
defaultArray(5).procedures = ["verifyVideoinputObj", "verifySelectedSource"];
% If no tests were specified, run all of them
if testArray == "."
    testStruct = defaultArray;
    return
end
% The testArray input is already text at this point due to
% runGenTLTestSuite's arguments block requiring input as a:
%   - Character vector,
%   - String array, or
%   - Cell array of character vectors
% However, if it is a char vector or a string array then it needs to be
% turned into a cell array before processing the testStruct
if class(testArray) ~= "cell"
    testArray = cellstr(testArray);
end

testStruct = struct("fileName",[],"procedures",[]);
testStructIdx = 1;
% Iterate through all possible test file names. When instances of that
% file are found in the input array, add its name to the output array
% as well as whichever individual test points may have been specified
for k=1:length(availTests)
    % Get all instances of the current availTests from the input array
    testIdxs = contains(testArray, availTests{k}, "IgnoreCase", true);
    if any(testIdxs)
        testStruct(testStructIdx).fileName = availTests{k};
        % If individual test points are specified, add only those to
        % the procedures field. Otherwise, add all of them.
        if any(contains(testArray(testIdxs), "/verify"))
            testStruct(testStructIdx).procedures = ...
                erase(testArray(testIdxs),availTests{k} + "/");
        else
            % Extract default procedures value for given test file name
            fileIdx = string({defaultArray.fileName}) == availTests{k};
            testStruct(testStructIdx).procedures = ...
                defaultArray(fileIdx).procedures;
        end
        testStructIdx = testStructIdx + 1;
    end
end
end

function [results, resultTable] = hProcessTestResult(testresult, params)
% testresult is a TestResult array containing information about the test
% run that just occurred
% params is the parameter array used in the test run
% Parse the testresults into a readable table of pass, fail runs per
% test per parameter. Return the testresults that were input (results), as
% well as a table of the failed and incomplete testpoints (resultTable)
results = testresult;

% Create failure+incomplete table
failAndIncompResults = testresult(logical( ...
    [testresult.Failed] + [testresult.Incomplete]));
% If there were no failures, then there's no need to process anything.
if isempty(failAndIncompResults)
    disp(newline + "No failures." + newline);
    resultTable = table([],[],'VariableNames', {'Incomplete','Failed'});
    return
end
% Otherwise, begin processing testresults.
testNames = {failAndIncompResults.Name};
paramNames = {params.Name};
% Struct entries are DeviceConfig parameters
deviceConfigIdxs = contains(paramNames, "struct") & cellfun(@(x) length(x)<=8, paramNames);
% All other entries are either producer or format parameters
producerIdxs = ~deviceConfigIdxs;
paramNames(deviceConfigIdxs) = strcat('[DeviceConfig=', ...
    paramNames(deviceConfigIdxs), '#ext]');
paramNames(producerIdxs) = strcat('[Producer=', ...
    paramNames(producerIdxs), '#ext]');

for k=1:length(paramNames)
    paramIdxs = contains(testNames, paramNames{k});
    namesToReplace = testNames(paramIdxs);
    if isstruct(params(k).Value)
        % Param was a full device configuration
        replaceStr = newline + "Device ID=" + string(params(k).Value.IMAQHWID) + ...
            newline + "Producer Directory=..." + newline + params(k).Value.Producer;
    else
        % Param was just a producer or format
        replaceStr = newline + "Producer Directory=" + newline + params(k).Value;
    end
    testNames(paramIdxs) = erase(namesToReplace, paramNames{k});
    testNames(paramIdxs) = cellstr(strcat(testNames(paramIdxs), replaceStr));

end

% Save results to a table
resultTable = table([failAndIncompResults.Incomplete]', [failAndIncompResults.Failed]', ...
    'VariableNames', {'Incomplete','Failed'}, 'RowNames', testNames');

% Begin test result display
disp("Failure Summary" + newline + newline + "Name" + repmat(' ', 1, 60) + ...
    "Failed  Incomplete" + newline + repmat('=', 1, 82))

for m=1:length(testNames)
    strLines = split(testNames{m}, newline);
    % Format the first line of each recorded test procedure to include an
    % X for the test result (Failed or Incomplete)
    strLines{1}(end+1:82) = " ";
    if failAndIncompResults(m).Failed
        strLines{1}(68) = "X";
    end
    if failAndIncompResults(m).Incomplete
        strLines{1}(78) = "X";
    end
    % Wrap the Producer line of the test result if it is too long
    if length(strLines) > 1 && length(strLines{end}) > 61
        strLines{end}(58:end) = '';
        strLines{end} = [strLines{end} '...'];
    end
    dispString = strjoin(strLines, newline);
    dispString = [dispString, newline, repmat('-',1,82)];
    disp(dispString);
end
end