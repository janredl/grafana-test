# Create a stack
provider "grafana" {
  alias         = "cloud"
  cloud_api_key = "glc_eyJvIjoiMTA1MTc3MSIsIm4iOiJ0ZXN0LWFjY2Vzcy1wb2xpY3ktdGVzdC1hbGwtc3RhY2tzLXRva2VuIiwiayI6Im1uNDNGSzk2RUxMRTZHMWtNcjVJTzA5NiIsIm0iOnsiciI6InByb2QtZXUtd2VzdC0yIn19"
}

resource "grafana_cloud_stack" "stack" {
  provider = grafana.cloud

  name        = "redltest"
  slug        = "redltest"
  region_slug = "eu"
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
  provider = grafana.cloud

  folder = grafana_folder.my_folder.uid
  config_json = jsonencode({
    "title" : "My Test Dashboard",
    "uid" : "my-test-dashboard"
  })
}
