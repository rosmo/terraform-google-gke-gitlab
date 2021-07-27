# Values for gitlab/gitlab chart on GKE
global:
  edition: ce
  hosts:
    domain: ${DOMAIN}
    https: true
    gitlab: {}
    externalIP: ${INGRESS_IP}
    ssh: %{ if USE_GCLB }${SSH_HOST}%{ else }~%{ endif }

  ## doc/charts/globals.md#configure-ingress-settings
  ingress:
    configureCertmanager: %{ if ! USE_GCLB }true%{ else }false%{ endif }
    enabled: %{ if ! USE_GCLB }true%{ else }false%{ endif }
    tls:
      enabled: %{ if ! USE_GCLB }true%{ else }false%{ endif }

  ## doc/charts/globals.md#configure-postgresql-settings
  psql:
    password:
      secret: gitlab-pg
      key: password
    host: ${DB_PRIVATE_IP}
    port: 5432
    username: gitlab
    database: gitlabhq_production

  redis:
    password:
      enabled: false
    host: ${REDIS_PRIVATE_IP}

  ## doc/charts/globals.md#configure-minio-settings
  minio:
    enabled: false

%{ if USE_GCLB }
  shell:
    port: 5222
%{ endif }

  ## doc/charts/globals.md#configure-appconfig-settings
  ## Rails based portions of this chart share many settings
  appConfig:
    ## doc/charts/globals.md#general-application-settings
    enableUsagePing: false

    ## doc/charts/globals.md#lfs-artifacts-uploads-packages
    backups:
      bucket: ${PROJECT_ID}-gitlab-backups
    lfs:
      bucket: ${PROJECT_ID}-git-lfs
      connection:
        secret: gitlab-rails-storage
        key: connection
    artifacts:
      bucket: ${PROJECT_ID}-gitlab-artifacts
      connection:
        secret: gitlab-rails-storage
        key: connection
    uploads:
      bucket: ${PROJECT_ID}-gitlab-uploads
      connection:
        secret: gitlab-rails-storage
        key: connection
    packages:
      bucket: ${PROJECT_ID}-gitlab-packages
      connection:
        secret: gitlab-rails-storage
        key: connection

    ## doc/charts/globals.md#pseudonymizer-settings
    pseudonymizer:
      bucket: ${PROJECT_ID}-gitlab-pseudo
      connection:
        secret: gitlab-rails-storage
        key: connection

certmanager-issuer:
  email: ${CERT_MANAGER_EMAIL}

%{ if USE_GCLB }
certmanager:
  install: false

nginx-ingress:
  enabled: false
%{ endif }

prometheus:
  install: false

redis:
  install: false

gitlab:
  gitaly:
    persistence:
      size: 200Gi
      storageClass: "pd-ssd"
  task-runner:
    backups:
      objectStorage:
        backend: gcs
        config:
          secret: google-application-credentials
          key: gcs-application-credentials-file
          gcpProject: ${PROJECT_ID}
%{ if USE_GCLB }
  webservice:
    service:
      annotations:
        cloud.google.com/neg: '{"exposed_ports": {"8080":{},"8181":{}}}'
        controller.autoneg.dev/neg: '{"backend_services":{"8080":[{"name":"${BACKEND}","max_rate_per_endpoint":100},{"name":"${BACKEND_INTERNAL}","region":"${REGION}","max_rate_per_endpoint":100}],"8181":[{"name":"${WORKHORSE_BACKEND}","max_rate_per_endpoint":100},{"name":"${WORKHORSE_BACKEND_INTERNAL}","region":"${REGION}","max_rate_per_endpoint":100}]}}'
%{ endif }

%{ if USE_GCLB }  
  gitlab-shell:
    service:
      annotations:
        cloud.google.com/neg: '{"exposed_ports": {"5222":{}}}'
        controller.autoneg.dev/neg: '{"backend_services":{"5222":[{"name":"${SHELL_BACKEND}","max_connections_per_endpoint":100}]}}'
%{ endif }

postgresql:
  install: false

gitlab-runner:
  install: ${GITLAB_RUNNER_INSTALL}
  rbac:
    create: true
  runners:
    locked: false
    cache:
      cacheType: gcs
      gcsBucketName: ${PROJECT_ID}-runner-cache
      secretName: google-application-credentials
      cacheShared: true
%{ if USE_GCLB }  
  gitlabUrl: http://${INTERNAL_IP}
%{ endif }

registry:
  enabled: true
%{ if USE_GCLB }  
  service:
    annotations:
      cloud.google.com/neg: '{"exposed_ports": {"5000":{}}}'
      controller.autoneg.dev/neg: '{"backend_services":{"5000":[{"name":"${REGISTRY_BACKEND}","max_rate_per_endpoint":100}]}}'
%{ endif }
  storage:
    secret: gitlab-registry-storage
    key: storage
    extraKey: gcs.json

