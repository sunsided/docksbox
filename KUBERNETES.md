# Use with Kubernetes
Kubernetes is another part of the equation when it comes to container apps. Containers on Kubernetes are deployed into pods, which are then usually a part of a deployment with one or more pods associated. Deployments can also be used to create scalable sets of pods for high availability on a Kubernetes cluster. If you’re unfamiliar with Kubernetes, check out this webinar below, where I go in-depth.

Deployments and services can be defined declaratively with a YAML file. Below is a Kubernetes YAML file that defines a deployment and a service for my retro gaming container.

The deployment is simple – it points to a single container image called blaize/keen and then tells Kubernetes what ports to expose for the container. The service defines how the deployment will be exposed on a network. In this case, it’s using a TCP load balancer, exposing port 80 and mapping that to the port exposed by the deployment. The service uses selectors on the label app to match the service with the deployment.

````
apiVersion: v1
kind: Service
metadata:
  name: keen-service
  labels:
    app: keen-deployment
spec:
  ports:
  - port: 80
    targetPort: 6080
  selector:
    app: keen-deployment
  type: LoadBalancer
---
apiVersion: apps/v1 
kind: Deployment
metadata:
  name: keen-deployment
spec:
  selector:
    matchLabels:
      app: keen-deployment
  replicas: 1
  template:
    metadata:
      labels:
        app: keen-deployment
    spec:
      containers:
      - name: master
        image: blaize/keen
        ports:
        - containerPort: 80
````

To connect, use this, first create a file called keen.yaml file, configure your instance kubectl to work with your instance of Kubernetes, then run deploy the sample.

````
kubectl create -f keen.yaml
````

When this is deployed to Kubernetes, Kubernetes will configure the external network to open on port 80 to listen to incoming requests. When used on Azure Kubernetes Services, AKS will create and map a public IP address (htttp://[your ip address]/vnc.html) for the service. Once connected, you can point your browser to the IP address of your cluster and have fun playing your retro games!
