--TODO: check if reading StudyDescription from DB instead of DICOM helps with special character encoding (ä,..)
--TODO: or other way of handling special characters as ASCII

print('Content-Type: application/xml\n')

local patid = string.gsub(study2, ':.*$', '')
local studyuid = string.gsub(study2, '^.*:', '')
local proxy = CGI('proxy')
local session = CGI('session')

local q = DicomObject:new()
q.QueryRetrieveLevel = 'SERIES'
q.PatientID = patid
q.StudyInstanceUID = studyuid
q.PatientBirthDate = ''
q.PatientName = ''
q.StudyDescription = ''
q.StudyDate = ''
q.StudyTime = ''
q.SeriesInstanceUID = ''
q.SeriesDescription = ''
q.SeriesNumber = ''
q.Modality = ''
r = dicomquery(servercommand('get_param:MyACRNema'), 'SERIES', q)

local s = DicomObject:new()

print([[
<?xml version="1.0" encoding="utf-8" ?>
<manifest xmlns="http://www.weasis.org/xsd/2.5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
 <arcQuery additionnalParameters="" arcId="1001" baseUrl="]]..proxy..[[/pacs/wado.faces;sessionid=]]..session..[[" requireOnlySOPInstanceUID="false">
  <Patient PatientID="]]..patid..[[" PatientName="]]..r[0].PatientName..[[" PatientBirthDate="]]..r[0].PatientBirthDate..[[" >
    <Study StudyInstanceUID="]]..r[0].StudyInstanceUID..[[" StudyDescription="]]..r[0].StudyDescription..[[" StudyDate="]]..r[0].StudyDate..[[" StudyTime="]]..r[0].StudyTime..[[" >
]])

for i=0, #r-1 do
  print([[
      <Series SeriesInstanceUID="]]..r[i].SeriesInstanceUID..[[" SeriesDescription="]]..r[i].SeriesDescription..[[" SeriesNumber="]]..r[i].SeriesNumber..[[" Modality="]]..r[i].Modality..[[" >
  ]])

  s.QueryRetrieveLevel = 'IMAGE'
  s.SOPInstanceUID = ''
  s.ImageNumber = ''
  s.SeriesInstanceUID = r[i].SeriesInstanceUID
  t = dicomquery(servercommand('get_param:MyACRNema'), 'IMAGE', s)
  for j=0, #t-1 do
    print([[<Instance SOPInstanceUID="]]..t[j].SOPInstanceUID..[[" InstanceNumber="]]..j..[[" />]])
  end

  print([[
      </Series>
]])
end

print([[
    </Study>
  </Patient>
 </arcQuery>
</manifest>
]])
