![ASCC Logo](/images/umaineascc.png)

# TOWTOOL
> Tow-Out Workflow Toolkit for Offshore Operations and Logistics

A library for `MATLAB` developed to simulate mooring install, tow-out, and hookup operations for a floating offshore wind farm.
TOWTOOL implements a stepped simulation framework with cross agent communication.


## Installing
The repository can be installed by downloading a `.zip` or via `git` by clicking the <span style="background-color:green">**&#60;&#62; Code&#11206;**</span> button above.

### Installing via direct download
To download a `.zip`, click the `Download ZIP` button and follow the prompts on the screen. 
Extract the `.zip` wherever you would like to locally store the toolbox.

![git code button](images/gitDirectDownload.png)

### Installing via git
To download the TOWTOOL via git, enter the following commands in a bash window:

```bash
cd /path/to/local/folder
git clone https://github.com/loralindyberg/TOWTOOL.git
```

This will create a folder at */path/to/local/folder* with the name TOWTOOL.

#### Dependencies
This toolbox requires a minimum of `MATLAB 2025b`, and it is recommended to have all available add-ons installed.
If users would like to use the weather module, they will need weather data in the form of a structure saved in either a .mat file or a .csv.
There is an example of both data structures in this repository, user data will require the same structure.

## Deployment
Once the toolbox has been installed via the preferred method, use of the code is simple.

Simply navigate to */path/to/local/folder/TOWTOOL* in a `MATLAB` window and open `TOWTOOL_GUI_82.mlapp`.

Each module, as well as `TOWTOOL_GUI_82.mlapp`, has extensive comments.

## Contributing
Please feel free to open an issue with any problems that occur or changes that feel like they would improve the experience of using the tool.

If you'd like to contribute on your own, please fork the repository and use a feature branch.
Pull requests are warmly welcome.
