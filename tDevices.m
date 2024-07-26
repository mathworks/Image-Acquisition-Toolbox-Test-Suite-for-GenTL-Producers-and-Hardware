classdef tDevices < matlab.unittest.TestCase
    % tDevices tests the discoverability of individual devices per and
    % between producers
    % INCLUDED TESTS:
    %
    %       verifyDeviceSequence   - Verify devices are enumerated
    %                                sequentially on discovery
    %       verifyAllDevices       - Verify that all producers detect all
    %                                connected devices

    % Copyright 2024 The MathWorks, Inc.

    properties
        TestParams
        CurrDevice
        CurrProducer
        % This test is not parameterized like the others as all devices are
        % considered in verification
        DeviceConfig = hConstructParams()
    end

    % Test Setup
    methods(TestClassSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            % Create test parameters based on first available configuration
            % of device and producer. This will mostly be ignored, but
            % allows test setup and cleanup to run
            testCase.CurrDevice = testCase.DeviceConfig{1};
            testCase.CurrProducer = testCase.DeviceConfig{1}.Producer;
            testCase.TestParams = hTestSetup(testCase.TestParams, ...
                testCase.CurrDevice, testCase.CurrProducer);
            setenv("GENICAM_GENTL64_PATH", testCase.TestParams.initialGentlEnv);
            % Suppress this warning as it may show up if producers do not
            % detect a device. Verification of detection is being performed
            % anyway, so any failures from this warning would be redundant.
            testCase.applyFixture(SuppressedWarningsFixture( ...
                "imaq:imaqhwinfo"))
            imaqreset();
        end
    end

    % Test Cleanup
    methods(TestClassTeardown)
        function cleanup(testCase)
            testCase.TestParams = hTestCleanup(testCase, testCase.TestParams);
        end
    end

    % Verification Methods
    methods(Test)
        function verifyDeviceSequence(testCase)
            % Verify that all devices discoverable by the gentl adaptor
            % appear with sequential device IDs. Duplicate device entries
            % (due to multiple producers picking them up) should still be
            % enumerated sequentially.
            hwInfo = imaqhwinfo("gentl");
            numDeviceIDs = numel(hwInfo.DeviceIDs);
            if (numDeviceIDs ~= 0)
                % Verify that device indexing starts at 1
                testCase.verifyEqual(hwInfo.DeviceIDs{1}, 1, ...
                    "Device ID for gentl adaptor does not start at index 1.");
                % Verify that index values are stored in increasing order
                if (numDeviceIDs > 1)
                    badIndex = [];
                    for p = 1:numDeviceIDs-1
                        badIndex(p) = hwInfo.DeviceIDs{p+1} < hwInfo.DeviceIDs{p};
                    end
                    testCase.verifyFalse(any(badIndex), ...
                        "Hardware discovered by gentl adaptor did not have" + ...
                        " the expected device IDs");
                end
            else
                testCase.verifyTrue(false, ...
                    "No gentl devices found. Ending verifyDeviceSequence.");
            end
            % Verify that there is one DeviceInfo entry struct per DeviceID
            % in the hardware info
            testCase.verifyEqual(length(hwInfo.DeviceIDs), length(hwInfo.DeviceInfo))
        end

        function verifyAllDevices(testCase)
            % Verify that all devices are detected by all producers
            % Since devices can be named differently by different
            % producers, this test will give each device a unique value for
            % DeviceUserID, which should persist across device connection
            % instances and producers

            testCase.addTeardown(@setenv,"GENICAM_GENTL64_PATH", ...
                testCase.TestParams.initialGentlEnv)
            producers = hGetAllProducers();
            % Create cell array to store all captured DeviceUserIDs
            allDUIDs = cell(1,length(producers));

            % Get test start time of the loop below. This is because the
            % values of set DeviceUserIDs will be time-dependent
            startTime = datetime;
            % Loop through all producers. This is not done with
            % TestParameters because the results of each loop/run need to
            % be saved and compared for verification
            for n=1:length(producers)
                setenv("GENICAM_GENTL64_PATH", producers{n});
                imaqreset;
                hwInfo = imaqhwinfo("gentl");
                allDUIDs{n} = cell(1, length(hwInfo.DeviceIDs));
                for m=1:length(hwInfo.DeviceIDs)
                    vid = videoinput("gentl", hwInfo.DeviceIDs{m});
                    src = vid.Source;
                    if isprop(src, "DeviceUserID")
                        initialDUID = src.DeviceUserID;
                        % If there is no DeviceUserID or its value was 
                        % already set by a previous execution of this test
                        % point, set the DeviceUserID. Otherwise, do not 
                        % set it as it was set by a previous loop.
                        if isempty(initialDUID) || testCase.hCheckIfOldTestDUID(initialDUID, startTime)
                            src.DeviceUserID = testCase.hMakeTempDUID();
                        end
                        allDUIDs{n}{m} = src.DeviceUserID;
                    else
                        % Some cameras may not have DeviceUserID. Set the
                        % allDUIDs entry for these devices to a placeholder
                        % for later processing
                        disp("DeviceID " + hwInfo.DeviceIDs{m} + " using " + ...
                            "producer in " + producers{n} + " does not have" + ...
                            " the DeviceUserID source property and cannot " + ...
                            "be used for verification" + newline);
                        allDUIDs{n}{m} = 'NO_DUID';
                    end
                    delete(vid);
                end
            end
            % Devices are not expected to be enumerated in the same order
            % by every producer, nor are they expected to be listed
            % under the same name across different producers. To get around
            % this, all hardware is assigned a DeviceUserID which will 
            % remain consistent across object creation. This will be used 
            % to verify that the same devices appear with every producer.
            % First, get all unique devices detected by producers
            distinctDevices = unique(cat(2,allDUIDs{:}));
            % Allocate a table to represent results
            t = table('Size',[length(producers) length(distinctDevices)], ...
                'VariableTypes', repmat("logical", 1, length(distinctDevices)), ...
                'VariableNames', distinctDevices);
            % Check whether each device appeared in each producer, the
            % put the results in the table. Columns represent unique
            % DeviceUserIDs (there will be a column representing devices 
            % that do not have the DeviceUserID source property called 
            % NO_DUID), and rows represent producers
            for n=1:length(producers)
                t(n,:) = array2table(ismember(distinctDevices, allDUIDs{n}));
            end
            t.Properties.RowNames = producers;
            if contains(t.Properties.VariableNames, "NO_DUID")
                % Log that not all devices without the DeviceUserID source 
                % property were found and are not included in the table
                disp("Only devices with DeviceUserID are listed below.");
                t = removevars(t, "NO_DUID");
            end
            disp(t);

            % Fail test if any device was not detected by a producer.
            testCase.verifyFalse(ismember(false, table2array(t)), ...
                "Not all devices were detected by all producers. " + ...
                "Please review table for more information.")
        end
    end

    methods(Static)
        function result = hCheckIfOldTestDUID(name, startTime)
            % Check if the name given was set by the currently-running
            % test (false), or if it was set by user or a previous
            % execution of the test point (true)
            result = true;
            try
                % If this can be created, it means the DeviceUserID was
                % previously set either in this test point execution OR in
                % a previous execution
                nameTime = datetime(name(3:end), "InputFormat", "ddMMyyHHmmss");
            catch ME
                disp("DeviceUserID " + name + " was not set by this test " + ...
                    "suite, but may be lost if the test exits incorrectly.")
            end

            if length(name)==14 && name(1:2) == "mw" && exist("nameTime", "var")
                % The DeviceUserID was set by the test. Extract the exact
                % time that this was set
                % If the given name is newer (greater) than the start of
                % the running test point, then it must NOT have been set in
                % a previous execution. and therefore it does not need to
                % be reset for the remainder of the test.
                if nameTime > startTime
                    result = false;
                end
            end
        end

        function name = hMakeTempDUID
            % Create a DeviceUserID from the current date and time
            % Pause briefly before creating the name to make sure
            % consecutively set IDs are always distinct
            pause(1);
            d = datetime;
            d.Format = "ddMMyyHHmmss";
            name = "mw" + string(d);
        end
    end
end