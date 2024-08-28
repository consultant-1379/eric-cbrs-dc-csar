#!/usr/bin/env groovy

def defaultBobImage = 'armdocker.rnd.ericsson.se/proj-adp-cicd-drop/bob.2.0:latest'
def bob = new BobCommand()
        .bobImage(defaultBobImage)
		.envVars([
        HOME:'${HOME}',
		CSAR_VERSION:'${CSAR_VERSION}',
		CSAR_REPO:'${CSAR_REPO}',
		PWD:'${PWD}',
		IMAGE_NAME:'${IMAGE_NAME}',
		HELM_REPO_TOKEN:'${HELM_REPO_TOKEN}'
    ])
        .needDockerSocket(true)
        .toString()

pipeline {
    agent {
            node
            {
            label "GE7_Docker"
            }
        }
    stages {
        stage ('Clean workspace') {
          steps {
                script {
                   sh "docker system prune -fa"
                }
            }
        }
        stage('Get CSAR'){
            steps{
                script {
                   sh "${bob} init -r ruleset-va.yaml"
                   sh "${bob} get-csar -r ruleset-va.yaml"
                }
            }
        }
        stage('Image level Scans'){
          parallel{
            stage('Anchore') {
                steps {
                   sh "${bob} anchore-grype-scan -r ruleset-va.yaml"
                   archiveArtifacts 'build/anchore-reports/**.*'
                }
            }
            stage('Trivy'){
                steps {
                    script {
                        def image_list = readFile("Files/images.txt").readLines()
                        for(image in image_list)
                           {
                            env.IMAGE_NAME=image
                            sh "${bob} trivy-inline-scan -r ruleset-va.yaml"
                          }
                        }
                    archiveArtifacts 'build/trivy-reports/**.*'
                }
            }
            stage('X-Ray'){
                steps{
                withCredentials([string(credentialsId: 'CBRSCIADM', variable: 'HELM_REPO_TOKEN')]) {
                    sh "${bob} fetch-xray-report -r ruleset-va.yaml"
                    archiveArtifacts 'build/xray-reports/**.*'
                }
            }
        }
    }
    }
	       stage('Get Rpm list'){
                steps {
                script {
					    def image_list = readFile("Files/images.txt").readLines()
                        for(image in image_list)
					      {
                            env.IMAGE_NAME=image
                            sh "./RetrieveImageRpmDb.sh -z -i ${env.IMAGE_NAME} -p ./rpmdb/."
                          }
		              }
		        }
		    }
	stage('Generate csv reports '){
			steps{
			    script {
                    sh "${bob} prepare-reports -r ruleset-va.yaml"
				}
			}
		}
		stage('Merge all reports'){
			steps{
                   sh "${bob} merge-reports -r ruleset-va.yaml"
				}
		}
		stage('Remove duplicates'){
			steps{
                    sh "${bob} remove-duplicates -r ruleset-va.yaml"
                    archiveArtifacts 'build/**.*'
			}
		}
	  }
	post {
	    always{
		 deleteDir()
        }
    }
}

// More about @Builder: http://mrhaki.blogspot.com/2014/05/groovy-goodness-use-builder-ast.html
import groovy.transform.builder.Builder
import groovy.transform.builder.SimpleStrategy

@Builder(builderStrategy = SimpleStrategy, prefix = '')
class BobCommand {

    def bobImage = 'bob.2.0:latest'
    def envVars = [:]

    def needDockerSocket = false

    String toString() {
        def env = envVars
                .collect({ entry -> "-e ${entry.key}=\"${entry.value}\"" })
                .join(' ')

        def cmd = """\
            |docker run
            |--init
            |--rm
            |--workdir \${PWD}
            |--user \$(id -u):\$(id -g)
            |-v \${PWD}:\${PWD}
            |-v /etc/group:/etc/group:ro
            |-v /etc/passwd:/etc/passwd:ro
            |-v \${HOME}:\${HOME}
            |${needDockerSocket ? '-v /var/run/docker.sock:/var/run/docker.sock' : ''}
            |${env}
            |\$(for group in \$(id -G); do printf ' --group-add %s' "\$group"; done)
            |--group-add \$(stat -c '%g' /var/run/docker.sock)
            |${bobImage}
            |"""
        return cmd
                .stripMargin()           // remove indentation
                .replace('\n', ' ')      // join lines
                .replaceAll(/[ ]+/, ' ') // replace multiple spaces by one
    }
}