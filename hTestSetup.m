function testparams = hTestSetup(testparams, devConfig, prodConfig)
% Initialize the testparams structure based on an input device and producer
% configuration. The testparams structure will be used throughout all test
% points and provides information about the current configuration.
% Prepare the test environment by setting up hardware specification files
% and setting GENICAM_GENTL64_PATH

% Copyright 2024 The MathWorks, Inc.

% Determine test platform
testparams.skipcleanup = false;

arch = computer;
if ispc
    if arch == "PCWIN64"
        testparams.arch = "win64";
    else
        testparams.arch = "win32";
    end
    testparams.adaptorExtension = "dll";
else
    testparams.arch = string(lower(arch));
    if any(testparams.arch == ["maci64", "maca64"])
        error("Mac platforms are not supported");
    else
        % Linux Platform
        testparams.adaptorExtension = "so";
    end
end

% Delete possible timer objects remaining in the system
delete(timerfind);

% Hardware specification file directory. Create it if it does not already
% exist in current path
testparams.hwSpecFileDir = fullfile(pwd, "hwspec");
if ~isfolder("hwspec")
    mkdir("hwspec")
end

% Bring current device configuration into test parameters
testparams.DEVICENAME = devConfig.DEVICENAME;
testparams.IMAQHWID = devConfig.IMAQHWID;
testparams.SUPPORTEDFORMATS = devConfig.SUPPORTEDFORMATS;
testparams.CurrentFormat = devConfig.CurrentFormat;
testparams.hwSpecFileName = devConfig.hwSpecFileName;

% Reconfigure environment variables to reflect producer-under-test
% Get current value of GenTL variable, save for cleanup later
imaqreset();
testparams.initialGentlEnv = getenv("GENICAM_GENTL64_PATH");
testparams.currGentlEnv = prodConfig;
setenv("GENICAM_GENTL64_PATH", testparams.currGentlEnv);
imaqreset();

% Check if hw spec files already exist for current hardware, otherwise
% create new ones
% hardware spec files follow the naming convention:
%     """ gentl_<DeviceName>_<DeviceID>.m """
% % Any non-word character in DeviceName is replaced with an underscore
testparams = hCreateSpecs(testparams);

% Save current path to revert to after tests
testparams.OriginalPath = path;

% Save current adaptor setup to revert to after tests
testparams.originalRegAdaptors = imaqregister;
% If the demo adaptor was registered, unregister it.
for k = 1:numel(testparams.originalRegAdaptors)
    p = strfind(testparams.originalRegAdaptors{k}, "mwdemoimaq." + testparams.adaptorExtension);
    if ~isempty(p)
        imaqregister(testparams.originalRegAdaptors{k}, "unregister");
        break
    end
end

% Put IMAQ toolbox into default state (unload all adaptors, delete existing
% videoinput objects)
imaqreset();

% Prevent imaqmex from limiting the amount of frame memory used since Linux
% does not always have a lot available
imaqmex('feature', '-limitphysicalmemoryusage', false);

% Make sure that device ID passed from the DUT file (iatDUTfile.m)
% corresponds to the specified device
% This assumes that the enumeration order of devices has not changed
% between test runs (e.g. from users disconnecting/connected hardware), 
% which cause the DeviceIDs recorded in testparams and hw spec files to
% become invalid, requiring regeneration.
try
    hwinfo = imaqhwinfo("gentl");
catch ME
    sprintf("Adaptor ""%s"" does not seem to be installed:\n %s", ...
        testparams.IMAQHWTYPE{:}, ME.message);
    rethrow(ME);
end
% Make sure that the device has the proper device ID. Assuming that there
% is not more than one of the same device attached to host, pick the device 
% ID of the first match of the device name
VALID_DEVICE_ID = false;
for k = 1:numel(hwinfo.DeviceInfo)
    if (strcmpi(hwinfo.DeviceInfo(k).DeviceName, testparams.DEVICENAME))
        testparams.IMAQHWID = hwinfo.DeviceInfo(k).DeviceID;
        VALID_DEVICE_ID = true;
    end
end
if (~VALID_DEVICE_ID)
    error("imaq:test:InvalidDevID", "Invalid Device ID ...\n")
end

% Create a temporary directory and copy the hardware specification file to
% the temporary directory using a shorter filename. Save the function
% handle to the shorter filename.
% Create a unique temporary directory for writing into.  Append the process
% ID of this copy of MATLAB to ensure that tempname is really unique when
% running more than one copy of MATLAB on the same machine
testparams.imaqTempDir = [tempname '_' num2str(feature("getpid"))];
[dirCreateSuccess, dirCreateMessage] = mkdir(testparams.imaqTempDir);
if ~dirCreateSuccess
    error("\nUnable to create IMAQ temp directory <%s>:\n<%s>", ...
        testparams.imaqTempDir, dirCreateMessage);
end
testparams.hwSpecTempName = 'DUT_HWSPECFILE';

if ~exist(testparams.imaqTempDir, "dir")
    dirMsg = sprintf("The target directory <%s> does not exist.\n", testparams.imaqTempDir);
    error("\nUnable to write the hardware specification file <%s> ...\n%s", ...
        testparams.hwSpecFileName, dirMsg)
end

% Clear any previously loaded temporary hardware specification function
loadedFcns = inmem;
if ismember(testparams.hwSpecTempName, loadedFcns)
    clear(testparams.hwSpecTempName)
    rehash
end

currentDir = pwd;
cd(testparams.imaqTempDir)

% Check existence of hardware spec file
hardwareSpecFile = fullfile(testparams.hwSpecFileDir, ...
    testparams.hwSpecFileName) + ".m";
if ~(exist(hardwareSpecFile, "file") == 2)
    error("The specified hardware spec file " + hardwareSpecFile + ...
        " does not exist");
end

% Copy hardware specification file to the temp directory
[copySuccess, copyMessage] = copyfile(hardwareSpecFile, ...
    testparams.hwSpecTempName + ".m", "f");
if copySuccess
    rehash % rehash path to include the directory just created
    % Create handle to hardware specification file function
    testparams.hwSpecFunction = str2func(testparams.hwSpecTempName);
else
    error(newline + "Unable to write hardware spec file " + ...
        hardwareSpecFile + " to temp directory." + newline + copyMessage);
end
cd(currentDir)

% Refresh  path to acknowledge recently created directory and file
rehash

% Number of times to try something that must be tried repeatedly.
testparams.testIterations = 10;

% General strings and definitions
testparams.getdataMetadataFieldnames = ["AbsTime", "FrameNumber", "RelativeFrame", "TriggerIndex"];
testparams.getdataMetadataFieldnames = sort(testparams.getdataMetadataFieldnames);

% Are there test points that need to be filtered? Collect all test points
% that need to be filtered.
stackFiles = dbstack;
callingFunctions = cell(1, numel(stackFiles));
for k = 1:numel(stackFiles)
    callingFunctions{k} = stackFiles(k).file;
end