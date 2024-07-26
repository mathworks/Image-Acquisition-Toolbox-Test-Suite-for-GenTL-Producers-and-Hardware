function producerDirList = hGetAllProducers()
% Get list of all GenTL producers directories currently stored in 
% GENICAM_GENTL64_PATH environment variable. This function will not search
% the system for producer locations or .CTI files, so please make sure all 
% desired producer paths are listed in the environment variable at the 
% start of the MATLAB session. A producer directory containing multiple 
% .CTI files will only appear in the producerDirList output once.

% Copyright 2024 The MathWorks, Inc.

hInternalHook(1)
gentlPaths = getenv("GENICAM_GENTL64_PATH");
if isempty(gentlPaths)
    % If no producers are found in GENICAM_GENTL64_PATH, throw an error
    error("No producer paths found in GENICAM_GENTL64_PATH environment variable.")
end
if gentlPaths(end) == pathsep
    % Remove trailing path separator if found
    gentlPaths = gentlPaths(1:end-1);
end
producers = split(gentlPaths, pathsep)';
producerDirList = cell(1, numel(producers));
idx = 1;
for k=1:numel(producers)
    if ~isempty(producers{k})
        ctiFile = dir(fullfile(producers{k}, filesep, "*.cti"));
        if ~isempty(ctiFile)
            % Producer found at fullfile(producers{k}, filesep, ctiFile.name)
            if producers{k}(end) == filesep
                % Remove trailing file separator if found
                producers{k} = producers{k}(1:end-1);
            end
            producerDirList{idx} = producers{k};
            idx = idx+1;
        else
            % No producers found in producer path
            disp("No .CTI file found in " + producers{k} + newline + ...
                "Not including in producerList.")
        end
    else
        disp("Producer entry empty and will be not included in list");
    end
end
% Remove any empty cells from preallocation
producerDirList = producerDirList(~cellfun("isempty", producerDirList));
end