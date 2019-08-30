-- This script is querying ConQuest PACS in order to retrieve 
-- DICOM series/image data restricted via QueryString parameters
-- the data is reported in JSON format

-- UseCases:
-- query one patient study series with all (*) images

-- do not allow query on all (*) patients
-- do not allow query on all (*) studies
-- do not allow query on all (*) series

-- Helper functions declaration

function isempty(s)
  return s == nil or s == '';
end

-- Supporting old naming conventions
local patientid;
local patientidmatch = CGI('patientidmatch');
if isempty(patientidmatch) then
  patientid = CGI('PatientID');
else
  patientid = patientidmatch;
end

-- Supporting old naming conventions
local studyuid;
local oldstudyuid = CGI('studyUID');
if isempty(oldstudyuid) then
  studyuid = CGI('StudyUID');
else
  studyuid = oldstudyuid;
end

-- Supporting old naming conventions
local seriesuid;
local oldseriesuid = CGI('seriesUID');
if isempty(oldseriesuid) then
  seriesuid = CGI('SeriesUID');
else
  seriesuid = oldseriesuid;
end

-- Functions declaration

function queryallimages()
  local images, imaget, q, s;

  if source == '(local)' then
    s = servercommand('get_param:MyACRNema');
  else
    s = source;
  end

  if not isempty(patientid) and patientid ~= '*' then
    if not isempty(studyuid) and studyuid ~= '*' then
      if not isempty(seriesuid) and seriesuid ~= '*' then
        q = newdicomobject();

        q.PatientID = patientid;
        q.StudyInstanceUID = studyuid;
        q.SeriesInstanceUID = seriesuid;
        q.SOPInstanceUID = '';
        q.InstanceNumber = '';
        q.SliceLocation = '';
        q.ImageDate ='';
        q.Modality = '';

        images = dicomquery(s, 'IMAGE', q);

        -- convert returned DDO (userdata) to table; needed to allow table.sort
        imaget = {};
        for i = 0, #images-1 do
          imaget[i+1] = {};
          imaget[i+1].SOPInstanceUID = images[i].SOPInstanceUID;
          imaget[i+1].InstanceNumber = images[i].InstanceNumber;
          imaget[i+1].SliceLocation = images[i].SliceLocation;
          imaget[i+1].ImageDate = images[i].ImageDate;
          imaget[i+1].SeriesInstanceUID = images[i].SeriesInstanceUID;
          imaget[i+1].SeriesDescription = images[i].SeriesDescription;
          imaget[i+1].Modality = images[i].Modality;
        end
      end
    end
  end
  
  return imaget;
end

function queryallsizes()
  local imaget;

  if not isempty(patientid) and patientid ~= '*' then
    if not isempty(studyuid) and studyuid ~= '*' then
      if not isempty(seriesuid) and seriesuid ~= '*' then
        local images = dbquery('dicomimages', 'objectfile,sopinstanc', 'seriesinst = \'' .. seriesuid .. '\'');

        if #images > 0 then
          imaget = {};
          for i = 1, #images do
            imaget[i] = {};
            imaget[i].ObjectFile = images[i][1];
            imaget[i].SOPInstanceUID = images[i][2];
          end
        end
      end
    end
  end
  
  return imaget;
end

-- RESPONSE

print('Content-type: application/json\n');

local images = queryallimages();

print([[{ "Series": [ ]]); -- start of json obj, start of studies collection

if images ~= nil then

  table.sort(images, function(a, b) return a.SOPInstanceUID < b.SOPInstanceUID end);

  local files = queryallsizes();
  if files ~= nil then
    table.sort(files, function(a, b) return a.SOPInstanceUID < b.SOPInstanceUID end);
  end

  for i = 1, #images do

    -- If it is first series
    if i == 1 then

      -- DICOM series json object
      print([[ { "SeriesInstanceUID": "]] .. images[i].SeriesInstanceUID .. [[", ]]);

      if images[i].SeriesDescription ~= '' and images[i].SeriesDescription ~= nil then
        -- Percentage sign is a special character in lua, that is why I need to mask it
        maskedDescription = string.gsub(images[i].SeriesDescription, "%%", "%%%%");
        print([[ "SeriesDescription": "]] .. maskedDescription .. [[", ]]);
      end

      if images[i].Modality ~= '' and images[i].Modality ~= nil then
        print([[ "Modality": "]] .. images[i].Modality .. [[", ]]);
      end

      -- DICOM images collection
      print([[ "Images": [ ]]); -- begin of images collection
    end

    -- DICOM image json object
    if images[i].SOPInstanceUID ~= '' and images[i].SOPInstanceUID ~= nil then

      -- Determine size of the DICOM file
      local size;
      if files ~= nil and #files == #images then
        local file = io.open("/mnt/data1/" .. files[i].ObjectFile, "r");
        size = file:seek("end");
        io.close(file);
      end

      if not isempty(size) then
        print([[ { "SOPInstanceUID": "]] ..images[i].SOPInstanceUID .. [[", ]]);
        print([[ "Size": "]] .. size .. [[" } ]]);
      else
        print([[ { "SOPInstanceUID": "]] ..images[i].SOPInstanceUID .. [[" } ]]);
      end
    end

    if i ~= #images then
      if images[i+1].SeriesInstanceUID == images[i].SeriesInstanceUID then
        print([[, ]]); -- there will be next images object
      end
    end
  end

  if #images > 0 then
    print([[ ] } ]]); -- end of images collection and  end of series object
  end
end

print([[ ] } ]]); -- end of series collection and end of json object
