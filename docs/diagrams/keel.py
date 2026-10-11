"""
Reader should recognize:
1. the account hierarchy, and see the two separate OUs
2. see that logging is centralized in the Mgmt account
3. human access is thru IDC
4. an emergency access path exists thru IAM
5. assuming the break-glass role triggers an alert email
6. security services are administered from the Security tooling, not Mgmt, and tier 1 instrumentation is enabled
"""
from diagrams import Diagram, Cluster
from diagrams.aws.management import Cloudtrail, Organizations, OrganizationsAccount
from diagrams.aws.general import User
from diagrams.oci.monitoring import Email
from diagrams.aws.integration import EventbridgeRule, SimpleNotificationServiceSnsTopic
from diagrams.aws.security import IAMAccessAnalyzer, IAMRole, IAMAWSSts, SingleSignOn, Guardduty, KMS
from diagrams.aws.storage import S3
from style import GRAPH_ATTR, data_flow, trust


# Accounts: which accounts appear? (these become Clusters)
# Org holds Mgmt account, Security OU with the Security Tooling account, Workloads OU with the Sandbox account

# Nodes: which services, in which account?
# External (outside Org): Human, Email
with Diagram("Keel Architecture", show=False, direction="LR", graph_attr=GRAPH_ATTR):
    with Cluster("External"):
        human = User("Operator")
        email = Email("Alert email")
    
    # Mgmt: Organizations
    with Cluster("AWS Organization"):
        # PlatformAdmin
        plat_admin = IAMRole("PlatformAdmin (all accounts)")
        # SecurityAnalyst
        sec_analyst = IAMRole("SecurityAnalyst (all accounts)")

        with Cluster("Management Account"):
            orgs = Organizations("Organization")
            # Mgmt: CloudTrail, s3 bucket, KMS
            trail = Cloudtrail("Org Trail (all accounts)")
            bucket = S3("Log bucket")
            kms = KMS("Encryption key")
            # Mgmt: break-glass user, break-glass role, STS, EventBridge rule, SNS topic
            bg_user = User("Break-glass IAM user")
            bg_role = IAMRole("Break-glass role")
            sts = IAMAWSSts("STS")
            rule = EventbridgeRule("Break-glass rule")
            sns_topic = SimpleNotificationServiceSnsTopic("SNS Topic")
            #Identity Center
            idc = SingleSignOn("IAM Identity Center")

        with Cluster("Workloads OU"):
                    sandbox = OrganizationsAccount("Sandbox")
        with Cluster("Security OU"):
            with Cluster("Security Tooling account"):
                # Security tooling (delegated admin): GuardDuty, IAM Access Analyzer
                guard_duty = Guardduty("GuardDuty")
                access_analyzer = IAMAccessAnalyzer("Access Analyzer")

    # Flows (logging):
    # CloudTrail -> S3 bucket (data: log files, encrypted)
    trail >> data_flow("log files, encrypted") >> bucket
    kms >> trust("encrypts") >> bucket
    
    # Flows (break-glass):
    # Human -> break-glass user         (trust/dashed: signs in, MFA)
    # break-glass user -> STS           (trust/dashed: AssumeRole, MFA required)
    # STS -> break-glass role (admin)   (trust/dashed: temporary credentials)
    # STS -> CloudTrail                 (data/solid: AssumeRole event)
    # CloudTrail -> EventBridge rule    (data/solid: event matched on role ARN)
    # EventBridge rule -> SNS topic     (data/solid: alert)
    # SNS topic -> Email                (data/solid: notification)
    human >> trust("signs in, MFA") >> bg_user
    bg_user >> trust("AssumeRole, MFA required") >> sts
    sts >> trust("temporary credentials") >> bg_role
    sts >> data_flow("AssumeRole event") >> trail 
    trail >> data_flow("event matched on role ARN") >> rule 
    rule >> data_flow("alert") >> sns_topic 
    sns_topic >> data_flow("notification") >> email

    # Flows (human access):
    # Human -> IAM Identity Center            (trust/dashed: signs in via portal)
    # IAM Identity Center -> PlatformAdmin   (trust/dashed: Platform Admins group, all accounts)
    # IAM Identity Center -> SecurityAnalyst   (trust/dashed: Security Analysts group, read-only, all accounts)
    human >> trust("signs in via portal") >> idc 
    idc >> trust("Platform Admins") >> plat_admin
    idc >> trust("Security Analysts, read-only") >> sec_analyst
    # Flows (delegated admin):
    # Organizations -> GuardDuty        (trust/dashed: delegated admin)
    # Organizations -> Access Analyzer  (trust/dashed: delegated admin)
    orgs >> trust("delegated admin") >> [guard_duty,access_analyzer]

