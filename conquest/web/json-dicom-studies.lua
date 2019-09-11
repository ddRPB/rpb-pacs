-- This script is querying ConQuest PACS in order to retrieve 
-- DICOM study/series data restricted via QueryString parameters
-- the data is reported in JSON format

-- UseCases:
-- query one patient all (*) studies with all series
-- query one patient study with all series
-- query one patient study with one series

-- do not allow query on all (*) patients

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
local studydate;
local oldstudydate = CGI('studyDate');
if isempty(oldstudydate) then
  studydate = CGI('StudyDate');
else
  studydate = oldstudydate;
end

-- Supporting old naming conventions
local seriesuid;
local oldseriesuid = CGI('seriesUID');
if isempty(oldseriesuid) then
  seriesuid = CGI('SeriesUID');
else
  seriesuid = oldseriesuid;
end

-- Supporting old naming conventions
local modality;
local oldmodality = CGI('modality');
if isempty(oldmodality) then
  modality = CGI('Modality');
else
  modality = oldmodality;
end

-- Supporting old naming conventions
local seriestime;
local oldseriestime = CGI('seriesTime');
if isempty(oldseriestime) then
  seriestime = CGI('SeriesTime')
else
  seriestime = oldseriestime
end

-- Functions declaration

function queryallseries()
  local series, seriest, q, s;

  if source == '(local)' then
    s = servercommand('get_param:MyACRNema');
  else
    s = source;
  end

  if not isempty(patientid) and patientid ~= '*' then
    q = newdicomobject();

    q.PatientID = patientid;
    q.StudyInstanceUID = studyuid;
    q.StudyDescription = '';
    q.StudyDate = studydate;
    q.StudyTime = '';
    q.SeriesInstanceUID = seriesuid;
    q.SeriesNumber = '';
    q.SeriesDescription = '';
    q.SeriesDate = '';
    q.SeriesTime = seriestime;
    q.Modality = modality;

    series = dicomquery(s, 'SERIES', q);

    -- convert returned DDO (userdata) to table; needed to allow table.sort
    seriest = {}
    for i = 0, #series-1 do
      seriest[i+1] = {};
      seriest[i+1].PatientID        = series[i].PatientID;
      seriest[i+1].StudyInstanceUID = series[i].StudyInstanceUID;
      seriest[i+1].StudyDescription = series[i].StudyDescription;
      seriest[i+1].StudyDate        = series[i].StudyDate;
      seriest[i+1].StudyTime        = series[i].StudyTime;
      seriest[i+1].SeriesInstanceUID= series[i].SeriesInstanceUID;
      seriest[i+1].SeriesNumber     = series[i].SeriesNumber;
      seriest[i+1].SeriesDescription= series[i].SeriesDescription;
      seriest[i+1].SeriesDate       = series[i].SeriesDate;
      seriest[i+1].SeriesTime       = series[i].SeriesTime;
      seriest[i+1].Modality         = series[i].Modality;
    end
  end

  return seriest
end

function getoneinstance(pid, stuid, seuid)
  local images, q, s;

  if source == '(local)' then
    s = servercommand('get_param:MyACRNema');
  else
    s = source;
  end

  if not isempty(pid) and pid ~= '*' then
    if not isempty(stuid) and stuid ~= '*' then
      if not isempty(seuid) and seuid ~= '*' then
        q = newdicomobject();

        q.PatientID = pid;
        q.StudyInstanceUID = stuid;
        q.SeriesInstanceUID = seuid;
        q.SOPInstanceUID = '';

        images = dicomquery(s, 'IMAGE', q);
      end
    end
  end

  local dcm;
  if #images > 0 then
    dcm = newdicomobject();
    readdicom(dcm, stuid  .. '\\' .. seuid ..  '\\' .. images[0].SOPInstanceUID);
  end

  return dcm;
end

-- RESPONSE

print('Content-type: application/json\n');

local series = queryallseries();

