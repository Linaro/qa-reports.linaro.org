apiVersion: v1
preferences: {}
kind: Config

clusters:
- cluster:
    server: ${endpoint}
    certificate-authority-data: ${cluster_auth_base64}
  name: ${kubeconfig_name}

contexts:
- context:
    cluster: ${kubeconfig_name}
    user: ${kubeconfig_name}
    namespace: default
  name: default

- context:
    cluster: ${kubeconfig_name}
    user: ${kubeconfig_name}
    namespace: qareports-staging
  name: qareports-staging

- context:
    cluster: ${kubeconfig_name}
    user: ${kubeconfig_name}
    namespace: qareports-production
  name: qareports-production

current-context: default

users:
- name: ${kubeconfig_name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - ${clustername}
      command: ../scripts/eks_auth.sh
      env:
      - name: AWS_STS_REGIONAL_ENDPOINTS
        value: regional
