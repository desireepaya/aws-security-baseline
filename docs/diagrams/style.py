from diagrams import Edge

GRAPH_ATTR = {"fontsize": "20", "bgcolor": "white", "pad": "0.4"}


def data_flow(label=""):
    return Edge(label=label, color="#232F3E")


def trust(label=""):
    return Edge(label=label, color="#7A5AF8", style="dashed")