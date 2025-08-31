output "function_id" {
  description = "ID of the created function"
  value       = yandex_function.main.id
}

output "function_name" {
  description = "Name of the created function"
  value       = yandex_function.main.name
}