function go2padaco()
%helper function to get to the Padaco directory.  Place this in the padaco folder and
%make sure that the padaco path (where this file is located) is on your MATLAB path
fmf = mfilename('fullpath');
cd(fileparts(fmf));
cd ..;