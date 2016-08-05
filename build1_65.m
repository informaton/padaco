
deletePathContents('/Users/unknown/code/MATLAB_compiled/1.65/package/');
deletePathContents('/Users/unknown/code/MATLAB_compiled/1.65/testing/');
deletePathContents('/Users/unknown/code/MATLAB_compiled/1.65/files_only/');
go2padaco
deploytool -package Padaco.prj
openDirectory('/Users/unknown/code/MATLAB_compiled/1.65/');