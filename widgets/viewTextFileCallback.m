function viewTextFileCallback(hObject, eventData, textFullFilename)
    if(exist(textFullFilename,'file'))
        url = sprintf('file://%s',textFullFilename);
        htmldlg('url',url,'title',textFullFilename);
    else
        fprintf(1,'File does not exist (%s)\n',textFullFilename);
    end
end