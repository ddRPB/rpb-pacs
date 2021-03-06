-- This script is querying ConQuest PACS in order to find out whether 
-- a specific DICOM file restricted via QueryString parameters exists
-- the data is reported in JSON format

local patientid = CGI('PatientID');
local studyuid = CGI('StudyUID');
local seriesuid = CGI('SeriesUID');
local sopuid = CGI('SopUID');

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

-- RESPONSE

print('Content-type: application/json\n');

local images = queryonefile();

local count = 0;
if images ~= nil then
  table.sort(images, function(a, b) return a.SOPInstanceUID < b.SOPInstanceUID end);
  count = #images;
end

print([[ { "FoundFilesCount": ]] .. count .. [[ } ]]);
