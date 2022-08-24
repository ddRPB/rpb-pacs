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

function sequenceIsEmpty(seq)
  return seq == nil or #seq == 0;
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

function getConfigItem(item)
  return gpps('sscscp', item, '');
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

function movesop(s, pid, stuid, seuid, sopuid)

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
          dicommove(s, s, m, 0);
          return true;
        end
      end
    end
  end

  return false;
end

function getinstance(pid, stuid, seuid, sopuid)

  local s;

  if source == '(local)' then
    s = servercommand('get_param:MyACRNema');
  else
    s = source;
  end
  
  -- read the full DICOM object
  local dcm;
  dcm = newdicomobject();
  readdicom(dcm, stuid  .. '\\' .. seuid ..  '\\' .. sopuid);

  -- when reading failed
  if isempty(dcm.SOPInstanceUID) then

    -- try to fetch  the local copy from source nodes with cmove
    movesop(s, pid, stuid, seuid, sopuid)

    -- try to read again (should be locally available)
    readdicom(dcm, stuid  .. '\\' .. seuid ..  '\\' .. sopuid);
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

  -- ROIs
  if not sequenceIsEmpty(rtStruct.StructureSetROISequence) then
    print([[ "ROIs": [ ]]); -- start of ROI array
    for i = 0, #rtStruct.StructureSetROISequence-1 do
      roiElement = rtStruct.StructureSetROISequence[i];

      if not isempty(roiElement.ROINumber) then
        print([[ { "ROINumber": "]] .. roiElement.ROINumber .. [[", ]]);
      end
      if not isempty(roiElement.ReferencedFrameOfReferenceUID) then
        print([[ "ReferencedFrameOfReferenceUID": "]] .. roiElement.ReferencedFrameOfReferenceUID .. [[", ]]);
      end
      if not isempty(roiElement.ROIName) then
        print([[ "ROIName": ]] .. stringify(roiElement.ROIName) .. [[, ]]);
      end
      if not isempty(roiElement.ROIDescription) then
        print([[ "ROIDescription": ]] .. stringify(roiElement.ROIDescription) .. [[, ]]);
      end
      if not isempty(roiElement.ROIVolume) then
        print([[ "ROIVolume": "]] .. roiElement.ROIVolume .. [[", ]]);
      end

      roiGenerationAlgorithm = '';
      if not isempty(roiElement.ROIGenerationAlgorithm) then
        roiGenerationAlgorithm = roiElement.ROIGenerationAlgorithm;
      end
      print([[ "ROIGenerationAlgorithm": "]] .. roiGenerationAlgorithm .. [[" } ]]); -- last attribute

      -- there will be next ROI object
      if i ~= #rtStruct.StructureSetROISequence-1 then
        print([[, ]]);
      end
    end

    print([[ ], ]]); -- end of ROI array
  end

  -- ROI observations
  if not sequenceIsEmpty(rtStruct.RTROIObservationsSequence) then
    print([[ "RTROIObservations": [ ]]); -- start of ROI Observation array
    for i = 0, #rtStruct.RTROIObservationsSequence-1 do
      roiObservationElement = rtStruct.RTROIObservationsSequence[i];

      if not isempty(roiObservationElement.ObservationNumber) then
        print([[ { "ObservationNumber": "]] .. roiObservationElement.ObservationNumber .. [[", ]]);
      end
      if not isempty(roiObservationElement.ReferencedROINumber) then
        print([[ "ReferencedROINumber": "]] .. roiObservationElement.ReferencedROINumber .. [[", ]]);
      end
      if not isempty(roiObservationElement.ROIObservationLabel) then
        print([[ "ROIObservationLabel": ]] .. stringify(roiObservationElement.ROIObservationLabel) .. [[, ]]);
      end
      if not isempty(roiObservationElement.ROIObservationDescription) then
        print([[ "ROIObservationDescription": ]] .. stringify(roiObservationElement.ROIObservationDescription) .. [[, ]]);
      end

      rtRoiInterpretedType = '';
      if not isempty(roiObservationElement.RTROIInterpretedType) then
        rtRoiInterpretedType = roiObservationElement.RTROIInterpretedType;
      end
      print([[ "RTROIInterpretedType": "]] .. rtRoiInterpretedType .. [[" } ]]); -- last attribute

      -- there will be next ROI observation object
      if i ~= #rtStruct.RTROIObservationsSequence-1 then
        print([[, ]]);
      end
    end

    print([[ ], ]]); -- end of ROI array
  end

  -- only the RT related references to imaging series
  referencedFrameOfReferenceUID = '';
  referencedRtSeriesUid = '';

  if not sequenceIsEmpty(rtStruct.ReferencedFrameOfReferenceSequence) then
    for i = 0, #rtStruct.ReferencedFrameOfReferenceSequence-1 do

      ref = rtStruct.ReferencedFrameOfReferenceSequence[i];
      if not sequenceIsEmpty(ref.RTReferencedStudySequence) then

        if not isempty(ref.FrameOfReferenceUID) then
          referencedFrameOfReferenceUID = ref.FrameOfReferenceUID;
        end

        for j = 0, #ref.RTReferencedStudySequence-1 do

          rtStudyElement = ref.RTReferencedStudySequence[j];
          if not sequenceIsEmpty(rtStudyElement.RTReferencedSeriesSequence) then

            for k = 0, #rtStudyElement.RTReferencedSeriesSequence-1 do

              rtSeriesElement = rtStudyElement.RTReferencedSeriesSequence[k];
              if not isempty(rtSeriesElement.SeriesInstanceUID) then
                referencedRtSeriesUid = rtSeriesElement.SeriesInstanceUID;
                break;
              end

            end
          end

          -- found referenced imaging (one should be enough)
          if not isempty(referencedRtSeriesUid) then
            break;
          end
        end
      end

      -- found referenced frame of reference (one should be enough)
      if not isempty(referencedFrameOfReferenceUID) then
        break;
      end
    end
  end

  if not isempty(referencedFrameOfReferenceUID) then
    print([[ "ReferencedFrameOfReferenceUID": "]] .. referencedFrameOfReferenceUID.. [[", ]]);
  end
  if not isempty(referencedRtSeriesUid) then
    print([[ "ReferencedRTSeriesUID": "]] .. referencedRtSeriesUid.. [[", ]]);
  end
  if not isempty(rtPlan.ApprovalStatus) then
    print([[ "ApprovalStatus": "]] .. rtPlan.ApprovalStatus .. [[", ]]);
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

  referencedRtStructUid = '';
  if not sequenceIsEmpty(rtPlan.ReferencedStructureSetSequence) then
    for i = 0, #rtPlan.ReferencedStructureSetSequence-1 do
      rtStruct = rtPlan.ReferencedStructureSetSequence[i];
      if not isempty(rtStruct.ReferencedSOPInstanceUID) then
        referencedRtStructUid = rtStruct.ReferencedSOPInstanceUID;
        break;
      end
    end
  end

  referencedRtDoseUid = '';
  if not sequenceIsEmpty(rtPlan.ReferencedRTDoseSequence) then
    for i = 0, #rtPlan.ReferencedRTDoseSequence-1 do
      rtDose = rtPlan.ReferencedRTDoseSequence[i];
      if not isempty(rtDose.ReferencedSOPInstanceUID) then
        referencedRtDoseUid = rtDose.ReferencedSOPInstanceUID;
        break;
      end
    end
  end

  if not isempty(referencedRtStructUid) then
    print([[ "ReferencedRTStructUID": "]] .. referencedRtStructUid .. [[", ]]);
  end
  if not isempty(referencedRtDoseUid) then
    print([[ "ReferencedRTDoseUID": "]] .. referencedRtDoseUid .. [[", ]]);
  end
  if not isempty(rtPlan.ApprovalStatus) then
    print([[ "ApprovalStatus": "]] .. rtPlan.ApprovalStatus .. [[", ]]);
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

  referencedRtPlanUid = '';
  if not sequenceIsEmpty(rtDose.ReferencedRTPlanSequence) then
    for i = 0, #rtDose.ReferencedRTPlanSequence-1 do
      rtPlan = rtDose.ReferencedRTPlanSequence[i];
      if not isempty(rtPlan.ReferencedSOPInstanceUID) then
        referencedRtPlanUid = rtPlan.ReferencedSOPInstanceUID;
        break;
      end
    end
  end

  if not isempty(referencedRtPlanUid) then
    print([[ "ReferencedRTPlanUID": "]] .. referencedRtPlanUid .. [[", ]]);
  end
  if not isempty(rtPlan.ApprovalStatus) then
    print([[ "ApprovalStatus": "]] .. rtPlan.ApprovalStatus .. [[", ]]);
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

  referencedRtPlanUid = '';
  if not sequenceIsEmpty(rtImage.ReferencedRTPlanSequence) then
    for i = 0, #rtImage.ReferencedRTPlanSequence-1 do
      rtPlan = rtImage.ReferencedRTPlanSequence[i];
      if not isempty(rtPlan.ReferencedSOPInstanceUID) then
        referencedRtPlanUid = rtPlan.ReferencedSOPInstanceUID;
        break;
      end
    end
  end

  if not isempty(referencedRtPlanUid) then
    print([[ "ReferencedRTPlanUID": "]] .. referencedRtPlanUid .. [[", ]]);
  end
  if not isempty(rtPlan.ApprovalStatus) then
    print([[ "ApprovalStatus": "]] .. rtPlan.ApprovalStatus .. [[", ]]);
  end
