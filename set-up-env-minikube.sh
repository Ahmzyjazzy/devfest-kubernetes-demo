#!/bin/bash


run(){
    minikube start
    delete
    enable_addons
    build_image
    deploy
    open_service
}

install_kubectl(){
    sudo apt-get update && sudo apt-get install -y apt-transport-https
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl
}

install_minikube(){
    curl -L https://github.com/kubernetes/minikube/releases/download/v0.28.0/minikube-linux-amd64 -c -x 10 -s 10 -j 10 -o /tmp/minikube
    sudo chmod +x /tmp/minikube
    #Just incase local/bin is not in your path
    export PATH=$PATH:$HOME/.local/bin
    cp /tmp/minikube ~/.local/bin/minikube
}

install_helm(){
    curl -L https://github.com/helm/helm/archive/v2.11.0.tar.gz  -c -x 10 -s 10 -j 10 -o /tmp/helm.tar.gz 
    sudo tar -xvzf /tmp/helm.tar.gz -C /tmp
    #Just incase local/bin is not in your path
    export PATH=$PATH:$HOME/.local/bin
    cp /tmp/minikube ~/.local/bin/minikube
}

install_and_start() {
    if hash minikube 2>/dev/null; then
        echo_with_decorators "Minikube is installed"
    else
        install-minikube
    fi

    if hash kubectl 2>/dev/null; then
        echo_with_decorators "Kubectl is installed"
    else
        install-kubectl
    fi

    run
}

echo_with_decorators(){
    echo -e "\n >----- \n  $1 \n ------<\n"
    echo "Press enter when ready to continue"
    read

}

delete(){
    echo_with_decorators "Deleting previous namespaces if they exist"
    kubectl delete namespace random-namespace
}

enable_addons(){
    echo_with_decorators "Enabling ingress setup to allow local load balancer use"
    minikube addons enable ingress
}

setup_env(){
    #We need to switch over to the minikube docker client
    echo_with_decorators "Here we want to make sure that our docker builds go to kubernetes so we switch docker clients"
    DOCKER_SETUP_K8S=$(minikube docker-env)
    echo_with_decorators "Here's what makes that happen:"
    echo_with_decorators "$DOCKER_SETUP_K8S"
    eval $DOCKER_SETUP_K8S
}

build_image(){
    setup_env
    echo_with_decorators "Now we're gonna build the test node-demo app"
    docker build -t node-demo .
}

deploy(){
    echo_with_decorators "Now we run through all the config files we have in the order specified"
    echo_with_decorators "namespace -> configmap  -> controller -> default-http -> deployment -> service -> ingress"
    for f in *{namespace,config,deployment,service,ingress}*; do kubectl create --save-config -f  $f; done 
    # kubectl expose deployment default-http-backend --namespace=ingress-nginx
}

update_configs(){
    echo_with_decorators "Let's update out configs again"
    echo_with_decorators "NO Order is required here: namespace -> configmap -> deployment -> service -> ingress"
    kubectl apply -f .
}

add_to_hosts(){
    MINIKUBE_IP=$(minikube ip)
    echo_with_decorators "Adding minikube ip to hosts file"
    if cat /etc/hosts | grep random.demo 2> /dev/null; then
        echo_with_decorators "You already have it in your hosts file"
    else
        echo_with_decorators "Adding minikube host IP to your computer"
        echo_with_decorators "$MINIKUBE_IP random.demo" | sudo tee -a /etc/hosts
    fi
}

open_service(){
    echo_with_decorators "You can also choose to open the service after all has been configured using this"
    minikube service random-service --namespace=random-service
    echo_with_decorators "This was bound to fail, don't panic. It won't work the next time."
}

watch_deployment(){
    echo_with_decorators "Now let's watch the deployments startup"
    xterm -fa 'Monospace' -fs 10 -bg white -fg black -e "watch kubectl describe pod random-deployment --namespace=random-namespace"
    echo_with_decorators "Now that you've seen it start successfully, let's try to open the service again"
    minikube service random-service --namespace=random-service
}

correct_ingress_controller(){
    POD_NAMESPACE="kube-system"
    POD_NAME=$(kubectl get pods -n kube-system -l addonmanager.kubernetes.io/mode=Reconcile,app=nginx-ingress-controller -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -it $POD_NAME -n $POD_NAMESPACE -- /nginx-ingress-controller  --default-backend-service=default-http-backend --enable-dynamic-configuration=true
}

if [[ -z "$1" ]]; then
    echo_with_decorators "Kindly use the Makefile to access commands here, Thanks :-)"
else
    "$@"
fi