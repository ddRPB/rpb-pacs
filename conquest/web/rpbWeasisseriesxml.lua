--TODO: check if reading StudyDescription and SeriesDescription from DB instead of DICOM helps with special character encoding (ä,..)
--TODO: or other way of handling special characters as ASCII

print('Content-Type: application/xml\n')

local patid = string.gsub(series2, ':.*$', '')
local seriesuid = string.gsub(series2, '^.*:', '')
local proxy = CGI('proxy')
local session = CGI('session')

local q = DicomObject:new()
q.QueryRetrieveLevel = 'IMAGE'
q.PatientID = patid
q.SeriesInstanceUID = seriesuid
q.SOPInstanceUID = ''
q.PatientBirthDate = ''
q.PatientName = ''
q.StudyInstanceUID = ''
q.StudyDescription = ''
q.StudyDate = ''
q.StudyTime = ''
q.SeriesDescription = ''
q.SeriesNumber = ''
q.Modality = ''
q.ImageNumber = ''
r = dicomquery(servercommand('get_param:MyACRNema'), 'IMAGE', q)

print([[
<?xml version="1.0" encoding="utf-8" ?>
<manifest xmlns="http://www.weasis.org/xsd/2.5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
 <arcQuery additionnalParameters="" arcId="1001" baseUrl="]]..proxy..[[/pacs/wado.faces;sessionid=]]..session..[[" requireOnlySOPInstanceUID="false">
  <Patient PatientID="]]..patid..[[" PatientName="]]..r[0].PatientName..[[" PatientBirthDate="]]..r[0].PatientBirthDate..[[" >
    <Study StudyInstanceUID="]]..r[0].StudyInstanceUID..[[" StudyDescription="]]..r[0].StudyDescription..[[" StudyDate="]]..r[0].StudyDate..[[" StudyTime="]]..r[0].StudyTime..[[" >
      <Series SeriesInstanceUID="]]..r[0].SeriesInstanceUID..[[" SeriesDescription="]]..r[0].SeriesDescription..[[" SeriesNumber="]]..r[0].SeriesNumber..[[" Modality="]]..r[0].Modality..[[" >
]])

for i=0, #r-1 do
  print([[<Instance SOPInstanceUID="]]..r[i].SOPInstanceUID..[[" InstanceNumber="]]..i..[[" />]])
end

print([[
      </Series>
    </Study>
  </Patient>
 </arcQuery>
</manifest>
]])
