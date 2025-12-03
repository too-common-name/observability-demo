# Study
https://www.youtube.com/watch?v=TmC7Ha3Qqk4&t=6s
https://grafana.com/docs/tempo/latest/introduction/architecture/#components
https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/distributed_tracing/distr-tracing-tempo-installing
https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/observability/red_hat_build_of_opentelemetry/install-otel#install-otel
https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/observability/red_hat_build_of_opentelemetry/index#otel-forwarding-telemetry-data
https://fabreur.medium.com/openshift-telemetry-configuring-tempostack-and-opentelemetry-6d19daea6c8a

# demo step

Requirements:
- Otel
- Tempo
- COO

- Apply demo/operators folder to install operators
- Check status with:
oc get csv -n openshift-opentelemetry-operator
oc get csv -n openshift-tempo-operator
- Create Otel backend resources (Collector) applying demo/backend_infrastructure/opentelemetry
- Verify that the status.phase of the OpenTelemetry Collector pod is Running and the conditions are type: Ready by running the following command:
`oc get pod -l app.kubernetes.io/managed-by=opentelemetry-operator,app.kubernetes.io/instance=<namespace>.<instance_name> -o yaml`
- Get the OpenTelemetry Collector service by running the following command:
`oc get service -l app.kubernetes.io/managed-by=opentelemetry-operator,app.kubernetes.io/instance=<namespace>.<instance_name>`