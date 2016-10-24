
x='7/29/2014,17:00:35,0,0,0,0,131,1,0,0,0,0';
startD = datenum('07/29/2014,17:00:35','mm/dd/yyyy,HH:MM:SS');
deltaD = datenum([0 0 0 0 0 1]);
endD = startD+datenum([0 0 0 7 0 0]);
fid = fopen('app.txt','w');
curD = startD;
while(curD < endD)
    curD = curD+deltaD;
    fprintf(fid,'%s,0,0,0,0,131,1,0,0,0,0\n',datestr(curD,'mm/dd/yyyy,HH:MM:SS'));
end
fclose(fid);