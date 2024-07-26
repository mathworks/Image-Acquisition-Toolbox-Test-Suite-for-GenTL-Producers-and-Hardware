# Image Acquisition Toolbox Test Suite for GenTL Producers and Hardware

[![View <File Exchange Title> on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/####-file-exchange-title)


This test suite is designed to help users qualify their GenTL producers and compliant camera hardware for use with MATLAB&reg; using Image Acquisition Toolbox&trade;.


The primary function to use is `runGenTLTestSuite()`, through which individual test points, combinations of test points, or all test points included in this repository can be run with available GenTL producers and GenICam-compliant camera hardware. 

Run this test suite to verify the basic behavior of GenTL producers when used by the MATLAB consumer, specifically pertaining to the `videoinput` object and other Image Acquisition Toolbox functions and workflows. Basic results of the test suite appear in the MATLAB Command Window, while detailed results are stored in a log file. 


## Setup
This test suite requires several [MathWorks products](#mathworks-products). This test suite also requires at least one GenTL Producer installed on the local machine, and at least one GenICam-compliant camera, though some test points require multiple to run correctly and will be filtered if sufficient producers and devices are not found. 
To Run:
1. Execute `runGenTLTestSuite()` at the MATLAB Command Window
    * To run all test points on all discoverable configurations, do not include arguments. To run specific tests, specify a string array, character vector, or cell array of character vectors containing test file names and/or individual test procedure names (see [runtests](https://www.mathworks.com/help/matlab/ref/runtests.html#btzwrop-tests) documentation). The log file will be saved to the system temporary directory by default.
        * Example: 
            ```
            >> runGenTLTestSuite("tVideoinput")
            ```
    * Specify "ProducerDirs" name-value pair as a string array, character vector, or cell array of character vectors of absolute paths to directories containing .CTI files to be tested
        * Example: 
            ```
            >> runGenTLTestSuite("ProducerDirs", {'C:\Program Files\VendorName1\Producer\bin\x64', 'C:\Program Files\VendorName2\Producer\x64'})
            ```
    * Specify "LogDirectory" name-value pair as an absolute or relative path to which the log file should be saved.
        * Example: 
            ```
            >> runGenTLTestSuite("LogDirectory", "C:\Users\username\Documents"})
            ```
    * Specify an optional output argument to save the TestResult array to a variable. See documentation for [matlab.unittest.TestResult](https://www.mathworks.com/help/matlab/ref/matlab.unittest.testresult-class.html) for information on this structure.
        * Example: 
            ```
            >> result = runGenTLTestSuite()
            ```
    * Specify an optional second output argument to save the full path to the log file as a variable
        * Example: 
            ```
            >> [result, logfile] = runGenTLTestSuite()
            ```
2. View Command Window output for a short summary of test results
    * Example:
        ```
        >> p = {'C:\Program Files\VendorName1\Producer\bin\x64', 'C:\Program Files\VendorName2\Producer\x64'};
        >> result = runGenTLTestSuite("tAcquisition", "ProducerDirs", p)
        ```
        The output to the MATLAB Command Window of this test run could look something like this:
        ```
        Failure Summary

        Name                                                            Failed  Incomplete
        ==================================================================================
        tAcquisition/verifyTestPattern                                               X    
        Device ID=1
        ProducerDir=...
        C:\Program Files\VendorName1\Producer\x64
        ----------------------------------------------------------------------------------
        tAcquisition/verifyTestPattern                                               X    
        Device ID=1
        ProducerDir=...
        C:\Program Files\VendorName2\Producer\x64
        ----------------------------------------------------------------------------------
        ```
        The above Failure Summary indicates that the `verifyTestPattern` test point in test file `tAcquisition.m` was not able to run to completion. Further analysis of the log file indicates that the test was filtered because the camera represented by Device ID 1 does not have the TestPattern source property. Because they are not mentioned in the Failure Summary, all other test points that were run have passed. The passed test points and configurations can be viewed like so:
        ```
        >> disp({result([result.Passed]).Name}')

                {'tAcquisition[DeviceConfig=struct#ext]/verifyAcquisition'  }
                {'tAcquisition[DeviceConfig=struct#ext]/verifySnapshot'     }
                {'tAcquisition[DeviceConfig=struct#ext]/verifyPreview'      }
                {'tAcquisition[DeviceConfig=struct_1#ext]/verifyAcquisition'}
                {'tAcquisition[DeviceConfig=struct_1#ext]/verifySnapshot'   }
                {'tAcquisition[DeviceConfig=struct_1#ext]/verifyPreview'    }
                {'tAcquisition[DeviceConfig=struct_2#ext]/verifyAcquisition'}
                {'tAcquisition[DeviceConfig=struct_2#ext]/verifySnapshot'   }
                {'tAcquisition[DeviceConfig=struct_2#ext]/verifyPreview'    }
        ```
3. In the event of failures, view the log file for more information and debugging. If no directory is specified with the "LogDirectory" input argument, the log file is saved to the system temporary directory ([tempdir](https://www.mathworks.com/help/matlab/ref/tempdir.html)).

In the event issues are encountered, contact [MathWorks Technical Support](https://www.mathworks.com/support/contact_us.html). Include the log file, a copy of your current imaqsupport.txt, and the generated hardware specification files of any failing configurations located in the `hwspec/` subdirectory located directly under the repository root. 

You can generate a fresh imaqsupport.txt using the [imaqsupport()](https://www.mathworks.com/help/imaq/contacting-mathworks-and-using-the-imaqsupport-function.html) function, which generates the file in the current directory.


### Additional Setup Information:
You can download and run this test suite from any directory with MATLAB write access. Make sure that MATLAB has write access to the system temporary directory and any directory specified for the log file.

#### Environment Variables
If not specifying producer directories to test using the "ProducerDirs" name-value pair, verify that all producer directories which you intend to have the test suite use are listed under the GENICAM_GENTL64_PATH environment variable before executing the test suite. You can check this from the MATLAB Command Window by executing:
```
>> getenv("GENICAM_GENTL64_PATH")
```
Note that if `runGenTLTestSuite` is stopped while running, or exits incorrectly, the GENICAM_GENTL64_PATH may not be reset to its original state on cleanup. To rectify this, either reset the environment variable manually with `setenv()` or restart MATLAB.

#### Hardware Specification Files
Hardware specification files will be generated into a subdirectory called `hwspec`. These files correspond to an individual camera-producer pair and contain information about available device properties and formats. Each file is generated the first time a pair is detected during any test run and will be reused in future test runs unless deleted, moved, or renamed. Regenerate a hardware specification file by deleting, renaming, or moving the existing file out of the `hwspec` subdirectory and then run `runGenTLTestSuite` with any arguments as long as the desired configuration is included. 

#### Advanced Arguments
There are two other optional name-value arguments that can be used, "DeviceIDs" and "Formats". These arguments and their usage are outlined below. Using these arguments adds complexity to the parameterization of the test suite and may require prior knowledge of the available producer and device configurations to be used effectively.
* Specify "DeviceIDs" name-value pair as an integer array of Device IDs. This assumes all testable producers enumerate the devices in the same order. This also assumes that all of the Device IDs contained in the input argument will be enumerable when each individual producer to be tested is set as the only entry in the GENICAM_GENTL64_PATH environment variable. As such, specifying the "ProducerDirs" name-value pair only with producer directories that are known to enumerate the the input Device IDs (or specifying only one producer directory to use) is recommended. 
    * Example: 
        ```
        >> runGenTLTestSuite("DeviceIDs", [1 2 4])
        ```
* Specify "Formats" name-value pair as a string array, character vector, or cell array of character vectors of formats to be tested when `tFormats.m` is among the test files to be run. All devices specified to be used in testing must be able to use all the specified formats, and any invalid configurations will be filtered when `tFormats.m` is run/ 
    * Example: 
        ```
        >> runGenTLTestSuite("Formats", {'Mono8', 'Mono16', 'RGB8Packed'})
        ```

#### Filtered Tests and Ignored Arguments
Some may be filtered automatically if certain conditions are met. This can be for a variety of reasons, but some common ones include:
* Devices do not have the required properties (e.g. tAcquisition/verifyTestPattern requires TestPattern source property)
* Not enough Devices connected/detected (e.g. tProducer/verifyVendorDriver requires two cameras)
* Input arguments are invalid (e.g. tFormats will filter verification for input formats that are not available on the device-under-test) 

Additionally, some test points within this repository will ignore name-value arguments that have been input due to their specific parameterization needs and will cause `runGenTLTestSuite` to throw a warning. The following table outlines which test files ignore which name-value input arguments when specified:

| **Test File**    | **ProducerDirs** | **DeviceIDs** | **Formats** |
|------------------|------------------|---------------|-------------|
| **tAcquisition** | Used             | Used          | Ignored     |
| **tDevices**     | Ignored          | Ignored       | Ignored     |
| **tFormats**     | Used             | Used          | Used        |
| **tProducer**    | Used             | Ignored       | Ignored     |
| **tVideoinput**  | Used             | Used          | Ignored     |

### [MathWorks Products](https://www.mathworks.com/products.html)

Required products for this test suite are:
- MATLAB release R2023b or newer
- Image Acquisition Toolbox
- Image Acquisition Toolbox Support Package for GenICam Interface
- Image Processing Toolbox

## Getting Started
Information about Getting Started
<!--- List or link to any relevent Documentation to help the user Get Started --->
* [GenICam GenTL Hardware Troubleshooting](https://www.mathworks.com/help/imaq/genicam-gentl-hardware.html)
* [Image Acquisition Toolbox Support Package for GenICam Interface](https://www.mathworks.com/matlabcentral/fileexchange/45180-image-acquisition-toolbox-support-package-for-genicam-interface)
* [Get Started with Image Acquisition Toolbox](https://www.mathworks.com/help/imaq/getting-started-with-image-acquisition-toolbox.html)
* [getenv()](https://www.mathworks.com/help/matlab/ref/getenv.html), [setenv()](https://www.mathworks.com/help/matlab/ref/setenv.html)

## Examples
### Run a variety of tests with individual calls
Run all test points in `tVideoinput.m`:
```
>> result = runGenTLTestSuite("tVideoinput")
```
Run only the `verifySnapshot` test point in `tAcquisition.m`:
```
>> result = runGenTLTestSuite("tAcquisition/verifySnapshot")
```
Run all of the above in one function call:
```
>> result = runGenTLTestSuite({'tVideoinput', 'tAcquisition/verifySnapshot'})
```
### Run tests using specific producer directories and devices
Run `verifySnapshot` from `tAcquisition.m` using only the producer directories specified in cell array `p`:
```
>> p = {'C:\Program Files\VendorName1\Producer\bin\x64', 'C:\Program Files\VendorName2\Producer\x64'};
>> result = runGenTLTestSuite("tAcquisition/verifySnapshot","ProducerDirs",p)
```
Run `tVideoinput.m` using the first producer in `p`, and only on device IDs 1 and 2:
```
>> result = runGenTLTestSuite("tVideoinput","ProducerDirs", p(1), "DeviceIDs", [1 2])
```

## License
The license is available in the license.txt file in this GitHub repository.

## Community Support
[MATLAB Central](https://www.mathworks.com/matlabcentral)

Copyright 2024 The MathWorks, Inc.