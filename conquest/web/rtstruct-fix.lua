-- This script is querying ConQuest PACS in order to retrieve
-- DICOM RTSTRUCT instance restricted via QueryString parameters
-- and fix ReviewerName for approved structs

local patientid = CGI('patientidmatch');
local studyuid = CGI('studyUID');
local seriesuid = CGI('seriesUID');
local instanceuid = CGI('instanceUID');

-- Functions declaration

function queryinstance()
  local rtstruct, b, s

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

  rtstruct = dicomquery(s, 'IMAGE', b)

  for i = 0, #rtstruct-1 do

   local sop = rtstruct[i].SOPInstanceUID
   local imagelocation = patientid..':'..sop

   servercommand('lua:'.."modified = false; struct=DicomObject:new(); struct:Read('"..imagelocation.."'); if (struct.Modality == 'RTSTRUCT' and struct.ApprovalStatus == 'APPROVED') then if (struct.ReviewerName == '') then struct.ReviewerName = 'PN'; modified = true; end; if (modified == true) then struct:AddImage(); end; end;");

  end;
end;

-- RESPONSE
HTML('Content-type: application/json\n');
queryinstance()
