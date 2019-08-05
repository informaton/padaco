function docPath = getDocumentsPath()
try
    docPath = findpath('docs');
catch
    docPath = fileparts(mfilename('fullpath'));
end
end