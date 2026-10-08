package main

import rego.v1

erlaubte_registries := ["reg-build:5000/", "reg-ziel:5000/"]

workloads := {"Deployment", "StatefulSet", "DaemonSet", "Job"}

# Alle Container einsammeln, egal ob Pod oder Workload
container contains c if {
	input.kind in workloads
	some c in input.spec.template.spec.containers
}

container contains c if {
	input.kind == "Pod"
	some c in input.spec.containers
}

pod_spec := input.spec.template.spec if input.kind in workloads

pod_spec := input.spec if input.kind == "Pod"

erlaubt(image) if {
	some prefix in erlaubte_registries
	startswith(image, prefix)
}

deny contains msg if {
	some c in container
	not erlaubt(c.image)
	msg := sprintf(
		"Container '%s': Image '%s' nicht aus erlaubter Registry",
		[c.name, c.image],
	)
}

deny contains msg if {
	some c in container
	endswith(c.image, ":latest")
	msg := sprintf("Container '%s': Tag :latest ist nicht erlaubt", [c.name])
}

deny contains msg if {
	some c in container
	not c.resources.limits.memory
	msg := sprintf("Container '%s': Memory-Limit fehlt", [c.name])
}

deny contains msg if {
	some c in container
	not c.resources.limits.cpu
	msg := sprintf("Container '%s': CPU-Limit fehlt", [c.name])
}

deny contains msg if {
	pod_spec
	not pod_spec.securityContext.runAsNonRoot
	msg := sprintf(
		"%s '%s': runAsNonRoot muss true sein",
		[input.kind, input.metadata.name],
	)
}

warn contains msg if {
	input.kind in workloads
	not input.metadata.labels.team
	msg := sprintf("%s '%s': Label 'team' fehlt", [input.kind, input.metadata.name])
}
