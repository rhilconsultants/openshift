# Generate kubeconfig

First the kubeconfig needs to work with a service account so let's create one :

    cat > sa.yaml << EOF
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      Name: ${USER}
    EOF

Now we will create the service account :

    # oc create -f sa.yaml

This will use your personal account to create the service account. Make sure your personal account has permissions to do this.

### Fetch the Secret

Now we will Fetch the name of the secrets used by the service account
This can be found by running the following command:

    # oc describe serviceAccounts ${USER}

    Output :

        Name:                user01
    Namespace:           project-user01
    Labels:              <none>
    Annotations:         <none>
    Image pull secrets:  user01-dockercfg-95wws
    Mountable secrets:   user01-dockercfg-95wws
                         user01-token-sk287
    Tokens:              user01-token-sk287 ← {{ this is what you need }}
                         user01-token-t4nl6
    Events:              <none>

Note down the Mountable secrets information which has the name of the secret that holds the token

### Fetch the token from the secret

Using the Mountable secrets value, you can get the token used by the service account. 
Run the following command to extract this information:


    # oc describe secrets user01-token-sk287
    Name:         user01-token-sk287
    Namespace:    project-user01
    Labels:       <none>
    Annotations:  kubernetes.io/service-account.name: user01
                  kubernetes.io/service-account.uid: 2b94cdc6-59dd-438c-8f65-443218471241
    
    Type:  kubernetes.io/service-account-token
    
    Data
    ====
    ca.crt:          5932 bytes
    namespace:       14 bytes
    service-ca.crt:  7145 bytes
    token:           eyJhbGciOiJSUzI1NiIsImtpZCI6IlExOU41eGc0X2paTUx3Sk9GcXdDTV9zdjRKUEIzeHVBZnlWa1dPWW9SS28ifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJwcm9qZWN0LXVzZXIwMSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJ1c2VyMDEtdG9rZW4tc2syODciLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoidXNlcjAxIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiMmI5NGNkYzYtNTlkZC00MzhjLThmNjUtNDQzMjE4NDcxMjQxIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OnByb2plY3QtdXNlcjAxOnVzZXIwMSJ9.cDiDLhDxb3nC8Pyyc_ADLr--NhH4wAwboJoq_3KV0J8y_g9GR3sEmfx9gtxgBFbH2cqxEAIoUN40A38PHW-T72Y8z5DdDCGBFpQM8zFA7LuasxvbBCfmlcChZlR7-IRo3aPlOL2w2N_U37ipHnnTeHURiPawD5XQv7hf5nXRKYz5pe9rvoRXZs4a9n2LwJG509hEwUud6nO7eDu0nGRNU0prXx1mQYM92PXwDmGG7WVhQ5zzS6t77CBlah9aV4YF2kuTBTOvELvEGsJl8dAP2ghNUFvjPF-wtZjqqVDOx3qQCRNIAbJa-tl2qMsRWFvzNV0d_prIc0s6vvSvy0omRg ← {{ this is what you need }}
    
This will output the token information that looks something like above. Note down the token value

### Get the certificate info for the cluster

Every cluster has a certificate that clients can use to encrypt traffic. Fetch the certificate and write to a file by running this command. In this case, we are using a file name cluster-cert.txt


    # oc config view --flatten --minify > cluster-cert.txt
    
    #  cat cluster-cert.txt
    apiVersion: v1
    clusters:
    - cluster:
        insecure-skip-tls-verify: true  ← {{ this is what you need }}
        server: https://api.ocp4.infra.local:6443 ← {{ this is what you need }}
      name: api-ocp4-infra-local:6443
    contexts:
    - context:
        cluster: api-ocp4-infra-local:6443
        namespace: project-user01
        user: user01/api-ocp4-infra-local:6443
      name: project-user01/api-ocp4-infra-local:6443/user01
    current-context: project-user01/api-ocp4-infra-local:6443/user01
    kind: Config
    preferences: {}
    users:
    - name: user01/api-ocp4-infra-local:6443
      user:
        token: EAkB_pyYCeSUw65NZMQeqvLzoE8Svdn_KRRfrZGgSMs

Copy two pieces of information from here certificate-authority-data and server

### Create a kubeconfig file

From the steps above, you should have the following pieces of information
  - token
  - Certificate-authority-data
  - server

Create a file called auth/kubeconfig and paste this content on to it


    #cat > auth/kubeconfig << EOF
    apiVersion: v1
    kind: Config
    users:
    - name: ${USER}
      user:
        token: <replace this with token info>
    clusters:
    - cluster:
        certificate-authority-data: <replace this with certificate-authority-data info>
        server: <replace this with server info>
      name: self-hosted-cluster
    contexts:
    - context:
        cluster: self-hosted-cluster
        user: ${USER}
      name: ${USER}
    current-context: svcs-acct-context
    EOF

Replace the placeholder above with the information gathered so far
  - replace the token
  - replace the certificate-authority-data
  - replace the server

    # oc adm policy add-role-to-user admin system:serviceaccount:project-user01:${USER}



