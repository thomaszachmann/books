package main

import rego.v1

# Hilfsfunktion: baut ein Deployment mit Image und runAsNonRoot-Wert
deployment(image, non_root) := {
	"kind": "Deployment",
	"metadata": {"name": "t", "labels": {"team": "demo"}},
	"spec": {"template": {"spec": {
		"securityContext": {"runAsNonRoot": non_root},
		"containers": [{
			"name": "app",
			"image": image,
			"resources": {"limits": {"cpu": "100m", "memory": "64Mi"}},
		}],
	}}},
}

test_gutes_deployment_erlaubt if {
	count(deny) == 0 with input as deployment("reg-build:5000/demo-app:1.0.0", true)
}

test_latest_verboten if {
	msgs := deny with input as deployment("reg-build:5000/demo-app:latest", true)
	some msg in msgs
	contains(msg, ":latest")
}

test_fremde_registry_verboten if {
	msgs := deny with input as deployment("docker.io/library/nginx:1.27", true)
	some msg in msgs
	contains(msg, "nicht aus erlaubter Registry")
}

test_root_verboten if {
	msgs := deny with input as deployment("reg-ziel:5000/demo-app:1.0.0", false)
	some msg in msgs
	contains(msg, "runAsNonRoot")
}

test_service_wird_ignoriert if {
	count(deny) == 0 with input as {"kind": "Service", "metadata": {"name": "s"}}
}
