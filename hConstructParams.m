function testParamArray = hConstructParams(config)
% This defines the test parameter object to be used in the
% ClassSetupParameter properties of each test class
% Without arguments, this function creates a cell array of
% producer/device combos. Each item will represent one producer and a
% device that it discovered with imaqhwinfo
%
% Arguments for specific producers and devices can be specified:
% - Producers: string or string array of CTI parent directories
% - DeviceIDs: device ID or array of device IDs. Does NOT account for
%   different producers enumerating devices in different orders, nor
%   does it account for producers that may not detect all available
%   devices.
%
% testParamArray output argument is a cell array of structures where each
% structure is a specific producer/device configuration. If there are 3
% producers and 4 devices detected or specified (and all devices are
% discovered by all producers), then there would be 12 configuration
% structs in the output cell array. Cell array use is required by MATLAB
% unittest parameter syntax.

% Copyright 2024 The MathWorks, Inc.

arguments
    % If Name-Value pair "Producers" is specified, it must not be empty
    config.ProducerDirs {mustBeText,mustBeNonempty} = hGetAllProducers();
    % If Name-Value pair "DeviceIDs" is specified, it must not be
    % empty. A placeholder ("unspecified") is used to not trigger
    % mustBeNonempty when DeviceIDs is not specified.
    % config.DeviceIDs {mustBeNonempty} = "unspecified";
    config.DeviceIDs = [];
end

producers = config.ProducerDirs;
% Check that all Producer paths contain a .CTI file
ctiFileInds = ~cellfun(@(x) isempty(dir(fullfile(x,filesep,"*.cti"))), ...
    producers);
if any(~ctiFileInds)
    noCTIprods = producers(~ctiFileInds);
    disp("The following producer paths do not contain .CTI files and will " + ...
        "not be included in testing:" + newline + ...
        sprintf("  - %s \n", noCTIprods{:}))
end
producers = producers(ctiFileInds);
initialEnv = getenv("GENICAM_GENTL64_PATH");
testParamArray = {};

% Switch between specified producers and create a new struct
% combination for each available device
for k = 1:numel(producers)
    setenv("GENICAM_GENTL64_PATH", producers{k});
    imaqreset();
    devInfo = imaqhwinfo("gentl").DeviceIDs;
    % Use imaqhwinfo output when device IDs are unspecified
    % if isequal(devices, "unspecified")
    if isempty(config.DeviceIDs)
        devices = devInfo;
    else
        devices = config.DeviceIDs;
    end
    if ~isempty(devInfo)
        % Get all devices detected by producer. The length of
        % prodDevices will be equal to the number of device IDs
        % found in devInfo
        prodDevices = hGetAllDevices();
        % hGetAllDevices gives a cell array which is necessary for
        % in-test parameterization, but a regular struct array is
        % better for the purpose of this function.
        prodDevices = [prodDevices{:}];
        % By default all devices are to be used. If device IDs are
        % given as an argument, only use those. Since all producers
        % should detect all hardware, the same device IDs will be
        % used for all producers. If a producer does list a
        % specific ID, it will output the skipped configuration to
        % the log file.
        finalProdDevices = {};
        if ~iscell(devices) && isnumeric(devices)
            % The operations below work better if devices is a cell
            % array like devInfo from imaqhwinfo
            devices = num2cell(devices);
        end
        for n=1:numel(devices)
            if ~ismember(devices{n},[devInfo{:}])
                % Specified device not found in hw info. Remove it
                % from prodDevices and log event
                disp("Specified DeviceID " + num2str(devices{n}) + " not " + ...
                    "found for producer at:" + newline + producers{k})
                continue;
            else
                % Add specified device struct to final output array
                % The output of find should only give 1 index,
                % otherwise this will error.
                devIdx = [prodDevices.IMAQHWID]==devices{n};
                finalProdDevices = [finalProdDevices prodDevices(devIdx)];
            end
        end
        % Add Producer field to all structs in testParamArray
        testParamArray = [testParamArray cellfun(@(f) ...
            setfield(f, "Producer", producers{k}), ...
            finalProdDevices, "UniformOutput", false)];
    else
        disp("No devices found using producer listed at " + producers{k})
    end
end

% Reset environment variable to its initial state
setenv("GENICAM_GENTL64_PATH", initialEnv);
imaqreset();
end