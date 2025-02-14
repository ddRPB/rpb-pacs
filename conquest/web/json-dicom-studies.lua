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

function sequenceIsEmpty(seq)
  return seq == nil or #seq == 0;
end

function startswith(s, start)
  return s:sub(1, #start) == start
end

function endswith(s, ending)
  return ending == "" or s:sub(-#ending) == ending
end

function escapeStr(s)
  local inChar  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'};
  local outChar = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'} ;
  for i, c in ipairs(inChar) do
    s = s:gsub(c, '\\' .. outChar[i]);
  end
  return s;
end

function stringify(s)
  return '"' .. escapeStr(s) .. '"';
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
  seriestime = CGI('SeriesTime');
else
  seriestime = oldseriestime;
end

local studydescription = CGI('StudyDescription');
local targetaet = CGI('TargetAET');
local rtdetails = CGI('RTDetails');
local mrdetails = CGI('MRDetails');

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
    q.StudyDescription = studydescription;
    q.StudyDate = studydate;
    q.StudyTime = '';
    q.SeriesInstanceUID = seriesuid;
    q.SeriesNumber = '';
    q.SeriesDescription = '';
    q.SeriesDate = '';
    q.SeriesTime = seriestime;
    q.Modality = modality;
    q.FrameOfReferenceUID = '';
    q.Manufacturer = '';
    q.ReferringPhysicianName = '';
    q.ManufacturerModelName = '';
    q.BodyPartExamined = '';

    -- query specific source node
    if not isempty(targetaet) then
        series = dicomquery(targetaet, 'SERIES', q);
    else -- act as proxy and query all source nodes
        series = dicomquery(s, 'SERIES', q);
    end
    -- convert returned DDO (userdata) to table; needed to allow table.sort
    seriest = {};
    for i = 0, #series-1 do
      seriest[i+1] = {};
      seriest[i+1].PatientID = series[i].PatientID;
      seriest[i+1].StudyInstanceUID = series[i].StudyInstanceUID;
      seriest[i+1].StudyDescription = series[i].StudyDescription;
      seriest[i+1].StudyDate = series[i].StudyDate;
      seriest[i+1].StudyTime = series[i].StudyTime;
      seriest[i+1].SeriesInstanceUID = series[i].SeriesInstanceUID;
      seriest[i+1].SeriesNumber = series[i].SeriesNumber;
      seriest[i+1].SeriesDescription = series[i].SeriesDescription;
      seriest[i+1].SeriesDate = series[i].SeriesDate;
      seriest[i+1].SeriesTime = series[i].SeriesTime;
      seriest[i+1].Modality = series[i].Modality;
      seriest[i+1].FrameOfReferenceUID = series[i].FrameOfReferenceUID;
      seriest[i+1].Manufacturer = series[i].Manufacturer;
      seriest[i+1].ReferringPhysicianName = series[i].ReferringPhysicianName;
      seriest[i+1].ManufacturerModelName = series[i].ManufacturerModelName;
      seriest[i+1].BodyPartExamined = series[i].BodyPartExamined;
    end
  end

  return seriest;
end

function movesop(fromPacs, toPacs, pid, stuid, seuid, sopuid)
  
  if not isempty(pid) and pid ~= '*' then
    if not isempty(stuid) and stuid ~= '*' then
      if not isempty(seuid) and seuid ~= '*' then
        if not isempty(sopuid) and sopuid ~= '*' then
          m = newdicomobject();
          m.PatientID = pid;
          m.StudyInstanceUID = stuid;
          m.SeriesInstanceUID = seuid;
          m.SOPInstanceUID = sopuid;
          m.QueryRetrieveLevel = 'IMAGE';
          
          -- last parameter '0' is StudyRoot ('1' is PatientRoot)
          dicommove(fromPacs, toPacs, m, 0);
          return true;
        end
      end
    end
  end
  
  return false;
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

        -- query specific source node
        if not isempty(targetaet) then
            images = dicomquery(targetaet, 'IMAGE', q);
        else -- act as proxy and query all source nodes
            images = dicomquery(s, 'IMAGE', q);
        end
      end
    end
  end

  local dcm;
  if #images > 0 then

    -- read the full DICOM object
    dcm = newdicomobject();
    readdicom(dcm, stuid  .. '\\' .. seuid ..  '\\' .. images[0].SOPInstanceUID);
    
    -- when reading failed
    if isempty(dcm.SOPInstanceUID) then
      
      -- try to fetch the local copy from specific source node with cmove
      if not isempty(targetaet) then
        movesop(targetaet, s, pid, stuid, seuid, images[0].SOPInstanceUID)
      else -- try to fetch the local copy from all proxied source nodes with cmove
        movesop(s, s, pid, stuid, seuid, images[0].SOPInstanceUID)
      end

      -- try to read again (should be locally available)
      readdicom(dcm, stuid  .. '\\' .. seuid ..  '\\' .. images[0].SOPInstanceUID);
    end
  end

  return dcm;
end

-- RT objects printing

function printRtStruct(rtStruct)
  if not isempty(rtStruct.StructureSetLabel) then
    print([[ "StructureSetLabel": "]] .. rtStruct.StructureSetLabel .. [[", ]]);
  end
  if not isempty(rtStruct.StructureSetName) then
    print([[ "StructureSetName": "]] .. rtStruct.StructureSetName .. [[", ]]);
  end
  if not isempty(rtStruct.StructureSetDescription) then
    print([[ "StructureSetDescription": ]] .. stringify(rtStruct.StructureSetDescription) .. [[, ]]);
  end
  if not isempty(rtStruct.StructureSetDate) then
    print([[ "StructureSetDate": "]] .. rtStruct.StructureSetDate .. [[", ]]);
  end
end

function printRtPlan(rtPlan)
  if not isempty(rtPlan.RTPlanLabel) then
    print([[ "RTPlanLabel": "]] .. rtPlan.RTPlanLabel .. [[", ]]);
  end
  if not isempty(rtPlan.RTPlanName) then
    print([[ "RTPlanName": "]] .. rtPlan.RTPlanName .. [[", ]]);
  end
  if not isempty(rtPlan.RTPlanDescription) then
    print([[ "RTPlanDescription": ]] .. stringify(rtPlan.RTPlanDescription) .. [[, ]]);
  end
  if not isempty(rtPlan.PrescriptionDescription) then
    print([[ "PrescriptionDescription": ]] .. stringify(rtPlan.PrescriptionDescription) .. [[, ]]);
  end
  if not isempty(rtPlan.RTPlanDate) then
    print([[ "RTPlanDate": "]] .. rtPlan.RTPlanDate .. [[", ]]);
  end
  if not isempty(rtPlan.RTPlanGeometry) then
    print([[ "RTPlanGeometry": "]] .. rtPlan.RTPlanGeometry .. [[", ]]);
  end
end

function printRtDose(rtDose)
  if not isempty(rtDose.DoseUnits) then
    print([[ "DoseUnits": "]] .. rtDose.DoseUnits .. [[", ]]);
  end
  if not isempty(rtDose.DoseType) then
    print([[ "DoseType": "]] .. rtDose.DoseType .. [[", ]]);
  end
  if not isempty(rtDose.DoseComment) then
    print([[ "DoseComment": "]] .. rtDose.DoseComment .. [[", ]]);
  end
  if not isempty(rtDose.DoseSummationType) then
    print([[ "DoseSummationType": "]] .. rtDose.DoseSummationType .. [[", ]]);
  end
  if not isempty(rtDose.InstanceCreationDate) then
    print([[ "InstanceCreationDate": "]] .. rtDose.InstanceCreationDate .. [[", ]]);
  end
end

function printRtImage(rtImage)
  if not isempty(rtImage.RTImageLabel) then
    print([[ "RTImageLabel": "]] .. rtImage.RTImageLabel .. [[", ]]);
  end
  if not isempty(rtImage.RTImageName) then
    print([[ "RTImageName": "]] .. rtImage.RTImageName .. [[", ]]);
  end
  if not isempty(rtImage.RTImageDescription) then
    print([[ "RTImageDescription": ]] .. stringify(rtImage.RTImageDescription) .. [[, ]]);
  end
  if not isempty(rtImage.InstanceCreationDate) then
    print([[ "InstanceCreationDate": "]] .. rtImage.InstanceCreationDate .. [[", ]]);
  end
end

function printMr(mr)
  if not isempty(mr.ContrastBolusAgent) then
    print([[ "ContrastBolusAgent": "]] .. mr.ContrastBolusAgent .. [[", ]]);
  end
  if not isempty(mr.ScanningSequence) then
    print([[ "ScanningSequence": ]] .. stringify(mr.ScanningSequence) .. [[, ]]);
  end
  if not isempty(mr.SequenceVariant) then
    print([[ "SequenceVariant": ]] .. stringify(mr.SequenceVariant) .. [[, ]]);
  end
  if not isempty(mr.ScanOptions) then
    print([[ "ScanOptions": ]] .. stringify(mr.ScanOptions) .. [[, ]]);
  end
  if not isempty(mr.MRAcquisitionType) then
    print([[ "MRAcquisitionType": ]] .. stringify(mr.MRAcquisitionType) .. [[, ]]);
  end
  if not isempty(mr.SequenceName) then
    print([[ "SequenceName": "]] .. mr.SequenceName .. [[", ]]);
  end
  if not isempty(mr.AngioFlag) then
    print([[ "AngioFlag": ]] .. stringify(mr.AngioFlag) .. [[, ]]);
  end
  if not isempty(mr.SliceThickness) then
    print([[ "SliceThickness": "]] .. mr.SliceThickness .. [[", ]]);
  end
  if not isempty(mr.RepetitionTime) then
    print([[ "RepetitionTime": "]] .. mr.RepetitionTime .. [[", ]]);
  end
  if not isempty(mr.EchoTime) then
    print([[ "EchoTime": "]] .. mr.EchoTime .. [[", ]]);
  end
  if not isempty(mr.InversionTime) then
    print([[ "InversionTime": "]] .. mr.InversionTime .. [[", ]]);
  end
  if not isempty(mr.NumberOfAverages) then
    print([[ "NumberOfAverages": "]] .. mr.NumberOfAverages .. [[", ]]);
  end
  if not isempty(mr.ImagingFrequency) then
    print([[ "ImagingFrequency": "]] .. mr.ImagingFrequency .. [[", ]]);
  end
  if not isempty(mr.ImagedNucleus) then
    print([[ "ImagedNucleus": "]] .. mr.ImagedNucleus .. [[", ]]);
  end
  if not isempty(mr.EchoNumbers) then
    print([[ "EchoNumbers": "]] .. mr.EchoNumbers .. [[", ]]);
  end
  if not isempty(mr.MagneticFieldStrength) then
    print([[ "MagneticFieldStrength": "]] .. mr.MagneticFieldStrength .. [[", ]]);
  end
  if not isempty(mr.NumberOfPhaseEncodingSteps) then
    print([[ "NumberOfPhaseEncodingSteps": "]] .. mr.NumberOfPhaseEncodingSteps .. [[", ]]);
  end
  if not isempty(mr.EchoTrainLength) then
    print([[ "EchoTrainLength": "]] .. mr.EchoTrainLength .. [[", ]]);
  end
  if not isempty(mr.PercentSampling) then
    print([[ "PercentSampling": "]] .. mr.PercentSampling .. [[", ]]);
  end
  if not isempty(mr.PercentPhaseFieldOfView) then
    print([[ "PercentPhaseFieldOfView": "]] .. mr.PercentPhaseFieldOfView .. [[", ]]);
  end
  if not isempty(mr.ProtocolName) then
    print([[ "ProtocolName": "]] .. mr.ProtocolName .. [[", ]]);
  end
  if not isempty(mr.InPlanePhaseEncodingDirection) then
    print([[ "InPlanePhaseEncodingDirection": ]] .. stringify(mr.InPlanePhaseEncodingDirection) .. [[, ]]);
  end
  if not isempty(mr.FlipAngle) then
    print([[ "FlipAngle": "]] .. mr.FlipAngle .. [[", ]]);
  end
  if not isempty(mr.PatientPosition) then
    print([[ "PatientPosition": ]] .. stringify(mr.PatientPosition) .. [[, ]]);
  end
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

      if not isempty(series[i].StudyDescription) then
        -- Percentage sign is a special character in lua, that is why I need to mask it
        maskedDescription = string.gsub(series[i].StudyDescription, "%%", "%%%%");
        print([[ "StudyDescription": "]] .. maskedDescription .. [[", ]]);
      end

      if not isempty(series[i].StudyDate ) then
        print([[ "StudyDate": "]] .. series[i].StudyDate .. [[", ]]);
      end

      if not isempty(series[i].StudyTime) then
        print([[ "StudyTime": "]] .. series[i].StudyTime .. [[", ]]);
      end

      print ([[ "Series" : [ ]]); -- begin of series collection
    end

    seriesInstanceUid = series[i].SeriesInstanceUID;

    -- DICOM series json collection
    print([[ { "SeriesInstanceUID" : "]] .. seriesInstanceUid .. [[", ]]); -- begin of series object

    if not isempty(series[i].SeriesNumber) then
      print ([[ "SeriesNumber": "]] .. series[i].SeriesNumber .. [[", ]]);
    end

    if not isempty(series[i].SeriesDescription) then
      -- Percentage sign is a special character in lua, that is why I need to mask it
      maskedDescription = string.gsub(series[i].SeriesDescription, "%%", "%%%%");
      print([[ "SeriesDescription": "]] .. maskedDescription .. [[", ]]);
    end

    if not isempty(series[i].SeriesDate) then
      print([[ "SeriesDate": "]] .. series[i].SeriesDate .. [[", ]]);
    end

    if not isempty(series[i].SeriesTime) then
      print([[ "SeriesTime": "]] .. series[i].SeriesTime .. [[", ]]);
    end

    if not isempty(series[i].FrameOfReferenceUID) then
      print([[ "FrameOfReferenceUID": "]] .. series[i].FrameOfReferenceUID .. [[", ]]);
    end

    if not isempty(series[i].Manufacturer) then
      print([[ "Manufacturer": "]] .. series[i].Manufacturer .. [[", ]]);
    end

    if not isempty(series[i].ReferringPhysicianName) then
      print([[ "ReferringPhysicianName": "]] .. series[i].ReferringPhysicianName .. [[", ]]);
    end

    if not isempty(series[i].ManufacturerModelName) then
      print([[ "ManufacturerModelName": "]] .. series[i].ManufacturerModelName .. [[", ]]);
    end

    if not isempty(series[i].BodyPartExamined) then
      print([[ "BodyPartExamined": ]] .. stringify(series[i].BodyPartExamined) .. [[, ]]);
    end

    modality = series[i].Modality;

    -- Exclude fetching of RT details for reporting if explicitly requested
    printRTDetails = true;
    if not isempty(rtdetails) then
        if rtdetails == 'Yes' then
            printRTDetails = true;
        elseif rtdetails  == 'No' then
            printRTDetails = false;
        end
    end
    -- Include fetching of MR details for reporting if explicitly requested
    printMRDetails = false;
    if not isempty(mrdetails) then
        if mrdetails == 'Yes' then
            printMRDetails = true;
        elseif mrdetails == 'No' then
            printMRDetails = false;
        end
    end

    -- RTIMAGE is excluded from detailed JSON reporting
    if (modality == 'RTPLAN' or modality == 'RTDOSE' or modality == 'RTSTRUCT') and printRTDetails then
      dcm = getoneinstance(patientid, studyInstanceUid, seriesInstanceUid);

      if dcm ~= nil then

        if not isempty(dcm.ImageType) then
          print([[ "ImageType": ]] .. stringify(dcm.ImageType) .. [[, ]]);
        end

        if modality == 'RTPLAN' then
          printRtPlan(dcm);
        elseif modality == 'RTDOSE' then
          printRtDose(dcm);
        elseif modality == 'RTSTRUCT' then
          printRtStruct(dcm);
        end
        -- elseif modality == 'RTIMAGE' then
        --   printRtImage(dcm);
        -- end
      end
    end

    -- MR detailed JSON reporting
    if modality == 'MR' and printMRDetails and not endswith(series[i].SeriesDescription, "_TENSOR") and not startswith(series[i].SeriesDescription, "svs_se") and not endswith(series[i].SeriesDescription, "PRESTO_KM SENSE") then
      dcm = getoneinstance(patientid, studyInstanceUid, seriesInstanceUid);

      if not isempty(dcm.ImageType) then
        print([[ "ImageType": ]] .. stringify(dcm.ImageType) .. [[, ]]);
      end
  
      if dcm ~= nil then
        printMr(dcm);
      end
    end

    print([[ "Modality": "]] .. modality .. [[" } ]]); -- end of series object

    if i ~= #series then
      if series[i+1].StudyInstanceUID == series[i].StudyInstanceUID then
        print([[, ]]); -- there will be next series object
      end
    end
  end
  
  if #series > 0 then
    print([[ ] } ]]); -- end of series collection and end of study object
  end
end

print([[ ] } ]]); -- end of studies collection and end of json obj
