locals {
  zone = "at-vie-2"
}

resource "exoscale_security_group" "my_security_group" {
  name = "my-sks-cluster-sg"
}

resource "exoscale_security_group_rule" "kubelet" {
  security_group_id = exoscale_security_group.my_security_group.id
  description       = "Kubelet"
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 10250
  end_port          = 10250
  # (beetwen worker nodes only)
  user_security_group_id = exoscale_security_group.my_security_group.id
}

resource "exoscale_security_group_rule" "cilium_vxlan" {
  security_group_id = exoscale_security_group.my_security_group.id
  description       = "Cilium VXLAN"
  type              = "INGRESS"
  protocol          = "UDP"
  start_port        = 8472
  end_port          = 8472
  user_security_group_id = exoscale_security_group.my_security_group.id
}

resource "exoscale_security_group_rule" "cilium_health" {
  security_group_id = exoscale_security_group.my_security_group.id
  description       = "Cilium Health Check"
  type              = "INGRESS"
  protocol          = "ICMP"
  icmp_code         = 0
  icmp_type         = 8
  user_security_group_id = exoscale_security_group.my_security_group.id
}

resource "exoscale_security_group_rule" "cilium_health_tcp" {
  security_group_id = exoscale_security_group.my_security_group.id
  description       = "Cilium Health Check"
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 4240
  end_port          = 4240
  user_security_group_id = exoscale_security_group.my_security_group.id
}

resource "exoscale_sks_cluster" "my_sks_cluster" {
   zone = local.zone
   name = "my-sks-cluster"
   cni = "cilium"
   service_level = "starter"
}

#create nodes 
resource "exoscale_sks_nodepool" "my_sks_nodepool" {
  zone       = local.zone
  cluster_id = exoscale_sks_cluster.my_sks_cluster.id
  name       = "my-sks-nodepool"
  instance_type = "standard.medium"
  size          = 3
  security_group_ids = [
    exoscale_security_group.my_security_group.id,
  ]
}

# (administration credentials)
resource "exoscale_sks_kubeconfig" "my_sks_kubeconfig" {
  zone       = local.zone
  cluster_id = exoscale_sks_cluster.my_sks_cluster.id
  user   = "kubernetes-admin"
  groups = ["system:masters"]
  ttl_seconds           = 3600
  early_renewal_seconds = 300
}
resource "local_sensitive_file" "my_sks_kubeconfig_file" {
  filename        = "kubeconfig"
  content         = exoscale_sks_kubeconfig.my_sks_kubeconfig.kubeconfig
  file_permission = "0600"
}

resource "helm_release" "argo_cd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.52.0"
  timeout          = 1200
  create_namespace = true
  namespace        = "argocd"
  lint             = true
  wait             = true

  depends_on = [
    local_sensitive_file.my_sks_kubeconfig_file
  ]
}

locals {
  repo_url = "https://github.com/podtato-head/podtato-head-app"
  repo_path = "deploy"
  app_name = "podtato-head"
  app_namespace = "podtato-head"
}

resource "helm_release" "argo_cd_app" {
  name             = "argocd-apps"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  version          = "1.4.1"
  timeout          = 1200
  create_namespace = true
  namespace        = "argocd"
  lint             = true
  wait             = true
  values = [templatefile("app-values.yaml", {
    repo_url = local.repo_url
    repo_path = local.repo_path
    app_name = local.app_name
    app_namespace = local.app_namespace
  })]

  depends_on = [
    helm_release.argo_cd
  ]
}