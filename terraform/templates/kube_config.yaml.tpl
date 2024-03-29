apiVersion: v1
clusters:
- cluster:
    server: ${MASTER_ENDPOINT}
    certificate-authority-data: ${CERTIFICATE}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws 
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${CLUSTER_NAME}"
