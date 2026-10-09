# docs/diagrams/keel.py
from diagrams import Diagram, Cluster
from diagrams.aws.management import Cloudtrail

from style import GRAPH_ATTR, data_flow, trust

with Diagram(
    "Keel",
    filename="keel",
    show=False,
    direction="LR",
    graph_attr=GRAPH_ATTR,
):
    trail = Cloudtrail("org trail")