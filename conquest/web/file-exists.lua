-- This script is querying ConQuest PACS in order to find out whether 
-- a specific DICOM file restricted via QueryString parameters exists
-- the data is reported in JSON format

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');
local seriesuid = CGI('SeriesUID');
local sopinstuid = CGI('SopUID');

-- Functions declaration

function queryonefile()
  local series, seriest, b, s;

  if source == '(local)' then
    s = servercommand('get_param:MyACRNema')
  else
    s = source;
  end

  b=newdicomobject();
  b.PatientID = patientid;
  b.StudyInstanceUID = studyuid;
  b.SeriesInstanceUID= seriesuid;
  b.SopInstanceUID = sopinstanceuid;

  series=dicomquery(s, 'SERIES', b);

  -- convert returned DDO (userdata) to table; needed to allow table.sort
  seriest={}
  for k1=0,#series-1 do
    seriest[k1+1]={}
    seriest[k1+1].StudyDate        = series[k1].StudyDate
    seriest[k1+1].PatientID        = series[k1].PatientID
    seriest[k1+1].StudyDate        = series[k1].StudyDate
    seriest[k1+1].SeriesTime       = series[k1].SeriesTime
    seriest[k1+1].StudyInstanceUID = series[k1].StudyInstanceUID
    seriest[k1+1].SeriesDescription= series[k1].SeriesDescription
    seriest[k1+1].StudyDescription = series[k1].StudyDescription
    seriest[k1+1].SeriesInstanceUID= series[k1].SeriesInstanceUID
    seriest[k1+1].Modality         = series[k1].Modality
  end
  return seriest
end

-- RESPONSE

HTML('Content-type: application/json\n\n');
local series = queryonefile()
table.sort(series, function(a,b) return a.StudyInstanceUID<b.StudyInstanceUID end)

jsonstring = [[ { "FoundFilesCount": ]]
jsonstring = jsonstring .. #series
jsonstring = jsonstring .. [[ } ]]
HTML(jsonstring)
