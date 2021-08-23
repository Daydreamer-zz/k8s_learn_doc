# Jenkins CI/CD

## 1.必选插件

```
Active Choices
Blue Ocean
Build Pipeline
Delivery Pipeline
Dashboard for Blue Ocean
Declarative Pipeline Migration Assistant
Git Parameter
Hidden Parameter
Kubernetes CLI
List Git Branches Parameter
Parameterized Trigger
```

### 2.jenkins pipeline语法

https://www.jenkins.io/zh/doc/book/pipeline/syntax/

### 3.生成jenkins k8s秘钥

```bash
openssl pkcs12 -export -out /root/default.pfx -inkey /etc/kubernetes/pki/admin-key.pem -in /etc/kubernetes/pki/admin.pem -certfile /etc/kubernetes/pki/ca.pem
```

### 4.jenkins结合k8s pod构建java应用示例

```groovy
pipeline {
  agent {
    kubernetes {
      cloud 'kubernetes-default'
      slaveConnectTimeout 1200
      yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - args: [\'$(JENKINS_SECRET)\', \'$(JENKINS_NAME)\']
      image: 'registry.cn-beijing.aliyuncs.com/citools/jnlp:alpine'
      name: jnlp
      imagePullPolicy: IfNotPresent
      volumeMounts:
        - mountPath: "/etc/localtime"
          name: "volume-2"
          readOnly: false        
    - command:
        - "cat"
      env:
        - name: "LANGUAGE"
          value: "en_US:en"
        - name: "LC_ALL"
          value: "en_US.UTF-8"
        - name: "LANG"
          value: "en_US.UTF-8"
      image: registry.cn-qingdao.aliyuncs.com/mycicd/maven:aliyun
      imagePullPolicy: IfNotPresent
      name: "build"
      tty: true
      volumeMounts:
        - mountPath: "/etc/localtime"
          name: "volume-2"
          readOnly: false
        - mountPath: "/root/.m2"
          name: "m2cache"
          readOnly: false
    - command:
        - "cat"
      env:
        - name: "LANGUAGE"
          value: "en_US:en"
        - name: "LC_ALL"
          value: "en_US.UTF-8"
        - name: "LANG"
          value: "en_US.UTF-8"
      image: "registry.cn-beijing.aliyuncs.com/citools/kubectl:self-1.17"
      imagePullPolicy: "IfNotPresent"
      name: "kubectl"
      tty: true
      volumeMounts:
        - mountPath: "/etc/localtime"
          name: "volume-2"
          readOnly: false
        - mountPath: "/var/run/docker.sock"
          name: "volume-docker"
          readOnly: false
    - command:
        - "cat"
      env:
        - name: "LANGUAGE"
          value: "en_US:en"
        - name: "LC_ALL"
          value: "en_US.UTF-8"
        - name: "LANG"
          value: "en_US.UTF-8"
      image: "registry.cn-beijing.aliyuncs.com/citools/docker:19.03.9-git"
      imagePullPolicy: "IfNotPresent"
      name: "docker"
      tty: true
      volumeMounts:
        - mountPath: "/etc/localtime"
          name: "volume-2"
          readOnly: false
        - mountPath: "/var/run/docker.sock"
          name: "volume-docker"
          readOnly: false
  restartPolicy: "Never"
  nodeSelector:
    build: "true"
  securityContext: {}
  volumes:
    - hostPath:
        path: "/var/run/docker.sock"
      name: "volume-docker"
    - hostPath:
        path: "/usr/share/zoneinfo/Asia/Shanghai"
      name: "volume-2"
    - hostPath:
        path: "/root/.m2"
      name: "m2cache"
'''	
}
}

  stages {
    stage('pulling Code') {
      parallel {
        stage('pulling Code') {
          when {
            expression {
              env.gitlabBranch == null
            }
          }
          steps {
            git(branch: "${BRANCH}", credentialsId: 'GITLAB_USER', url: "${REPO_URL}")
          }
        }

        stage('pulling Code by trigger') {
          when {
            expression {
              env.gitlabBranch != null
            }
          }
          steps {
            git(url: "${REPO_URL}", branch: env.gitlabBranch, credentialsId: 'GITLAB_USER')
          }
        }

      }
    }

    stage('initConfiguration') {
      steps {
        script {
          CommitID = sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
          CommitMessage = sh(returnStdout: true, script: "git log -1 --pretty=format:'%h : %an  %s'").trim()
          def curDate = sh(script: "date '+%Y%m%d-%H%M%S'", returnStdout: true).trim()
          TAG = curDate[0..14] + "-" + CommitID + "-" + BRANCH
        }

      }
    }

    stage('Building') {
      parallel {
        stage('Building') {
          steps {
            container(name: 'build') {
            sh """
            echo "Building Project..."
            ${BUILD_COMMAND}
          """
            }

          }
        }

        stage('Scan Code') {
          steps {
            sh 'echo "Scan Code"'
          }
        }

      }
    }

    stage('Build image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'REGISTRY_USER', passwordVariable: 'Password', usernameVariable: 'Username')]) {
        container(name: 'docker') {
          sh """
          docker build -t ${HARBOR_ADDRESS}/${REGISTRY_DIR}/${IMAGE_NAME}:${TAG} .
          docker login -u ${Username} -p ${Password} ${HARBOR_ADDRESS}
          docker push ${HARBOR_ADDRESS}/${REGISTRY_DIR}/${IMAGE_NAME}:${TAG}
          """
        }
        }

      }
    }
    
    stage('Archive') {
       steps {
          archiveArtifacts artifacts: 'target/*.jar', followSymlinks: false
       }
    }

    stage('Deploy') {
    when {
            expression {
              DEPLOY != "false"
            }
          }
    
      steps {
      container(name: 'kubectl') {
        sh """
        cat ${KUBECONFIG_PATH} > /tmp/1.yaml
  /usr/local/bin/kubectl config use-context ${CLUSTER} --kubeconfig=/tmp/1.yaml
  export KUBECONFIG=/tmp/1.yaml
  /usr/local/bin/kubectl set image ${DEPLOY_TYPE} -l ${DEPLOY_LABEL} ${CONTAINER_NAME}=${HARBOR_ADDRESS}/${REGISTRY_DIR}/${IMAGE_NAME}:${TAG} -n ${NAMESPACE} --record
"""
        }

      }
    }

  }
  environment {
    CommitID = ''
    CommitMessage = ''
    TAG = ''
  }
}
```

