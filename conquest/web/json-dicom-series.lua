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
  return imaget
end

function queryallsizes()
  local images = dbquery('dicomimages', 'objectfile,sopinstanc', 'seriesinst = \'' .. seriesuid .. '\'')

  local imaget={}
  for k=1,#images do
    imaget[k]={}
    imaget[k].SOPInstanceUID = images[k][2]
    imaget[k].ObjectFile = images[k][1]
  end
  return imaget
end

-- RESPONSE

print('Content-type: application/json\n')
local images = queryallimages()
table.sort(images, function(a,b) return a.SOPInstanceUID<b.SOPInstanceUID end)

local files= queryallsizes()
table.sort(files, function(a,b) return a.SOPInstanceUID<b.SOPInstanceUID end)

print([[{ "Series": [ ]]) -- start of json obj, start of studies collection

for i=1,#images do
    
  -- If it is first serie
  if i == 1 then
    --DICOM series json object
    print([[ { "SeriesInstanceUID": "]] .. images[i].SeriesInstanceUID .. [[", ]])
   
    if images[i].SeriesDescription ~= '' and images[i].SeriesDescription ~= nil then
      -- Percentage sign is a special character in lua, that is why I need to mask it
      maskedDescription = string.gsub(images[i].SeriesDescription, "%%", "%%%%")
      print([[ "SeriesDescription": "]] .. maskedDescription .. [[", ]])
    end

    if images[i].Modality ~= '' and images[i].Modality ~= nil then
      print([[ "Modality": "]] .. images[i].Modality .. [[", ]])
    end

    -- DICOM images collection
    print([[ "Images": [ ]]) -- begin of images collection
  end
  
  -- DICOM image json object
  if images[i].SOPInstanceUID ~= '' and images[i].SOPInstanceUID ~= nil then
    
    -- Determine size of the DICOM file
    local filename = files[i].ObjectFile
    local path = "/mnt/data1/" .. filename
    local file = io.open(path, "r")
    local size = file:seek("end")
    io.close(file)
    
    if size ~= '' and size ~= nil then
      print([[ { "SOPInstanceUID": "]] ..images[i].SOPInstanceUID .. [[", ]])
      print([[ "Size": "]] .. size .. [[" } ]])
    else
      print([[ { "SOPInstanceUID": "]] ..images[i].SOPInstanceUID .. [[" } ]])	    
    end
  end
  
  --HTML(jsonstring)
  if i ~= #images then
   if images[i+1].SeriesInstanceUID == images[i].SeriesInstanceUID then
    print([[, ]]) -- there will be next images object
   end
  end  
end

if #images > 0 then
  print([[ ] } ]]) -- end of images collection and  end of series object
end

print([[ ] } ]]) -- end of series collection and end of json object
