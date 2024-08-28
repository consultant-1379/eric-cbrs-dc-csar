#!/usr/bin/env groovy

def defaultBobImage = 'armdocker.rnd.ericsson.se/proj-adp-cicd-drop/bob.2.0:latest'
def bob = new BobCommand()
    .bobImage(defaultBobImage)
    .envVars([
        HOME:'${HOME}',
        USER:'${USER}',
		SPRINT_END:'${SPRINT_PREFIX}',
		HELM_REPO_TOKEN:'${HELM_REPO_TOKEN}',
		RELEASE_CANDIDATE:'${RELEASE_CANDIDATE}',
		CBRS_SSH:'${CBRS_SSH}',
		GERRIT_USERNAME:'${GERRIT_USERNAME}',
		CSAR_PACKAGE_NAME:'${CSAR_PACKAGE_NAME}',
        GERRIT_PASSWORD:'${GERRIT_PASSWORD}'
		
    ])
    .needDockerSocket(true)
    .toString()

pipeline {
    agent {
	    node{
            label 'GE7_Docker'
		}
    }
	environment{
        CSAR_PACKAGE_NAME = "eric-cbrs-dc-package"
        SPRINT_PREFIX = "point_fix_${SPRINT_END}"
    }
    parameters {
        string(name: 'SPRINT_END', description: '"Sprint End e.g: Sprint number(20.17)"')
		string(name: 'RELEASE_CANDIDATE', description: '"Release version  e.g: 0.1.0-1"')
    }
    stages {
        stage('Init') {
            steps {
                sh 'echo Init'
            }
        }
        stage('get-charts') {
            steps {
                        sh "${bob} -r ruleset2.0.pra.yaml get-charts"
            }
        }
        stage('upload-csar') {
            steps {
			 script {
			     withCredentials([string(credentialsId: 'CBRSCIADM', variable: 'HELM_REPO_TOKEN')]){
                        sh "${bob} -r ruleset2.0.pra.yaml upload-csar"
						archiveArtifacts 'artifact.properties'

            }
        }		
    }
	}
		 stage('new-pointfix-branch') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'Gerrit HTTP',
                                 usernameVariable: 'GERRIT_USERNAME',
                                 passwordVariable: 'GERRIT_PASSWORD'),
					file(credentialsId: 'cbrsciadm_ssh_key', variable: 'CBRS_SSH')]) {
                        sh "${bob} -r ruleset2.0.pra.yaml new-pointfix-branch"	
                }
            }
        }

		 stage('Increment version prefix') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'Gerrit HTTP',
                                 usernameVariable: 'GERRIT_USERNAME',
                                 passwordVariable: 'GERRIT_PASSWORD')])
                {
                    sh "${bob} -r ruleset2.0.pra.yaml increment-version-prefix"
                }
            }
        }
	}
	post {
      always {
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