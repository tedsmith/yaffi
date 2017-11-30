# Yaffi
Yet Another Free Forensic Imager, for Windows and GNU\Linux

![Logo](https://github.com/tedsmith/yaffi/blob/master/Logo/YAFFILogo2.png)

Compiling the Project Yourself
------------------------------

Binaries for Windows and Linux are available via the Releases section. But if you need or want to compile it yourself, then first clone the source code: `git clone https://github.com/tedsmith/yaffi.git`

There is an LPR and LPI file that is the Lazarus Project File and Lazarus Project Information file. So you need the Lazarus IDE and Freepascal Compiler (v3.0 or above) for your chosen platform, available from www.lazarus-ide.org before anything else. 

After installation of Lazarus and Freepascal, choose "Open Project" and navigate to the folder where you cloned YAFFI.
Lazarus looks for LPI files by default (local config file for a project) which should open on your system but if not, use the LPR project file instead. Simply adjust the drop down menu for file type (bottom right) to "All files", and then select the LPR file.
Lazarus will then warn you that a project session file is missing and would you like to create one. Choose "Yes" and then just click OK in the next window (the one that asks what type of project you are making - it should default to 'Application').
After clicking OK for the last time, a local LPI file will be created for your computer session. 

Lazarus will then complain about some missing packages, unless they happen to be installed in your IDE already; HashLib4Pascal. So you need to install that. Here is how.  

HashLib4Pascal package: The library is included in the GitHub YAFFI project. So simply choose "Package", then "Open Package File (lpk)" from the top menu of Lazarus.
Choose and navigate to `CloneOfYAFFI/HashLib4Pascal/HashLib/src/Packages/FPC/HashLib4PascalPackage.lpk` then click the 'Compile' button.
Then use the next button to the right called 'Use >>' and click 'Add to Project' from the drop-down menu. HashLib4Pascal is now added to your YAFFI project.

Lazarus will re-launch and probably re-open the YAFFI project, hopefully now without errors. 

Now save your project (Project --> Save Project) which will create a new LPI file. Then you can compile YAFFI yourself using Lazarus. 

I am hopeful this guide might encourage collaborators and also help various Linux distributors include YAFFI into their package management platforms. 

Ted Smith