-- This script is querying ConQuest PACS in order to retrieve
-- DICOM RTPLAN instance restricted via QueryString parameters
-- and fix DoseReferenceStructureType for Hyperion plans
-- and fix ReviewerName for approved plans

local patientid = CGI('patientidmatch');
local studyuid = CGI('studyUID');
local seriesuid = CGI('seriesUID');
local instanceuid = CGI('instanceUID');

-- Functions declaration

function queryinstance()
  local rtplan, b, s

  if source == '(local)' then
    s = servercommand('get_param:MyACRNema')
  else
    s = source;
  end

  b = DicomObject:new()
  b.PatientID = patientid
  b.StudyInstanceUID = studyuid
  b.SeriesInstanceUID = seriesuid
  b.SOPInstanceUID = instanceuid

  rtplan = dicomquery(s, 'IMAGE', b)

  for i = 0, #rtplan-1 do

   local sop = rtplan[i].SOPInstanceUID
   local imagelocation = patientid..':'..sop

   servercommand('lua:'.."modified = false; plan=DicomObject:new(); plan:Read('"..imagelocation.."'); if (plan.Modality == 'RTPLAN') then if (plan.ManufacturerModelName == 'HYPERION') then for i = 0, #plan.DoseReferenceSequence-1 do if (plan.DoseReferenceSequence[i].DoseReferenceStructureType == 'VOLUME') then plan.DoseReferenceSequence[i].DoseReferenceStructureType = 'SITE'; modified = true; end; end; end; if (plan.ApprovalStatus == 'APPROVED' and plan.ReviewerName == '') then plan.ReviewerName = 'PN'; modified = true; end; if (modified == true) then plan:AddImage(); end; end;");

  end;
end;   

-- RESPONSE

HTML('Content-type: application/json\n');
queryinstance()
