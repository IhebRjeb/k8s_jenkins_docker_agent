# Jenkins Setup on Minikube Documentation

## Table of Contents
- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Dockerfile for Jenkins Agent](#dockerfile-for-jenkins-agent)
- [Kubernetes Configuration Files](#kubernetes-configuration-files)
  - [Jenkins Deployment](#jenkins-deployment)
  - [Persistent Volume Configuration](#persistent-volume-configuration)
  - [Jenkins Agent Deployment](#jenkins-agent-deployment)
- [Deployment Steps](#deployment-steps)
- [Accessing Jenkins](#accessing-jenkins)
- [Jenkins Agent Node Configuration Steps](#jenkins-agent-node-configuration-steps)
  - [Prerequisites](#prerequisites)
  - [Steps to Configure the Jenkins Agent Node](#steps-to-configure-the-jenkins-agent-node)
  - [Joining the Jenkins Master from the Agent](#joining-the-jenkins-master-from-the-agent)

## Overview
This document outlines the setup of Jenkins on a Minikube environment, detailing the Docker image for Jenkins agents and the necessary Kubernetes configuration files for deploying Jenkins and its agents.

## Directory Structure
The project structure is as follows:
```sh
.
├── Dockerfile
└── poc
    ├── jenkins-agent-deployment.yaml
    ├── jenkins-deployment.yaml
    └── jenkins-pv.yaml   
```     

## Dockerfile for Jenkins Agent
The Dockerfile is used to build the Docker image for the Jenkins agent. Below is the content of the Dockerfile:
```dockerfile
# Use the official Jenkins inbound agent as the base image
FROM jenkins/inbound-agent:latest

# Switch to root user to install Docker CLI
USER root

# Install Docker CLI dependencies and Docker CLI
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg2 \
    lsb-release && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Add the Jenkins user to the Docker group (so it can use Docker)
RUN if ! getent group docker; then groupadd docker; fi && \
    usermod -aG docker jenkins

# Switch back to Jenkins user
USER jenkins
```
# Kubernetes Configuration Files for Jenkins

This repository contains Kubernetes configuration files for deploying Jenkins and its agent in a Kubernetes cluster. The deployment files are located in the `poc` directory. Below are the configurations for each component.

## Jenkins Deployment

### File: `jenkins-deployment.yaml`

This file defines the Jenkins deployment and service configuration.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: jenkins-data
          mountPath: /var/jenkins_home
      volumes:
      - name: jenkins-data
        persistentVolumeClaim:
          claimName: jenkins-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins-service
  namespace: jenkins
spec:
  type: NodePort  # Or ClusterIP if you're only accessing it within the cluster
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      nodePort: 31532
    - name: jnlp
      port: 50000
      targetPort: 50000
  selector:
    app: jenkins
```
## Persistent Volume Configuration

### File: `jenkins-pv.yaml`

This file defines the persistent volume and persistent volume claim for Jenkins data storage.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jenkins-pv
  namespace: jenkins
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/wsl/docker-desktop/shared-sockets/jenkins-data" # Updated path

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: jenkins
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi

```
## Jenkins Agent Deployment

### File: `jenkins-agent-deployment.yaml`

This file defines the Jenkins agent deployment, including environment variables and volume mounts.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-agent
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins-agent
  template:
    metadata:
      labels:
        app: jenkins-agent
    spec:
      containers:
      - name: jenkins-agent
        image: ihebrj/jenkins-agent:latest
        env:
        - name: JENKINS_URL
          value: "http://jenkins-service:8080"  # Use the Jenkins service from the current namespace
        - name: JENKINS_AGENT_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: JENKINS_SECRET
          value: "8aaaf08fa4644154ca4ee95abe679dc3e97d9462c9b08ff04f3098034d57e31c"  # Agent secret from Jenkins UI
        - name: JENKINS_AGENT_WORKDIR
          value: "/home/jenkins"  # Define the working directory for the agent
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run/docker.sock
      volumes:
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock
          type: Socket
      
```

## Deployment Steps

### 1. Create a Namespace for Jenkins

First, create a dedicated namespace for Jenkins:

```bash
kubectl create namespace jenkins
```

### 2. Apply the Persistent Volume and Persistent Volume Claim

Set up the persistent volume and persistent volume claim for Jenkins:

```bash
kubectl apply -f jenkins-pv.yaml
```

### 3. Deploy Jenkins Master

Deploy the Jenkins master by applying the deployment configuration:

```bash
kubectl apply -f jenkins-deployment.yaml
```
### 4. Deploy Jenkins Agent

Deploy the Jenkins agent using the provided deployment file:

```bash
kubectl apply -f jenkins-agent-deployment.yaml
```

# Accessing Jenkins and Configuring Jenkins Agents

## Accessing Jenkins

To access the Jenkins UI, open your web browser and navigate to:

```bash
http://<minikube-ip>:31532
```
You can find your Minikube IP address by running:
```bash
minikube ip
```

# Jenkins Agent Node Configuration Steps

After deploying the Jenkins agent, follow these steps to configure it within the Jenkins master:

## Prerequisites
- Ensure that the Jenkins master is running.
- Verify that the Jenkins agent pod is active and able to connect to the Jenkins master.

## Steps to Configure the Jenkins Agent Node

1. **Access Jenkins Dashboard:** 
   Open your web browser and navigate to the Jenkins master URL (e.g., `http://<MINIKUBE_IP>:31532`).

2. **Log in to Jenkins:** 
   Use your Jenkins credentials to log in.

3. **Navigate to Manage Jenkins:** 
   From the Jenkins dashboard, click on "Manage Jenkins" in the left sidebar.

4. **Manage Nodes:** 
   Click on "Manage Nodes and Clouds." This will display a list of existing nodes.

5. **Add a New Node:**
   - Click on "New Node."
   - Enter a name for the agent (e.g., `docker-agent`).
   - Select "Permanent Agent" and click **OK.**

6. **Configure Node Details:**
   - **Description:** (Optional) Provide a description for the agent.
   - **# of Executors:** Set the number of concurrent jobs the agent can run (e.g., `1`).
   - **Remote Root Directory:** Specify the working directory for the agent (e.g., `/home/jenkins`).
   - **Labels:** (Optional) Add labels to identify the node for specific job assignments (e.g., `docker`).
   - **Usage:** Select how to use the node (e.g., "Use this node as much as possible.").
   - **Launch Method:** Choose "Launch agents via execution of command on the master" or "Launch agent via Java Web Start" based on your preference.

7. **Configure Node Properties:**
   - Scroll down to "Node Properties."
   - Enable "Environment Variables" and add any necessary variables for the agent's operations. For example:
     - `DOCKER_HOST:` Set to `tcp://docker:2375` if you plan to use Docker commands within the agent.

8. **Save Configuration:** 
   Click "Save" to apply the configuration changes.

9. **Verify Agent Connection:** 
   After saving, return to "Manage Nodes and Clouds." Ensure the new agent appears in the list and shows as "Connected."

10. **Test the Agent:**
    - Create a simple freestyle job that runs a command using the Jenkins agent.
    - Select the agent from the "Restrict where this project can be run" option.
    - Build the job and verify that it runs successfully on the agent.

## Joining the Jenkins Master from the Agent
To join the Jenkins master from the agent, execute the following commands from the Jenkins agent's terminal : 
```bash
curl -sO http://jenkins-service:8080/jnlpJars/agent.jar 
java -jar agent.jar -url http://jenkins-service:8080/ -secret <provided_secret> -name "docker-agent" -workDir "/home/jenkins"
```
This command retrieves the agent JAR file and starts the agent, connecting it to the Jenkins master using the provided secret.