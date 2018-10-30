-- This script is querying ConQuest PACS in order to find out whether 
-- a specific DICOM file restricted via QueryString parameters exists
-- the data is reported in JSON format

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');
local seriesuid = CGI('SeriesUID');
local sopinstuid = CGI('SopUID');

-- Functions declaration

function queryonefile()
  local images, imaget, b, s;

  if source == '(local)' then
    s = servercommand('get_param:MyACRNema');
  else
    s = source;
  end

  b = newdicomobject();
  b.PatientID = patientid;
  b.StudyInstanceUID = studyuid;
  b.SeriesInstanceUID = seriesuid;
  b.SOPInstanceUID = sopinstuid;

  images = dicomquery(s, 'IMAGE', b);

  -- convert returned DDO (userdata) to table; needed to allow table.sort
  imaget={}
  for k=0,#images-1 do
    imaget[k+1]={}
    imaget[k+1].SOPInstanceUID = images[k].SOPInstanceUID
  end
  return imaget
end

-- RESPONSE

print('Content-type: application/json\n')
local images = queryonefile()
table.sort(images, function(a,b) return a.SOPInstanceUID<b.SOPInstanceUID end)

print([[ { "FoundFilesCount": ]] .. #images .. [[ } ]])
