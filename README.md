This document describes a simple example to configure CI/CD with OCP and Jenkins.

1. First, provision OCPv4.9.53.

2. create a new project/namespace.

3. install jenkins operator. (This might not be shown up in newer OCP like v4.11 by default)  
<img width="564" alt="image" src="https://media.github.ibm.com/user/24674/files/30281484-967c-48b5-8f08-8c25ddabc86d">

4. create a jenkins instance.  
<img width="1191" alt="image" src="https://media.github.ibm.com/user/24674/files/a08fae2b-1d2f-4aee-b9a0-f16e472f8ad8">

5. login to the jenkins as kubeadmin.  
https://jenkins-jenkins-sample-defaulte.apps.***.***.com/

6. create a pipeline.
<img width="745" alt="image" src="https://media.github.ibm.com/user/24674/files/2036514b-8a40-488b-a3fe-c9aeb099c7e0">  
<img width="1199" alt="image" src="https://media.github.ibm.com/user/24674/files/e97f6834-c294-47fd-b0a7-197cc5d805a4">  

7. In this example, I use https://github.com/e30532/myjenkins. 
```
[root@armless1 ~]# git clone https://github.com/e30532/myjenkins
Cloning into 'myjenkins'...
remote: Enumerating objects: 54, done.
remote: Counting objects: 100% (54/54), done.
remote: Compressing objects: 100% (35/35), done.
remote: Total 54 (delta 22), reused 38 (delta 10), pack-reused 0
Receiving objects: 100% (54/54), 6.17 KiB | 3.08 MiB/s, done.
Resolving deltas: 100% (22/22), done.
[root@armless1 ~]# cd myjenkins/
[root@armless1 myjenkins]# tree
.
|-- Dockerfile
|-- Jenkinsfile
|-- pom.xml
|-- README.md
|-- server.xml
`-- src
    `-- myjenkins
        `-- SimpleServlet.java

2 directories, 6 files
[root@armless1 myjenkins]# 
```
Note: In the Docker file, there are two steps. In the first phase, the application is packaged as a war file. In the later phase, a liberty image is built with the new application. 

8. Because the github.com can't directly access the jenkins running in Fyre(behind F/W), we use SCM Polling instead of WebHook.  
<img width="1215" alt="image" src="https://media.github.ibm.com/user/24674/files/4009ed78-eb66-433f-a092-c5a71b6f9b34">

9. As you see in Jenkinsfile, it uses a buildconfig named myjenkins. So we need to create it at OCP side.

<img width="673" alt="image" src="https://media.github.ibm.com/user/24674/files/732b18cb-4647-4216-9f8d-ff1caba71c3a">

```
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  labels:
    app.kubernetes.io/name: myjenkins
  name: myjenkins
spec:
  output:
    to:
      kind: ImageStreamTag
      name: 'myjenkins:latest'
  source:
    # Expect a local directory to be streamed to OpenShift as a build source
    type: Binary
    binary: {}
  strategy:
    type: Docker
    dockerStrategy:
      # Find the image build instructions in ./Dockerfile
      dockerfilePath: Dockerfile
```

10. As you see in the build config above, the image is pushed to the OCP internal registry. So we need to create the image stream as well. 

<img width="592" alt="image" src="https://media.github.ibm.com/user/24674/files/9dd46c77-d7d0-4405-a29a-22a6611dc607">


11. By pushing the change to the github repository, 

```
[root@armless1 myjenkins]# vi src/myjenkins/SimpleServlet.java 
[root@armless1 myjenkins]# git add . 
[root@armless1 myjenkins]# git commit -m "update SimpleServlet"
[main ab597a6] update SimpleServlet
 Committer: root <root@armless1.***.***.com>
Your name and email address were configured automatically based
on your username and hostname. Please check that they are accurate.
You can suppress this message by setting them explicitly:

    git config --global user.name "Your Name"
    git config --global user.email you@example.com

After doing this, you may fix the identity used for this commit with:

    git commit --amend --reset-author

 1 file changed, 1 insertion(+), 1 deletion(-)
[root@armless1 myjenkins]# git push
Enumerating objects: 9, done.
Counting objects: 100% (9/9), done.
Delta compression using up to 8 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (5/5), 404 bytes | 404.00 KiB/s, done.
Total 5 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To https://github.com/e30532/myjenkins
   30e4307..ab597a6  main -> main
[root@armless1 myjenkins]# 
```

A new build is kicked. 
<img width="986" alt="image" src="https://media.github.ibm.com/user/24674/files/a9f996cf-db6a-46cf-a08d-1e841c19f9c3">

<img width="737" alt="image" src="https://media.github.ibm.com/user/24674/files/c9b381c0-d7e1-4eb8-8bd0-2045279aaec5">


At the OCP side, a new build object is created.  
```
yamayoshi@yamadayoshikis-MacBook-Pro ~ % oc get pod
NAME                                      READY   STATUS      RESTARTS   AGE
jenkins-jenkins-sample-769bb9c77f-5w2tk   2/2     Running     0          89m
maven-lnj38                               1/1     Running     0          65s
myjenkins-1-build                         0/1     Completed   0          82m
myjenkins-2-build                         0/1     Completed   0          32m
myjenkins-3-build                         1/1     Running     0          16s
myjenkins-866754764d-vnfln                1/1     Running     0          29m
yamayoshi@yamadayoshikis-MacBook-Pro ~ % oc logs -f myjenkins-3-build 
:
:
[2/2] STEP 6/10: ENV WLP_LOGGING_CONSOLE_LOGLEVEL=info
--> 1bb17032d86
[2/2] STEP 7/10: ENV WLP_LOGGING_CONSOLE_SOURCE=message,trace,accessLog,ffdc,audit
--> 108f1f32081
[2/2] STEP 8/10: RUN configure.sh
```

Once the build is completed, a new image is published to the internal registry and the application pod is recreated with the new image.
```
yamayoshi@yamadayoshikis-MacBook-Pro ~ % oc get pod
NAME                                      READY   STATUS        RESTARTS   AGE
jenkins-jenkins-sample-769bb9c77f-5w2tk   2/2     Running       0          91m
maven-lnj38                               1/1     Terminating   0          3m32s
myjenkins-1-build                         0/1     Completed     0          84m
myjenkins-2-build                         0/1     Completed     0          34m
myjenkins-3-build                         0/1     Completed     0          2m43s
myjenkins-7444d4558d-wltwk                1/1     Running       0          8s
yamayoshi@yamadayoshikis-MacBook-Pro ~ % curl myjenkins-defaulte.apps.***.***/myjenkins/SimpleServlet
** Served at: /myjenkins%                                                                                                                               yamayoshi@yamadayoshikis-MacBook-Pro ~ % 
```


