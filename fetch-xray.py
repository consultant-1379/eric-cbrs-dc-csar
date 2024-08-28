imageListFile = open('Files/images.txt', 'r')
skippedScanFile= open('build/xray-reports/skipped_xray_scan_image_list.txt','a')

def xrayConfig(docker_image,arm_server,arm_server_xray):
    xray_to_scan=''
    xray_location = docker_image.replace(arm_server, arm_server_xray)
    xray_to_scan = "\r\n    - \"" + xray_location+'\"'
    xray_to_scan= xray_to_scan.replace('\n','')
    xrayConfigFile = open("xray_report.config", "a")
    xrayConfigFile.write(xray_to_scan)
    xrayConfigFile.close()


xray_skip_scan=''
total_cnt,skipped_cnt=0,0
skip_scan_image_list=['proj-common-assets-cd-released','proj-common-assets-cd','proj-pc-gs-released','proj-pc-rs-released','proj-exilis-released','proj-adp-eric-ctrl-bro-drop','proj-adp-certificate-management-released','proj-adp-eric-data-distributed-coordinator-ed-drop','proj-adp-eric-data-distributed-coordinator-ed-internal','proj-eric-oss-ddc-drop','proj-pc-gs-drop','proj-pc-released']
for IMAGE in imageListFile:
  total_cnt+=1
  image_tokens=IMAGE.split('/')
  arm_server=image_tokens[0]
  arm_repository=image_tokens[1]
  arm_dir=image_tokens[2]
  if (arm_repository in skip_scan_image_list) or  (arm_dir.startswith('eric-enm-sles-base')) :
    skipped_cnt+=1
    xray_skip_scan = xray_skip_scan  + IMAGE
  elif (arm_server == 'armdocker.rnd.ericsson.se'):
    if ((arm_repository == 'proj-enm') | (arm_repository == 'proj-exilis-released') | (arm_repository == 'proj-common-assets-cd-released') | (arm_repository == 'proj-eric-cbrs-dc-released') |(arm_repository == 'proj-eric-cbrs-dc-drop')):
      xrayConfig(IMAGE, arm_server, '- ARM-SELI/' + arm_repository + '-docker-global')
    else:
      xrayConfig(IMAGE, arm_server, '- ARM-SELI/docker-v2-global-' + arm_repository + '-xray-local')
  elif (arm_server == 'selndocker.mo.sw.ericsson.se')| (arm_server == 'serodocker.sero.gic.ericsson.se'):
    xrayConfig(IMAGE, arm_server, '- ARM-SERO/' + arm_repository + '-docker-local')
skippedScanFile.write(xray_skip_scan)

print("Scanning ",total_cnt-skipped_cnt,"out of ", total_cnt,"total images")
print("########   skipped Images List   ########")
print(xray_skip_scan)

imageListFile.close()
skippedScanFile.close()

