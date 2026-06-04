variable "config" {
  description = "Global configuration object from root"
  type = object({
    project_name = string
    environment  = string
  })
}
