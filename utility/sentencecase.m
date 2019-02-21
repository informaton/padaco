%  'DR' -> 'Dr'
%  'joe' -> 'Joe'
%  @hyatt moore iv
function strOut = sentencecase(strIn)
strOut = '';
if(ischar(strIn))
    strOut = [upper(strIn(1)), lower(strIn(2:end))];
end