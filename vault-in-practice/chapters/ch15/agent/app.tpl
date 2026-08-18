{{- with secret "meridian/data/tracking" -}}
{
  "database": {
    "user": "{{ .Data.data.db_user }}",
    "password": "{{ .Data.data.db_password }}"
  }
}
{{- end -}}
