Padaco
======

Interpreting state-of-the-art accelerometer monitoring of physical activity and sleep to reduce obesity and improve child health

# Description

Padaco is a data visualization and analysis tool for accelerometry data obtained from a wearable device.  It currently supports Actigraph's GT3X+ sensor. You can use the software to visualize this sensor data, which includes tri-axial accelerometry (X,Y,Z axis and their vector magnitude), luminance, and some other derived measures (e.g. step count and inclination).

See the home page at http://web.stanford.edu/~hyatt4/software/padaco for a user manual, test data set, and compiled versions of the software (Mac OS X only at the moment).

If you want to run the source code from here, then you will need to use MATLAB.

The software provides several visualizations of the data and clustering features when you have many days of recorded activity. There is an activity and sleep classification algorithm as well, which is described in the help section of the software.

# Getting started

To run from source, open MATLAB and set its Current Folder to the root of this repository. Then run:

```matlab
padaco
```

The entry point calls `pathsetup` to add the application folders to the MATLAB path before opening the interface. See the bundled [instruction manual](_resources/html/Padaco%20instruction%20manual.pdf) for usage instructions.

For the native CSV helpers and their build requirements, see [src/README.md](src/README.md).

# Repository layout

| Directory | Contents |
| --- | --- |
| `abstract/` | Shared base classes for data, settings, and controllers. |
| `controllers/` | Application controllers and settings management. |
| `models/` | Sensor data, classification, clustering, and parameter classes. |
| `views/` | MATLAB figures, dialogs, apps, and UI widgets. |
| `events/` | Event data classes used by the application. |
| `utility/` | Shared helper functions. |
| `stats/` | Statistical helper functions. |
| `+featureFcn/` | MATLAB package containing feature functions. |
| `tools/` | Additional MATLAB and R analysis scripts and tools. |
| `src/` | Native C helpers and MATLAB MEX sources. |
| `_resources/` | Manuals, help images, icons, and version information. |
| `debug/` | Development scripts and experiments. |
| `archive/` | Older code and figures. |

# License

See [LICENSE](LICENSE) for licensing information.

# Funding

This work was partially funded by a Stanford-Oxford Big Data for Human Health seed grant from the Li Ka Shing Foundation and a grant from the Stanford Child Health Research Institute and a grant from the Food and Drug Administration.
