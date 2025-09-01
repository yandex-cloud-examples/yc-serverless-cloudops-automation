output "function_up_id" {
  description = "ID of the created function"
  value       = yandex_function.scale-up.id
}

output "function_up_name" {
  description = "Name of the created function"
  value       = yandex_function.scale-up.name
}

output "function_down_id" {
  description = "ID of the created function"
  value       = yandex_function.scale-down.id
}

output "function_down_name" {
  description = "Name of the created function"
  value       = yandex_function.scale-down.name
}