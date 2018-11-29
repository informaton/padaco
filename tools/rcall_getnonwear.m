% This demonstrates how to use rcall to determine weartime of an input file
% using the nhanes wearttime algorithm.  The output is saved to a separate
% file, which can then be processed within Padaco or separately in MATLAB
% or R.  

function nw = rcall_getnonwear(countFilename,nwAlgorithmToUse)
    if(nargin<3)
        nwAlgorithmToUse = 'nhanes';
    end
    switch(lower(nwAlgorithmToUse))
        case {'nhanes','nci'}
            r_script_filename = 'r_scripts/nhanes_wt.R';
        
        otherwise
            logStatus('Algorithm unrecognized ("%s").  Using default ("nhanes")',nwAlgorithmToUse);
            r_script_filename = 'r_scripts/nhanes_wt.R';
    end
    
    %tmpCountFilename = fullfile(mfilename('fullpath'),'tmklj.tmp');    
    %exportActigraph(dataToGet,epochLenght);
    if(~exist(countFilename,'file'))
        logStatus('Unable to save count data to intermediate text file');
        nw = [];
    else
        nonWearFilename = fullfile(mfilename('fullpath'),'wt_lj.tmp');
    
        
    
        output = rcall(r_script_filename,tmpCountFilename,nonWearFilename);  % remove semicolon to display r script's output.
        
        % to process the output consider
        fid = fopen(nonWearFilename,'r');
        
        % "X","Y","Z","steps","weartimeX","weartimeY","weartimeZ","weartimeS"
        
        frewind(fid);
        headerLine = fgetl(fid);
        numCols = sum(headerLine==',')+1;
        fmtStr = repmat('%n ',1,numCols);
        nw = textscan(fid,fmtStr,'collectoutput',true,'headerlines',1,'delimiter',',');
        %a = textscan(fid,'%n %n %n %n %n %n %n %n','collectoutput',true,'headerlines',1,'delimiter',',');
        fclose(fid);        
        delete(tmpNonwearFilename);
        
        
    end
end