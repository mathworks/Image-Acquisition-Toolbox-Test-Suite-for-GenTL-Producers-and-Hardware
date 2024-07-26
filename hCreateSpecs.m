function testparams = hCreateSpecs(testparams)
% For a given set a test parameters, check if a hardware specification
% files has been created yet. If not, create a hw spec file cataloging
% all the expected formats and device/source properties.
%
% This function assumes that the hardware is already in the state the
% user intends it to be tested in; that is if the device properties are
% modified outside the test environment, the hw spec file will NOT be
% automatically regenerated unless it is deleted manually.

% Copyright 2024 The MathWorks, Inc.

testparams.hwSpecFilePath = fullfile(pwd, "hwspec", testparams.hwSpecFileName + ".m");

if exist(fullfile(pwd,"hwspec", testparams.hwSpecFileName +".m"), "file")
    % Case where file already exists
    if exist("testparams", "var")
        % Subcase where existing spec will be used
        disp("Existing hardware spec file will be used")
        return
    else
        % Subcase where spec exists and user wants to replace it
        % Delete existing spec before creating the new one
        delete(testparams.hwSpecFilePath);
        [testparams, writeSuccess] = writeSpecFile(testparams);
    end
else
    % No file exists. Create a new one
    [testparams, writeSuccess] = writeSpecFile(testparams);
end

if writeSuccess
    disp("Hardware Spec file written to: " + newline + ...
        testparams.hwSpecFilePath);
else
    error("Hardware Spec file was not generated successfully in" + ...
        newline + testparams.hwSpecFilesPath + newline + ...
        "Please verify write access to hwspec directory." + ...
        newline + "Exiting test suite.");
end
end

function [testparams, writeSuccess] = writeSpecFile(testparams)
% Create a videoinput and source object
vid = videoinput("gentl", testparams.IMAQHWID);
src = getselectedsource(vid);

% Get all properties from both objects
allParentProperties = fieldnames(get(vid));
allSourceProperties = fieldnames(get(src));

% Both vid and src have "Tag" and "Type"; associate these with vid in
% the property struct
allSourceProperties = setdiff(allSourceProperties, ["Tag", "Type"]);

% Get property fieldnames Type, Constraint, ConstraintValue,
% DefaultValue, ReadOnly, and DeviceSpecific
propFields = fieldnames(propinfo(vid, allParentProperties{1}));

% Create readable struct
devPropSpec.propFields = propFields;
devPropSpec.returnType = 'returnType';
devPropSpec.propStructName = 'propertyStruct';
devPropSpec.runtimeDefinedProps = {...
    'Name'...
    'NumberOfBands'...
    'Parent'...
    'Selected'...
    'ROIPosition'...
    'SelectedSourceName'...
    'Source'...
    'SourceName'...
    'VideoFormat'...
    'VideoResolution'...
    };

% Open a new file to write spec
fid = fopen(testparams.hwSpecFilePath, 'wt');
if (fid == -1)
    error(['Unable to open file' testparams.hwSpecFileName '.m for writing']);
end
writeSuccess = true;
try
    % Write spec header
    testparams = writeSpecHeader(testparams, devPropSpec, fid);

    % Write supported format list
    testparams = writeSpecFormats(testparams, devPropSpec, fid);

    % Write property struct for parent (videoinput) object
    devPropSpec.propNames = allParentProperties;
    writeSpecProps(testparams, devPropSpec, vid, fid);

    % Write property struct for child (source) object
    devPropSpec.propNames = allSourceProperties;
    writeSpecProps(testparams, devPropSpec, src, fid, numel(allParentProperties));
catch ME
    writeSuccess = false;
    error("Failed to write file " + testparams.hwSpecFileName + newline + ME.message)
end

% Close the spec file
if (fclose(fid) == -1)
    writeSuccess = false;
end
% Cleanup
delete(vid);
end

function testparams = writeSpecHeader(testparams, devPropSpec, fid)
% Write spec file's header
specHeader = {...
    ['function ' devPropSpec.propStructName ' = ', ...
    testparams.hwSpecFileName, '(' devPropSpec.returnType ')'], ...
    '%' ...
    ['% ', upper(testparams.hwSpecFileName)], ...
    ['% - GenTL Hardware Specification for <', testparams.DEVICENAME, '>'], ...
    '%' ...
    ['% Default Video Format: ', testparams.CurrentFormat], ...
    '%' ...
    ['% DESCRIPTION: ', testparams.hwSpecFileName, '()'], ...
    '% Creates a hw spec structure for the device under test.' ...
    '%' ...
    '% Outputs:' ...
    ['% ' devPropSpec.propStructName ': returns'] ...
    '%    - a property structure, if no input argument, or input is ''property''  ' ...
    '%    - a cell array of supported formats, if input argument is ''formats''  ' ...
    '%' ...
    '% Examples: ' ...
    '%' ...
    ['%  1. propertyStruct = ', testparams.hwSpecFileName, '();'] ...
    '%' ...
    ['%  2. supportedFormats = ', testparams.hwSpecFileName, '(''formats'');'] ...
    '%' ...
    ['%  3. propertyStruct = ', testparams.hwSpecFileName, '(''property'');'] ...
    '%' ...
    '%' ...
    ['%   Created on:  ', char(datetime('now'))], ...
    };
fprintf(fid, '%s\n', specHeader{:});
fprintf(fid, '\n%s\n', '% Basic error checking');
fprintf(fid, '%s\n\n', 'narginchk(0, 1);');
fprintf(fid, '\n\n%s\n%s\n', ...
    '% Check the return type to return either a property structure, ', ...
    '% or a list of supported formats');
