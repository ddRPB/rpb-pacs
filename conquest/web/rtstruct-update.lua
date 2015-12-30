-- This script is querying ConQuest PACS in order to retrieve
-- DICOM RTSTRUCT instance restricted via QueryString parameters
-- and update specified ROIName with provided new value

local patientid = CGI('patientidmatch');
local studyuid = CGI('studyUID');
local seriesuid = CGI('seriesUID');
local instanceuid = CGI('instanceUID');
local roiname = CGI('roiname');
local roinumber = CGI('roinumber');
local value = CGI('value');

-- Functions declaration

function queryinstance()
  local rtstructs, b, s

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

  rtstructs = dicomquery(s, 'IMAGE', b)

  for i = 0, #rtstructs-1 do

   local sop = rtstructs[i].SOPInstanceUID
   local imagelocation = patientid..':'..sop

   servercommand('lua:'.."modified = false; structs=DicomObject:new(); structs:Read('"..imagelocation.."'); if (structs.Modality == 'RTSTRUCT') then for i = 0, #structs.StructureSetROISequence-1 do if (structs.StructureSetROISequence[i].ROIName == '"..roiname.."' and structs.StructureSetROISequence[i].ROINumber == '"..roinumber.."') then structs.StructureSetROISequence[i].ROIName = '"..value.."'; modified=true; end; end; if modified == true then structs:AddImage(); end; end;");

  end;
end;   

-- RESPONSE

HTML('Content-type: application/json\n');
queryinstance()       
