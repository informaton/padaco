% Invokes R calls via a system call to Rscript
% ref: https://linux.die.net/man/1/rscript
function out = rcall(r_script,varargin)
    RScript = getRScriptFile();
    if(exist(RScript,'file'))
        % Demo version ...
        if(nargin<1)
            out = runDemo();
        else
            r_args = '';
            if(numel(varargin)>0)
                r_args = char(cellstr(varargin{:}));
            end
            sysCmd = sprintf('%s %s %s',RScript, r_script, r_args);
            [status, out] = system(sysCmd);
            if(status~=0)
                fprintf(1,'The r script (%s) did not complete successfully\n',r_script);
            end            
        end
    end
end

function out = runDemo()
    curPath = fileparts(mfilename('fullpath'));
    r_script = fullfile(curPath,'test1.R');
    if(~exist(r_script,'file'))
        fid = fopen(r_script,'w+');
        if(fid > 1)
            fprintf(fid,['x = 0+1',newline]);
            fprintf(fid,['cat(''Test'',x,''complete'');',newline]);
            fclose(fid);
        else
            throw(MException('INF:Padaco:Tools:rcall','rcall.m requires the filename of an R-script to run'))
        end
    end
    out = rcall(r_script);
end
