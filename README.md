Need to have a vars.tf file localy 
```
variable "exo_key" {
    type = string
    sensitive = true
    default = "Your_key"
}
variable "exo_secret" {
    type = string
    sensitive = true
    default = "Your_secret"
}
```
