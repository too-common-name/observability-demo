from diagrams import Diagram, Cluster, Edge
from diagrams.k8s.compute import Pod, DaemonSet
from diagrams.k8s.infra import Node
from diagrams.onprem.monitoring import Prometheus
from diagrams.onprem.tracing import Tempo
from diagrams.onprem.logging import Loki
from diagrams.custom import Custom
from diagrams.onprem.network import Tomcat

# Graph attributes to help with layout spacing and label placement
graph_attr = {"splines": "spline", "nodesep": "0.6", "ranksep": "0.8", "rankdir": "LR"}

with Diagram(
    "Observability Demo Architecture",
    filename="../images/observability_demo_architecture",
    show=True,
    graph_attr=graph_attr,
):

    with Cluster("Visualization & Intelligence"):
        ols = Custom("OpenShift Lightspeed", "./icons/ols.png")
        perses = Custom("Perses", "./icons/perses.png")

        with Cluster("Cluster Observability Operator"):
            troubleshooting = Custom("Troubleshooting\n(Korrel8r)", "./icons/coo.png")
            incidents = Custom(
                "Incidents\n(Cluster Health Analyzer)", "./icons/coo.png"
            )

    with Cluster("Platform Observability"):
        blank_observability_platform = Node(
            "", shape="plaintext", width="0", height="0"
        )
        uwm = Prometheus("UWM Prometheus\n(Metrics)")
        tempo = Tempo("Tempo\n(Traces)")
        loki = Loki("Loki\n(Logs)")

    with Cluster("observability-demo Project"):
        otel_col = Pod("App Collector\n(Deployment)")

        with Cluster("Workloads"):
            quarkus = Pod("Quarkus App")
            spring = Tomcat("Spring Boot App")

    with Cluster("Cluster Nodes"):
        infra_col = DaemonSet("Infra Collector\n(DaemonSet)")
        kubelet = Node("Kubelet API")

    # Apps push OTLP to Collector
    quarkus >> Edge(label="OTLP") >> otel_col
    spring >> Edge(label="OTLP") >> otel_col

    # Collector exports to Store (Destination implies data type: Tempo=Traces, Loki=Logs)
    otel_col >> Edge() >> tempo
    otel_col >> Edge() >> loki

    # Infra Collector exports logs (Added missing connection)
    infra_col >> Edge() >> loki

    # Prometheus scrapes the collectors
    uwm >> Edge(style="dashed", color="darkgray") >> otel_col
    uwm >> Edge(style="dashed", color="darkgray") >> infra_col

    # Infra Collector scrapes Kubelet
    infra_col >> Edge(style="dashed", color="darkgray", label="stats") >> kubelet

    # Troubleshooting correlates data (Red/Firebrick indicates "Investigation")
    (
        troubleshooting
        >> Edge(color="firebrick", label="Correlate signals")
        >> blank_observability_platform
    )

    # Incidents checks health
    incidents >> Edge(color="firebrick", label="Query") >> uwm

    # OLS asks Incidents
    ols >> Edge(color="firebrick", label="Analyze") >> incidents

    # Perses visualizes
    perses >> Edge(color="firebrick") >> uwm
