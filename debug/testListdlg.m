failedFiles={'701457t00c11secDataTable.csv'
    '701513t00c11secDataTable.csv'
    '701711t00c11secDataTable.csv'
    '701759t00c11secDataTable.csv'
    '702485t00c11secDataTable.csv'
    '702893t00c11secDataTable.csv'
    '703111t00c11secDataTable.csv'
    '704385t00c11secDataTable.csv'
    '704397t00c11secDataTable.csv'
    '705059t00c11secDataTable.csv'
    '705233t00c11secDataTable.csv'
    '705917t00c11secDataTable.csv'
    '706551t00c11secDataTable.csv'
    '707503t00c11secDataTable.csv'
    '708093t00c11secDataTable.csv'
    '708241t00c11secDataTable.csv'
    '708333t00c11secDataTable.csv'
    '708593t00c11secDataTable.csv'
    '708703t00c11secDataTable.csv'
    '710091t00c11secDataTable.csv'
    '713576t00c11secDataTable.csv'};
fileCount = 268;
failCount = numel(failedFiles);
successCount = fileCount - failCount;
elapsedTimeStr = '00:22:53';
batchResultStr = sprintf(['Processed %u files in %s.',...
    '\n\tSuccess:\t%u\n',...
    '\tFail:\t%u\n'],fileCount,elapsedTimeStr,successCount,failCount);


promptStr = str2cell(sprintf('%s\nFailed files include:',batchResultStr));
promptStr = promptStr(1:3);
% promptStr = batchResultStr;

fprintf(1,'\n\n%u Files Failed:\n',numel(failedFiles));

for f=1:numel(failedFiles)
    fprintf('\t%s\tFAILED.\n',failedFiles{f});
end

skipped_filenames = failedFiles(:);
if(failCount<=10)
    listSize = [180 150];  %[ width height]
elseif(failCount<=20)
    listSize = [180 200];
else
    listSize = [180 300];
end

[selections,clicked_ok]= listdlg('PromptString',promptStr,'Name','Batch Completed',...
    'OKString','Copy to Clipboard','CancelString','Close','ListString',skipped_filenames,...
    'listSize',listSize);

if(clicked_ok)
    %char(10) is newline
    skipped_files = [char(skipped_filenames(selections)),repmat(char(10),numel(selections),1)];
    skipped_files = skipped_files'; %filename length X number of files
    
    clipboard('copy',skipped_files(:)'); %make it a column (1 row) vector
    selectionMsg = [num2str(numel(selections)),' filenames copied to the clipboard.'];
    disp(selectionMsg);
    h = msgbox(selectionMsg);
    pause(1);
    if(ishandle(h))
        delete(h);
    end
end;
