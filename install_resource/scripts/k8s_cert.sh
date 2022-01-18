#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin
K8S_MASTER_HOSTNAME=k8s-master01
K8S_MASTER_IP=192.168.2.4
K8S_MASTER_VIP=192.168.2.4
K8S_SERVICE_IP=10.96.0.1
K8S_APISERVER_PORT=6443
CERT_CONFIG_DIR=/root/k8s_learn_doc/install_resource/k8s_pki_config

config_dir(){
	mkdir -p /etc/etcd/ssl /etc/kubernetes/pki/etcd  /root/.kube /etc/kubernetes/pki /etc/kubernetes/manifests/ /etc/systemd/system/kubelet.service.d  /var/lib/kubelet /var/log/kubernetes /opt/cni/bin
}

etcd_cert(){
	cfssl gencert -initca ${CERT_CONFIG_DIR}/etcd-ca-csr.json | cfssljson -bare /etc/etcd/ssl/etcd-ca;

	cfssl gencert \
		-ca=/etc/etcd/ssl/etcd-ca.pem \
		-ca-key=/etc/etcd/ssl/etcd-ca-key.pem \
		-config=${CERT_CONFIG_DIR}/ca-config.json \
		-hostname=127.0.0.1,${K8S_MASTER_HOSTNAME},${K8S_MASTER_IP} \
		-profile=kubernetes \
		${CERT_CONFIG_DIR}/etcd-csr.json | cfssljson -bare /etc/etcd/ssl/etcd;

	ln -s /etc/etcd/ssl/* /etc/kubernetes/pki/etcd/
}

k8s_cert(){
	cfssl gencert -initca ${CERT_CONFIG_DIR}/ca-csr.json | cfssljson -bare /etc/kubernetes/pki/ca;


        if [ ${K8S_MASTER_IP} == ${K8S_MASTER_VIP} ]; then

		cfssl gencert -ca=/etc/kubernetes/pki/ca.pem \
		    -ca-key=/etc/kubernetes/pki/ca-key.pem \
			-config=${CERT_CONFIG_DIR}/ca-config.json \
			-hostname=${K8S_SERVICE_IP},127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,${K8S_MASTER_HOSTNAME},${K8S_MASTER_IP} \
		    -profile=kubernetes ${CERT_CONFIG_DIR}/apiserver-csr.json | cfssljson -bare /etc/kubernetes/pki/apiserver
	else

		cfssl gencert -ca=/etc/kubernetes/pki/ca.pem \
		    -ca-key=/etc/kubernetes/pki/ca-key.pem \
			-config=${CERT_CONFIG_DIR}/ca-config.json \
			-hostname=${K8S_SERVICE_IP},127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,${K8S_MASTER_HOSTNAME},${K8S_MASTER_VIP},${K8S_MASTER_IP} \
		    -profile=kubernetes ${CERT_CONFIG_DIR}/apiserver-csr.json | cfssljson -bare /etc/kubernetes/pki/apiserver
	fi


	cfssl gencert \
		-ca=/etc/kubernetes/pki/ca.pem \
		-ca-key=/etc/kubernetes/pki/ca-key.pem \
		-config=${CERT_CONFIG_DIR}/ca-config.json \
		-profile=kubernetes \
		${CERT_CONFIG_DIR}/manager-csr.json | cfssljson -bare /etc/kubernetes/pki/controller-manager;

	cfssl gencert \
		-ca=/etc/kubernetes/pki/ca.pem \
		-ca-key=/etc/kubernetes/pki/ca-key.pem \
		-config=${CERT_CONFIG_DIR}/ca-config.json \
		-profile=kubernetes \
		${CERT_CONFIG_DIR}/scheduler-csr.json | cfssljson -bare /etc/kubernetes/pki/scheduler;

	cfssl gencert \
		-ca=/etc/kubernetes/pki/ca.pem \
		-ca-key=/etc/kubernetes/pki/ca-key.pem \
		-config=${CERT_CONFIG_DIR}/ca-config.json \
		-profile=kubernetes \
		${CERT_CONFIG_DIR}/kube-proxy-csr.json | cfssljson -bare /etc/kubernetes/pki/kube-proxy;

	cfssl gencert \
		-ca=/etc/kubernetes/pki/ca.pem \
		-ca-key=/etc/kubernetes/pki/ca-key.pem \
		-config=${CERT_CONFIG_DIR}/ca-config.json \
		-profile=kubernetes \
		${CERT_CONFIG_DIR}/admin-csr.json | cfssljson -bare /etc/kubernetes/pki/admin;

	cfssl gencert -initca ${CERT_CONFIG_DIR}/front-proxy-ca-csr.json | cfssljson -bare /etc/kubernetes/pki/front-proxy-ca;

	cfssl gencert \
		-ca=/etc/kubernetes/pki/front-proxy-ca.pem \
		-ca-key=/etc/kubernetes/pki/front-proxy-ca-key.pem \
		-config=${CERT_CONFIG_DIR}/ca-config.json \
		-profile=kubernetes \
		${CERT_CONFIG_DIR}/front-proxy-client-csr.json | cfssljson -bare /etc/kubernetes/pki/front-proxy-client;


	openssl genrsa -out /etc/kubernetes/pki/sa.key 2048;
	openssl rsa -in /etc/kubernetes/pki/sa.key -pubout -out /etc/kubernetes/pki/sa.pub
}

kube_config(){
	# controller-manager
	kubectl config set-cluster kubernetes \
		--certificate-authority=/etc/kubernetes/pki/ca.pem \
		--embed-certs=true \
		--server=https://${K8S_MASTER_VIP}:${K8S_APISERVER_PORT}\
		--kubeconfig=/etc/kubernetes/controller-manager.kubeconfig;

	kubectl config set-context system:kube-controller-manager@kubernetes \
		--cluster=kubernetes \
		--user=system:kube-controller-manager \
		--kubeconfig=/etc/kubernetes/controller-manager.kubeconfig;

	kubectl config set-credentials system:kube-controller-manager \
		--client-certificate=/etc/kubernetes/pki/controller-manager.pem \
		--client-key=/etc/kubernetes/pki/controller-manager-key.pem \
		--embed-certs=true \
		--kubeconfig=/etc/kubernetes/controller-manager.kubeconfig;

	kubectl config use-context system:kube-controller-manager@kubernetes \
		--kubeconfig=/etc/kubernetes/controller-manager.kubeconfig;



	# kube-scheduler
	kubectl config set-cluster kubernetes \
		--certificate-authority=/etc/kubernetes/pki/ca.pem \
		--embed-certs=true \
		--server=https://${K8S_MASTER_VIP}:${K8S_APISERVER_PORT} \
		--kubeconfig=/etc/kubernetes/scheduler.kubeconfig

	kubectl config set-context system:kube-scheduler@kubernetes \
		--cluster=kubernetes \
		--user=system:kube-scheduler \
		--kubeconfig=/etc/kubernetes/scheduler.kubeconfig

	kubectl config set-credentials system:kube-scheduler \
		--client-certificate=/etc/kubernetes/pki/scheduler.pem \
		--client-key=/etc/kubernetes/pki/scheduler-key.pem \
		--embed-certs=true \
		--kubeconfig=/etc/kubernetes/scheduler.kubeconfig

	kubectl config use-context system:kube-scheduler@kubernetes \
		--kubeconfig=/etc/kubernetes/scheduler.kubeconfig



	# admin
	kubectl config set-cluster kubernetes \
		--certificate-authority=/etc/kubernetes/pki/ca.pem \
		--embed-certs=true \
		--server=https://${K8S_MASTER_VIP}:${K8S_APISERVER_PORT} \
		--kubeconfig=/etc/kubernetes/admin.kubeconfig

	kubectl config set-credentials kubernetes-admin \
		--client-certificate=/etc/kubernetes/pki/admin.pem \
		--client-key=/etc/kubernetes/pki/admin-key.pem \
		--embed-certs=true \
		--kubeconfig=/etc/kubernetes/admin.kubeconfig


	kubectl config set-context kubernetes-admin@kubernetes \
		--cluster=kubernetes \
		--user=kubernetes-admin \
		--kubeconfig=/etc/kubernetes/admin.kubeconfig

	kubectl config use-context kubernetes-admin@kubernetes \
		--kubeconfig=/etc/kubernetes/admin.kubeconfig
}

config_dir
etcd_cert
k8s_cert
kube_config
