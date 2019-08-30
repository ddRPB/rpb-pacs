-- This script is querying ConQuest PACS in order to retrieve
-- DICOM RTSTRUCT instance restricted via QueryString parameters
-- and update specified ROIName with provided new value

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');
local seriesuid = CGI('SeriesUID');
local sopuid = CGI('SopUID');
local roiname = CGI('RoiName');
local roinumber = CGI('RoiNumber');
local value = CGI('Value');

-- Functions declaration

function isempty(s)
  return s == nil or s == '';
end

function queryonefile()
  local images, imaget, q, s;

  if source == '(local)' then
    s = servercommand('get_param:MyACRNema');
  else
    s = source;
  end

  if not isempty(patientid) then
    if not isempty(studyuid) then
      if not isempty(seriesuid) then
        if not isempty(sopuid) then

          q = newdicomobject();
          q.PatientID = patientid;
          q.StudyInstanceUID = studyuid;
          q.SeriesInstanceUID = seriesuid;
          q.SOPInstanceUID = sopuid;

          images = dicomquery(s, 'IMAGE', q);

          -- convert returned DDO (userdata) to table; needed to allow table.sort
          imaget = {};
          for i = 0, #images-1 do
            imaget[i+1] = {};
            imaget[i+1].SOPInstanceUID = images[i].SOPInstanceUID;
          end
        end
      end
    end
  end

  return imaget;
end

function updatertstruct(images)
  if not isempty(roinumber) then
    for i = 1, #images do
      local imagelocation = patientid .. ':' .. images[i].SOPInstanceUID;
      servercommand('lua:'.."modified = false; structs=DicomObject:new(); structs:Read('"..imagelocation.."'); if (structs.Modality == 'RTSTRUCT') then for i = 0, #structs.StructureSetROISequence-1 do if (structs.StructureSetROISequence[i].ROIName == '"..roiname.."' and structs.StructureSetROISequence[i].ROINumber == '"..roinumber.."') then structs.StructureSetROISequence[i].ROIName = '"..value.."'; modified=true; end; end; if modified == true then structs:AddImage(); end; end;");
      return true;
    end
  end

  return false;
end

-- RESPONSE

print('Content-type: application/json\n');

local images = queryonefile();

local count = 0;
local updated = 0;

if images ~= nil then
  count = #images;
  if updatertstruct(images) then
    updated = updated + 1;
  end
end

print([[ { "FoundFilesCount": ]] .. count .. [[, "UpdatedFilesCount": ]] .. updated .. [[ } ]]);
