% This demonstrates how to use rcall to determine weartime of an input file
% using the nhanes wearttime algorithm.  The output is saved to a separate
% file, which can then be processed within Padaco or separately in MATLAB
% or R.  
r_script_filename = 'r_scripts/nhanes_wt.R';
accelerometer_filename = '~/data/sampleData/sample_1sec.csv';
wt_output_filename = '~/data/sampleData/sample_1sec_wt.csv';

output = rcall(r_script_filename,accelerometer_filename,wt_output_filename);  % remove semicolon to display r script's output.

% to process the output consider
fid = fopen(wt_output_filename,'r');
frewind(fid); a = textscan(fid,'%n %n %n %n %n %n %n %n','collectoutput',true,'headerlines',1,'delimiter',',');
fclose(fid);