print([[{ "Studies": [ ]]); -- start of json obj, start of studies collection

if series ~= nil then

  table.sort(series, function(a, b) return a.StudyInstanceUID < b.StudyInstanceUID end);

  for i = 1, #series do

    if series[i].StudyDate == '' then series[i].StudyDate = series[i].SeriesDate end
    if series[i].StudyDate == '' or series[i].StudyDate == nil then series[i].StudyDate = 'Unknown' end

    -- Determine whether it is first study or next study in a list (split necessary)
    local split = (i == 1) or (series[i-1].StudyInstanceUID ~= series[i].StudyInstanceUID);

    -- If it is a next study
    if split and i ~= 1 then
      print([[ ] } , ]]); -- end of series collection if next exist, end of study object if next exist, next study can be created
    end

    -- If it is first study or next study in a list
    if split then

      studyInstanceUid = series[i].StudyInstanceUID;

      -- DICOM study json object
      print([[ { "StudyInstanceUID": "]] .. studyInstanceUid .. [[", ]]); -- begin of study object

      if series[i].StudyDescription ~= '' and series[i].StudyDescription ~= nil then
        -- Percentage sign is a special character in lua, that is why I need to mask it
        maskedDescription = string.gsub(series[i].StudyDescription, "%%", "%%%%");
        print([[ "StudyDescription": "]] .. maskedDescription .. [[", ]]);
      end

      if series[i].StudyDate ~= '' and series[i].StudyDate ~= nil then
        print([[ "StudyDate": "]] .. series[i].StudyDate .. [[", ]]);
      end

      if series[i].StudyTime ~= '' and series[i].StudyTime ~= nil then
        print([[ "StudyTime": "]] .. series[i].StudyTime .. [[", ]]);
      end

      print ([[ "Series" : [ ]]); -- begin of series collection
    end

    seriesInstanceUid = series[i].SeriesInstanceUID;

    -- DICOM series json collection
    print([[ { "SeriesInstanceUID" : "]] .. seriesInstanceUid .. [[", ]]); -- begin of series object

    if series[i].SeriesNumber ~= '' and series[i].SeriesNumber ~= nil then
      print ([[ "SeriesNumber": "]] .. series[i].SeriesNumber .. [[", ]]);
    end

    if series[i].SeriesDescription ~= '' and series[i].SeriesDescription ~= nil then
      -- Percentage sign is a special character in lua, that is why I need to mask it
      maskedDescription = string.gsub(series[i].SeriesDescription, "%%", "%%%%");
      print([[ "SeriesDescription": "]] .. maskedDescription .. [[", ]]);
    end

    if series[i].SeriesDate ~= '' and series[i].SeriesDate ~= nil then
      print([[ "SeriesDate": "]] .. series[i].SeriesDate .. [[", ]]);
    end

    if series[i].SeriesTime ~= '' and series[i].SeriesTime ~= nil then
      print([[ "SeriesTime": "]] .. series[i].SeriesTime .. [[", ]]);
    end

    modality = series[i].Modality;

    if modality == 'RTPLAN' or modality == 'RTDOSE' or modality == 'RTSTRUCT' or modality == 'RTIMAGE' then
      dcm = getoneinstance(patientid, studyInstanceUid, seriesInstanceUid);

      if dcm ~= nil then

        if modality == 'RTPLAN' then
          if not isempty(dcm.RTPlanLabel) then
            print([[ "RTPlanLabel": "]] .. dcm.RTPlanLabel .. [[", ]]);
          end
          if not isempty(dcm.RTPlanName) then
            print([[ "RTPlanName": "]] .. dcm.RTPlanName .. [[", ]]);
          end
          if not isempty(dcm.RTPlanDescription) then
            print([[ "RTPlanDescription": "]] .. dcm.RTPlanDescription .. [[", ]]);
          end
          if not isempty(dcm.PrescriptionDescription) then
            print([[ "PrescriptionDescription": "]] .. dcm.PrescriptionDescription .. [[", ]]);
          end
          if not isempty(dcm.RTPlanDate) then
            print([[ "RTPlanDate": "]] .. dcm.RTPlanDate .. [[", ]]);
          end

        elseif modality == 'RTDOSE' then
          if not isempty(dcm.DoseUnits) then
            print([[ "DoseUnits": "]] .. dcm.DoseUnits .. [[", ]]);
          end
          if not isempty(dcm.DoseType) then
            print([[ "DoseType": "]] .. dcm.DoseType .. [[", ]]);
          end
          if not isempty(dcm.DoseComment) then
            print([[ "DoseComment": "]] .. dcm.DoseComment .. [[", ]]);
          end
          if not isempty(dcm.DoseSummationType) then
            print([[ "DoseSummationType": "]] .. dcm.DoseSummationType .. [[", ]]);
          end
          if not isempty(dcm.InstanceCreationDate) then
            print([[ "InstanceCreationDate": "]] .. dcm.InstanceCreationDate .. [[", ]]);
          end

        elseif modality == 'RTSTRUCT' then
          if not isempty(dcm.StructureSetLabel) then
            print([[ "StructureSetLabel": "]] .. dcm.StructureSetLabel .. [[", ]]);
          end
          if not isempty(dcm.StructureSetName) then
            print([[ "StructureSetName": "]] .. dcm.StructureSetName .. [[", ]]);
          end
          if not isempty(dcm.StructureSetDescription) then
            print([[ "StructureSetDescription": "]] .. dcm.StructureSetDescription .. [[", ]]);
          end
          if not isempty(dcm.StructureSetDate) then
            print([[ "StructureSetDate": "]] .. dcm.StructureSetDate .. [[", ]]);
          end

        elseif modality == 'RTIMAGE' then
          if not isempty(dcm.RTImageLabel) then
            print([[ "RTImageLabel": "]] .. dcm.RTImageLabel .. [[", ]]);
          end
          if not isempty(dcm.RTImageName) then
            print([[ "RTImageName": "]] .. dcm.RTImageName .. [[", ]]);
          end
          if not isempty(dcm.RTImageDescription) then
            print([[ "RTImageDescription": "]] .. dcm.RTImageDescription .. [[", ]]);
          end
          if not isempty(dcm.InstanceCreationDate) then
            print([[ "InstanceCreationDate": "]] .. dcm.InstanceCreationDate .. [[", ]]);
          end
        end
      end
    end

    print([[ "Modality": "]] .. modality .. [[" } ]]); -- end of series object

    if i ~= #series then
      if series[i+1].StudyInstanceUID == series[i].StudyInstanceUID then
        print([[, ]]); -- there will be nex series object
      end
    end
  end
  
  if #series > 0 then
    print([[ ] } ]]); -- end of series collection and end of study object
  end
end

print([[ ] } ]]); -- end of studies collection and end of json obj
