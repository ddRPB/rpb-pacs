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

function queryallimages()
  local images, imaget, b, s

  if source == '(local)' then
    s = servercommand('get_param:MyACRNema')
  else
    s = source;
  end

  b = newdicomobject()
  b.PatientID = patientid
  b.StudyInstanceUID = studyuid
  b.SeriesInstanceUID = seriesuid
  b.SOPInstanceUID = ''
  b.InstanceNumber = ''
  b.SliceLocation = ''
  b.ImageDate =''
  b.Modality = ''

  images = dicomquery(s, 'IMAGE', b)

  -- convert returned DDO (userdata) to table; needed to allow table.sort
  imaget={}
  for k=0,#images-1 do
    imaget[k+1]={}
    imaget[k+1].SOPInstanceUID = images[k].SOPInstanceUID
    imaget[k+1].InstanceNumber = images[k].InstanceNumber
    imaget[k+1].SliceLocation = images[k].SliceLocation
    imaget[k+1].ImageDate = images[k].ImageDate
    imaget[k+1].SeriesInstanceUID = images[k].SeriesInstanceUID
    imaget[k+1].SeriesDescription = images[k].SeriesDescription
    imaget[k+1].Modality = images[k].Modality
  end
  table.sort(imaget, function(a,b) return a.SOPInstanceUID < b.SOPInstanceUID end)

  return imaget
end

-- RESPONSE

HTML('Content-type: application/json\n');
local images = queryallimages()
table.sort(images, function(a,b) return a.SOPInstanceUID<b.SOPInstanceUID end)

jsonstring = [[ { "Series": [ ]] -- start of json obj, start of studies collection

for i=1,#images do
    
  -- If it is first study series or next series in a list
  local split = (i==1) or (images[i-1].SeriesInstanceUID ~= images[i].SeriesInstanceUID)

  -- If it is the next series
  if split and i~=1 then
    jsonstring = jsonstring .. [[ ] ]] -- end of images collection if next exist
    jsonstring = jsonstring .. [[ } ]] -- end of series object if next exist
    jsonstring = jsonstring .. [[, ]] -- next series can be created
  end

  -- If  it is first serie or next serie in a list
  if split then
    --DICOM study json object
    jsonstring = jsonstring .. [[ { ]] -- begin of series object
    jsonstring = jsonstring .. [[ "SeriesInstanceUID": "]] .. images[i].SeriesInstanceUID .. [[", ]]
    
    if images[i].SeriesDescription ~= '' and images[i].SeriesDescription ~= nil then
      jsonstring = jsonstring .. [[ "SeriesDescription": "]] .. images[i].SeriesDescription .. [[", ]]  
    end
    jsonstring = jsonstring .. [[ "Images" : [ ]] -- begin of images collection
  end
  
  -- DICOM images json collection
  jsonstring = jsonstring .. [[ { ]] -- begin of images object
  jsonstring = jsonstring .. [[ "SOPInstanceUID" : "]] ..images[i].SOPInstanceUID .. [[", ]]

  jsonstring = jsonstring .. [[ "Modality" : "]] ..images[i].Modality .. [[ " ]]
  
  jsonstring = jsonstring .. [[ } ]] -- end of images object

  if i ~= #images then
   if images[i+1].SeriesInstanceUID == images[i].SeriesInstanceUID then
    jsonstring = jsonstring .. [[, ]] -- there will be next images object
   end
  end  
end

if #images > 0 then
  jsonstring = jsonstring .. [[ ] ]] -- end of images collection
  jsonstring = jsonstring .. [[ } ]] -- end of serie object
end
jsonstring = jsonstring .. [[ ] ]] -- end of series collection
jsonstring = jsonstring .. [[ } ]] -- end of json obj

HTML(jsonstring)
