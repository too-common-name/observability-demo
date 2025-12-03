from diagrams import Diagram, Cluster
from diagrams.k8s.compute import Pod
from diagrams.k8s.infra import Node
from diagrams.k8s.network import Service
from diagrams.onprem.monitoring import Prometheus
from diagrams.onprem.tracing import Tempo
from diagrams.onprem.logging import Loki
from diagrams.onprem.compute import Server
from diagrams.onprem.monitoring import Grafana

with Diagram("hld", show=True, direction="TB"):

    # Backend
    backend_metrics = Prometheus("Prometheus Metrics")
    backend_traces = Tempo("Tempo Traces")
    backend_logs = Loki("Loki Logs")
    grafana = Grafana("Grafana Dashboards")

    # Collectors
    infra_collector = Server("Infra Collector\n(Deployment)")
    app_collector = Server("App Collector\n(Deployment)")

    # Infra sources
    with Cluster("Cluster Infra"):
        kubevirt_service = Service("KubeVirt Metrics\n(kubevirt-prometheus-metrics)")
        nodes = [Node(f"Node-{i}") for i in range(1, 4)]
        vm_pods = [Pod(f"VM-Pod-{i}") for i in range(1, 4)]

    # App sources
    with Cluster("App Namespace"):
        app_pods = [Pod(f"MyApp-Pod-{i}") for i in range(1, 4)]

    # Connections
    kubevirt_service >> infra_collector
    for n in nodes:
        n >> infra_collector
    for p in vm_pods:
        p >> infra_collector

    for p in app_pods:
        p >> app_collector

    # Export to backend
    infra_collector >> backend_metrics
    app_collector >> backend_metrics
    app_collector >> backend_traces
    app_collector >> backend_logs

    # Dashboards read all
    backend_metrics >> grafana
    backend_traces >> grafana
    backend_logs >> grafana