tabOne = sprintf('\t');
inpArgSpec = {...
    'if nargin == 0'...
    [tabOne devPropSpec.returnType ' = ''property'';'] ...
    ['elseif isempty(intersect(lower(' devPropSpec.returnType ...
    '), {''property'' ''formats''}))'] ...
    [tabOne 'error(''Invalid input specified ...'');'] ...
    'end' ...
    };
fprintf(fid, '%s\n', inpArgSpec{:});
end

function testparams = writeSpecFormats(testparams, devPropSpec, fid)
% Write spec file's supported formats
quote = '''';
sepLine = '%==========================================================';
fprintf(fid, '\n\n%s', sepLine);
fprintf(fid, '\n%%\t\t\t\t%s\n', 'DEVICE SUPPORTED FORMAT');
fprintf(fid, '%s\n\n', sepLine);

fprintf(fid, '%s\n', ['if strcmpi(' devPropSpec.returnType ', ''formats'')']);
fprintf(fid, '\t%s\n', [devPropSpec.propStructName ' = { ...']);
for k = 1:numel(testparams.SUPPORTEDFORMATS)
    fprintf(fid, '\t\t%s\n', [quote, testparams.SUPPORTEDFORMATS{k}, quote, ' ...']);
end
fprintf(fid, '\t\t};\n');
fprintf(fid, '\t%s\n', 'return');
fprintf(fid, '%s\n', 'end');
end

function writeSpecProps(testparams, propSpecs, obj, fid, indexOffset)
% Write spec file's videoinput or source properties
propNames = propSpecs.propNames;           % names of properties
propFields = propSpecs.propFields;         % fields of the property
propStructName = propSpecs.propStructName; % name to be given to property struct
if (isfield(propSpecs, "runtimeDefinedProps"))
    runtimeDefProps = propSpecs.runtimeDefinedProps;
else
    runtimeDefProps = {''};
end
if ~exist("indexOffset", "var")
    indexOffset = 0;
end
quote='''';

% Loop through each property name
for k = 1:numel(propNames)
    if ismember(propNames{k}, runtimeDefProps) || strcmpi(class(obj), "videosource")
        RUNTIME_DEFINED = 'true';
    else
        RUNTIME_DEFINED = 'false';
    end

    % Write each prop name as a comment
    fprintf(fid, '\n');
    fprintf(fid, '\t%s\n', ['% ', propNames{k}]);
    fprintf(fid, '\t%s\n', [propStructName '(', num2str(k+indexOffset),...
        ').Name = ', quote, propNames{k}, quote,  ';']);

    % Loop through each field of the property
    pinfo_obj = propinfo(obj, propNames{k});
    for p = 1:numel(propFields)
        % Write property structure
        fprintf(fid, '\t%s', [propStructName '(', num2str(k+indexOffset),...
            ').', propFields{p}, ' = ']);

        % Write the default value followed by a new line
        default_value = pinfo_obj.(propFields{p});
        switch class(default_value)
            case 'cell'
                % Enumerated properties
                fprintf(fid, '%s', '{');
                for q = 1:length(default_value)
                    fprintf(fid, '%s', [quote, default_value{q}, quote]);

                    % print a ';' after each value (except for last)
                    % to make in a column
                    if q ~= length(default_value)
                        fprintf(fid, '%s', ' ');
                    end
                end
                fprintf(fid, '%s', '}');
            case 'function_handle'
                % Callback
                f = functions(default_value);
                fprintf(fid, '%s', ['@', f.function]);
            case 'char'
                fprintf(fid, '%s', [quote, default_value, quote]);
            case 'struct'
                emptyStruct = 'struct(''Type'', [], ''Data'', []);';
                fprintf(fid, '%s;\n', emptyStruct);
                fprintf(fid, '\t%s', [propStructName '(', num2str(k+indexOffset), ').', ...
                    propFields{p}, '(1) = ']);
                fprintf(fid, '%s', '[]');
            case 'videosource'
                fprintf(fid, '%s', [quote, '[1x1 videosource]', quote]);
                RUNTIME_DEFINED = 'true';
            case 'videoinput'
                fprintf(fid, '%s', [quote, '', quote]);
                RUNTIME_DEFINED = 'true';
            otherwise
                if isempty(default_value)
                    % for empty values
                    fprintf(fid, '%s', '[]');
                elseif islogical(default_value)
                    % for logical values
                    if default_value
                        fprintf(fid, '%s', 'true');
                    else
                        fprintf(fid, '%s', 'false');
                    end
                elseif (length(default_value) > 1 & ...
                        ~ischar(default_value))
                    % for bounded doubles
                    fprintf(fid, '%s', '[');

                    for q = 1:length(default_value)
                        value = default_value(q);
                        if isfloat(value)
                            fprintf(fid, '%.17g', value);
                        else
                            fprintf(fid, '%d', value);
                        end
                        fprintf(fid, '%s', ' ');
                    end
                    fprintf(fid, '%s', ']');
                else
                    % for regular doubles
                    if isfloat(default_value)
                        fprintf(fid, '%.17g', default_value);
                    else
                        fprintf(fid, '%d', default_value);
                    end
                end
        end
        % Suppress output with semicolon
        fprintf(fid, '%s\n', ';');
    end
    fprintf(fid, '\t%s\n', [propStructName '(', num2str(k+indexOffset),...
        ').RuntimeDefined = ' RUNTIME_DEFINED ';']);
end
end