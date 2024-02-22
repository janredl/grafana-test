locals {
  cloud_region = "eu"
  http_target  = "https://test-buga.fg.cz/"
}

# Create a stack
provider "grafana" {
  alias         = "cloud"
  cloud_api_key = "glc_eyJvIjoiMTA1MTc3MSIsIm4iOiJ0ZXN0LWFjY2Vzcy1wb2xpY3ktdGVzdC1hbGwtc3RhY2tzLXRva2VuIiwiayI6Im1uNDNGSzk2RUxMRTZHMWtNcjVJTzA5NiIsIm0iOnsiciI6InByb2QtZXUtd2VzdC0yIn19"
}

resource "grafana_cloud_stack" "stack" {
  provider = grafana.cloud

  name        = "redltest"
  slug        = "redltest"
  region_slug = local.cloud_region
  description = "Test Grafana Cloud Stack"
}

# Create a service account and key for the stack
resource "grafana_cloud_stack_service_account" "cloud_sa" {
  provider   = grafana.cloud
  stack_slug = grafana_cloud_stack.stack.slug

  name        = "cloud service account"
  role        = "Admin"
  is_disabled = false
}

resource "grafana_cloud_stack_service_account_token" "cloud_sa" {
  provider   = grafana.cloud
  stack_slug = grafana_cloud_stack.stack.slug

  name               = "stack cloud_sa key"
  service_account_id = grafana_cloud_stack_service_account.cloud_sa.id
}

# Create resources within the stack
provider "grafana" {
  alias = "stack"

  url  = grafana_cloud_stack.stack.url
  auth = grafana_cloud_stack_service_account_token.cloud_sa.key
}

resource "grafana_folder" "my_folder" {
  provider = grafana.stack

  title = "Test folder"
}

resource "grafana_dashboard" "my_dashboard" {
  provider = grafana.stack

  folder = grafana_folder.my_folder.uid
  config_json = jsonencode({
    "title" : "My Test Dashboard",
    "uid" : "my-test-dashboard"
  })
}

//Install Synthetic Monitoring on the stack
resource "grafana_cloud_access_policy" "sm_metrics_publish" {
  provider = grafana.cloud

  region = local.cloud_region
  name   = "metric-publisher-for-sm"
  scopes = ["metrics:write", "stacks:read"]
  realm {
    type       = "stack"
    identifier = grafana_cloud_stack.stack.id
  }
}

resource "grafana_cloud_access_policy_token" "sm_metrics_publish" {
  provider = grafana.cloud

  region           = local.cloud_region
  access_policy_id = grafana_cloud_access_policy.sm_metrics_publish.policy_id
  name             = "metric-publisher-for-sm"
}

resource "grafana_synthetic_monitoring_installation" "sm_stack" {
  provider = grafana.cloud

  stack_id              = grafana_cloud_stack.stack.id
  metrics_publisher_key = grafana_cloud_access_policy_token.sm_metrics_publish.token
}

provider "grafana" {
  alias           = "sm"
  sm_access_token = grafana_synthetic_monitoring_installation.sm_stack.sm_access_token
  sm_url          = grafana_synthetic_monitoring_installation.sm_stack.stack_sm_api_url
}

data "grafana_synthetic_monitoring_probes" "main" {
  provider   = grafana.sm
  depends_on = [grafana_synthetic_monitoring_installation.sm_stack]
}

resource "grafana_synthetic_monitoring_check" "http" {
  provider = grafana.sm

  job     = "HTTP Defaults"
  target  = local.http_target
  probes = [
    data.grafana_synthetic_monitoring_probes.main.probes.Frankfurt,
  ]
  labels = {
    label1 = "test label"
  }
  settings {
    http {}
  }
}