end

-- RESPONSE

print('Content-type: application/json\n');

device = 'MAGDevice0';

local images = queryallimages();

print([[{ "Series": [ ]]); -- start of json obj, start of studies collection

if images ~= nil then

  table.sort(images, function(a, b) return a.SOPInstanceUID < b.SOPInstanceUID end);

  local files = queryallsizes();
  if files ~= nil then
    table.sort(files, function(a, b) return a.SOPInstanceUID < b.SOPInstanceUID end);
  end

  for i = 1, #images do
    
    -- If it is first series (there should always be just one series requested)
    if i == 1 then

      -- DICOM series json object
      print([[ { "SeriesInstanceUID": "]] .. images[i].SeriesInstanceUID .. [[", ]]);

      if not isempty(images[i].SeriesDescription) then
        -- Percentage sign is a special character in lua, that is why I need to mask it
        maskedDescription = string.gsub(images[i].SeriesDescription, "%%", "%%%%");
        print([[ "SeriesDescription": "]] .. maskedDescription .. [[", ]]);
      end

      modality = '';
      if not isempty(images[i].Modality) then
        modality = images[i].Modality;
        print([[ "Modality": "]] .. modality .. [[", ]]);
      end

      -- DICOM images collection
      print([[ "Images": [ ]]); -- begin of images collection
    end

    -- DICOM image json object
    sopInstanceUid = '';
    if not isempty(images[i].SOPInstanceUID) then
      sopInstanceUid = images[i].SOPInstanceUID;

      -- Determine size of the DICOM file
      local size;
      if files ~= nil and #files == #images then
        local file = io.open(getConfigItem(device) .. files[i].ObjectFile, "r");
        size = file:seek("end");
        io.close(file);
      end

      print([[ { ]]); -- start instance

      -- RT object - more details
      if modality == 'RTPLAN' or modality == 'RTDOSE' or modality == 'RTSTRUCT' or modality == 'RTIMAGE' then
        dcm = getinstance(patientid, studyuid, seriesuid, sopInstanceUid);

        if dcm ~= nil then

          if not isempty(dcm.ImageType) then
            print([[ "ImageType": ]] .. stringify(dcm.ImageType) .. [[, ]])
          end

          if modality == 'RTPLAN' then
            printRtPlan(dcm);
          elseif modality == 'RTDOSE' then
            printRtDose(dcm);
          elseif modality == 'RTSTRUCT' then
            printRtStruct(dcm);
          elseif modality == 'RTIMAGE' then
            printRtImage(dcm);
          end
        end
      end

      -- end instance
      if not isempty(size) then
        print([[ "SOPInstanceUID": "]] .. sopInstanceUid .. [[", ]]);
        print([[ "Size": "]] .. size .. [[" } ]]);
      else
        print([[ "SOPInstanceUID": "]] .. sopInstanceUid .. [[" } ]]);
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
