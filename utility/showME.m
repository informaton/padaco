% showME(me, {fid}) Simple error reporting function for MATLAB using the MEexception me
% me is an instance of MException
% fid is an optional file id representing the file to write to.  Default is
% fid = 1 (print to screen)
%
%Author:  Hyatt Moore IV
% Date:   2012/2013/2016
function showME(me,fid)

if(nargin<2 || isempty(fid) || fid<1)
    fid = 1;
end

fprintf(fid,'%s\n',me.message);

if(fid==1)
    for k=1:numel(me.stack)
        fprintf(fid,'<a href="matlab: opentoline(''%s'',%u,1)">%s at %u</a>\n',me.stack(k).file,me.stack(k).line,me.stack(k).name,me.stack(k).line);
    end
else
    for k=1:numel(me.stack)
        fprintf(fid,'\t%s line %u:\t%s\n',me.stack(k).file,me.stack(k).line,me.stack(k).name);
    end
end

