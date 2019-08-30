function getstudyuid()
  local a,b,s;
  s = servercommand('get_param:MyACRNema')
  
  b=newdicomobject();
  b.PatientID = CGI('patientidmatch');
  b.SeriesInstanceUID = CGI('seriesUID');
  b.StudyInstanceUID = '';
  b.Modality = '';
  a=dicomquery(s, 'SERIES', b);
  return a[0].StudyInstanceUID, a[0].Modality
end

function queryimages()
  local images,imaget,b,s;

  s = servercommand('get_param:MyACRNema')

  b=newdicomobject();
  b.PatientID        = CGI('patientidmatch')
  b.SeriesInstanceUID= CGI('seriesUID');
  b.SOPInstanceUID   = '';

  images=dicomquery(s, 'IMAGE', b);

  imaget={}
  for k=0,#images-1 do
    imaget[k+1]={}
   imaget[k+1].SOPInstanceUID=images[k].SOPInstanceUID
  end
  table.sort(imaget, function(a,b) return a.SOPInstanceUID<b.SOPInstanceUID end)

  return imaget
end

HTML('Content-type: text/html\n\n');

local studyuid, modality = getstudyuid()
local size = 256
if modality=='RTSTRUCT' or modality=='RTPLAN' then size = 0 end

print([[
<HEAD><TITLE>Version ]]..version..[[ WADO viewer</TITLE></HEAD>
<BODY BGCOLOR='CFDFCF'>
<H3>Conquest ]]..version..[[ WADO viewer</H3>

<SCRIPT language=JavaScript>
function load()
{
]])

bridge=[[]]
proxy=CGI('proxy')

--  document.images[0].src = ']]..script_name..[[?requestType=WADO&contentType=image/gif'+
--                           ']]..bridge..[[' +
--                           '&studyUID=]]..studyuid..[[' +
--                           '&seriesUID=]]..CGI('seriesUID')..[[' +
--                           '&objectUID=' + document.forms[0].slice.value;


if string.sub(modality, 1, 2)~='RT' then
print([[
  document.images[0].src = ']]..proxy..[['+ 'pacs/dicomImage.faces?'+
                           '&studyUID=]]..studyuid..[[' +
                           '&seriesUID=]]..CGI('seriesUID')..[[' +
                           '&objectUID=' + document.forms[0].slice.value;
]])
end

if string.sub(modality, 1, 2)=='RT' then
print([[
  document.getElementById("myframe").src = ']]..script_name..[[?requestType=WADO&contentType=text/plain'+
			   ']]..bridge..[[' +
                           '&studyUID=]]..studyuid..[[' +
                           '&seriesUID=]]..CGI('seriesUID')..[[' +
                           '&objectUID=' + document.forms[0].slice.value;
]])
end

print([[
}

function PopupCenter(pageURL, title,w,h)
{ var left = (screen.width/2)-(w/2);
  var top = (screen.height/2)-(h/2);
  var targetWin = window.open (pageURL, title, 'toolbar=no, location=no, directories=no, status=no, menubar=no, scrollbars=yes, resizable=yes, copyhistory=no, width='+w+', height='+h+', top='+top+', left='+left);
}

function nextslice()
{ 
 if (document.forms[0].slice.selectedIndex == document.forms[0].slice.length-1) document.forms[0].slice.selectedIndex = 0; 
else document.forms[0].slice.selectedIndex = document.forms[0].slice.selectedIndex + 1; load()
}

function previousslice()
{ 
if (document.forms[0].slice.selectedIndex == 0) document.forms[0].slice.selectedIndex = document.forms[0].slice.length-1; 
else document.forms[0].slice.selectedIndex = document.forms[0].slice.selectedIndex - 1; load()
}

</SCRIPT>
<IMG SRC=loading.jpg BORDER=0 HEIGHT=]].. size ..[[>
]])

if string.sub(modality, 1, 2)=='RT' then
print([[
<iframe id="myframe" BORDER=0 HEIGHT=256>
<p>Your browser does not support iframes.</p>
</iframe>
]])
end

print([[
<H3>]].. modality ..[[</H3>
<FORM>
Slice:
  <INPUT TYPE=BUTTON VALUE='<' onclick=previousslice() >
  <select name=slice onchange=load()>
]]
)

local i, images;
images = queryimages();
for i=1, #images do
  print('<option value='..images[i].SOPInstanceUID..'>'..i..'</option>')
end

print([[
  </select>
  <INPUT TYPE=BUTTON VALUE='>' onclick=nextslice() >
</FORM>
]])

print([[
<SCRIPT language=JavaScript>
  document.onload=document.forms[0].slice.selectedIndex= document.forms[0].slice.length/2;load()
</SCRIPT>
</BODY>
]])
