data "tfe_organization" "org" {
  name = var.hcp_tf_org_name
}

############################################################################
# HCP Terrform : VCS 연동 및 Module 등록
############################################################################
resource "tfe_oauth_client" "vcs" {
  for_each         = var.vcs_info
  name             = each.key
  organization     = data.tfe_organization.org.name
  api_url          = each.value.api_url
  http_url         = each.value.http_url
  oauth_token      = each.value.api_token
  service_provider = each.value.service_provider
}


############################################################################
# HCP Terrform : 프로젝트 및 워크스페이스 생성
############################################################################
resource "tfe_project" "project" {
  name         = var.hcp_tf_project_name
  organization = data.tfe_organization.org.name
}

resource "tfe_workspace" "workspaces" {
  for_each     = var.hcp_tf_workspace_vcs
  name         = each.key
  organization = data.tfe_organization.org.name
  tag_names    = each.value.workspace_tag_name
  project_id   = tfe_project.project.id
  vcs_repo {
    identifier     = each.value.vcs_repo_identifier
    oauth_token_id = tfe_oauth_client.vcs["junholee_github"].oauth_token_id
  }
  force_delete        = true
  auto_apply          = each.value.auto_apply
  queue_all_runs      = false
  trigger_patterns    = each.value.trigger_patterns
  working_directory   = each.value.working_directory
  assessments_enabled = false
}

resource "tfe_workspace_settings" "workspaces" {
  for_each            = var.hcp_tf_workspace_vcs
  workspace_id        = tfe_workspace.workspaces[each.key].id
  execution_mode      = each.value.execution_mode
  global_remote_state = true
}


############################################################################
# HCP Terraform : 변수 세트 및 변수 설정
############################################################################
resource "tfe_variable_set" "sets" {
  for_each     = local.variable_sets
  name         = each.value.name
  organization = data.tfe_organization.org.name
}

resource "tfe_variable" "variables" {
  for_each = { for idx, var_data in flatten([
    for var_set_key, var_set_value in local.variable_sets : [
      for var_key, var_value in var_set_value.variables : {
        key          = var_key
        value        = var_value.value
        category     = var_value.category
        sensitive    = lookup(var_value, "sensitive", false)
        description  = lookup(var_value, "description", null)
        variable_set = var_set_key
      }
    ]
  ]) : idx => var_data }

  key             = each.value.key
  value           = each.value.value
  category        = each.value.category
  sensitive       = each.value.sensitive
  description     = each.value.description
  variable_set_id = tfe_variable_set.sets[each.value.variable_set].id
}

resource "tfe_project_variable_set" "project_variable_sets" {
  for_each        = tfe_variable_set.sets
  variable_set_id = each.value.id
  project_id      = tfe_project.project.id
}