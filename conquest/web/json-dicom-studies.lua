-- This script is querying ConQuest PACS in order to retrieve 
-- DICOM patient/study/series data restricted via QueryString parameters
-- the data is reported in JSON format

local patientid = CGI('patientidmatch');
local studyuid = CGI('studyUID');
local studydate = CGI('studyDate');
local seriesuid = CGI('seriesUID');
local modality = CGI('modality');
local seriestime = CGI('seriesTime');

-- Functions declaration

function queryallseries()
  local series, seriest, b, s;

  if source == '(local)' then
    s = servercommand('get_param:MyACRNema')
  else
    s = source;
  end
 
  b = newdicomobject();
  b.PatientID = patientid;
  b.StudyInstanceUID = studyuid;
  b.StudyDescription = '';
  b.StudyDate = studydate;
  b.StudyTime = '';
  b.SeriesInstanceUID = seriesuid;
  b.SeriesNumber = '';
  b.SeriesDescription = '';
  b.SeriesDate = '';
  b.SeriesTime = seriestime;
  b.Modality = modality;
 
  series = dicomquery(s, 'SERIES', b);
  
  -- convert returned DDO (userdata) to table; needed to allow table.sort
  seriest={}
  for k1=0,#series-1 do
    seriest[k1+1]={}
    seriest[k1+1].PatientID        = series[k1].PatientID
    seriest[k1+1].StudyInstanceUID = series[k1].StudyInstanceUID
    seriest[k1+1].StudyDescription = series[k1].StudyDescription
    seriest[k1+1].StudyDate        = series[k1].StudyDate
    seriest[k1+1].StudyTime        = series[k1].StudyTime
    seriest[k1+1].SeriesInstanceUID= series[k1].SeriesInstanceUID
    seriest[k1+1].SeriesNumber     = series[k1].SeriesNumber
    seriest[k1+1].SeriesDescription= series[k1].SeriesDescription
    seriest[k1+1].SeriesDate       = series[k1].SeriesDate
    seriest[k1+1].SeriesTime       = series[k1].SeriesTime
    seriest[k1+1].Modality         = series[k1].Modality
  end
  return seriest
end

-- RESPONSE

print('Content-type: application/json\n')
local series = queryallseries()
table.sort(series, function(a,b) return a.StudyInstanceUID<b.StudyInstanceUID end)

print([[{ "Studies": [ ]]) -- start of json obj, start of studies collection

for i=1,#series do

  if series[i].StudyDate == '' then series[i].StudyDate = series[i].SeriesDate end
  if series[i].StudyDate == '' or series[i].StudyDate == nil then series[i].StudyDate = 'Unknown' end
  
  -- Determine whether it is first study or next study in a list (split necessary)
  local split = (i==1) or (series[i-1].StudyInstanceUID ~= series[i].StudyInstanceUID)

  -- If it is a next study
  if split and i~=1 then
    print([[ ] } , ]]) -- end of series collection if next exist, end of study object if next exist, next study can be created
  end

  -- If  it is first study or next study in a list
  if split then
    --DICOM study json object    
    print([[ { "StudyInstanceUID": "]] .. series[i].StudyInstanceUID .. [[", ]]) -- begin of study object
    
    if series[i].StudyDescription ~= '' and series[i].StudyDescription ~= nil then
      -- Percentage sign is a special character in lua, that is why I need to mask it
      maskedDescription = string.gsub(series[i].StudyDescription, "%%", "%%%%")
      print([[ "StudyDescription": "]] .. maskedDescription .. [[", ]])
    end

    if series[i].StudyDate ~= '' and series[i].StudyDate ~= nil then
      print([[ "StudyDate": "]] .. series[i].StudyDate .. [[", ]])
    end

    if series[i].StudyTime ~= '' and series[i].StudyTime ~= nil then
      print([[ "StudyTime": "]] .. series[i].StudyTime .. [[", ]])
    end
    
    print ([[ "Series" : [ ]]) -- begin of series collection
  end
 
  -- DICOM series json collection
  print([[ { "SeriesInstanceUID" : "]] ..series[i].SeriesInstanceUID .. [[", ]]) -- begin of series object
  
  if series[i].SeriesNumber ~= '' and series[i].SeriesNumber ~= nil then
    print ([[ "SeriesNumber": "]] .. series[i].SeriesNumber .. [[", ]])
  end

  if series[i].SeriesDescription ~= '' and series[i].SeriesDescription ~= nil then
    -- Percentage sign is a special character in lua, that is why I need to mask it
    maskedDescription = string.gsub(series[i].SeriesDescription, "%%", "%%%%")
    print([[ "SeriesDescription": "]] .. maskedDescription .. [[", ]])
  end
 
  if series[i].SeriesDate ~= '' and series[i].SeriesDate ~= nil then
    print([[ "SeriesDate": "]] .. series[i].SeriesDate .. [[", ]])
  end 

  if series[i].SeriesTime ~= '' and series[i].SeriesTime ~= nil then
    print([[ "SeriesTime": "]] .. series[i].SeriesTime .. [[", ]])
  end
  
  print([[ "Modality": "]] .. series[i].Modality .. [[ " } ]]) -- end of series object

  if i ~= #series then
   if series[i+1].StudyInstanceUID == series[i].StudyInstanceUID then
    print([[, ]]) -- there will be nex series object
   end
  end 
end

if #series > 0 then
  print([[ ] } ]]) -- end of series collection and end of study object
end
print([[ ] } ]]) -- end of studies collection and end of json obj
