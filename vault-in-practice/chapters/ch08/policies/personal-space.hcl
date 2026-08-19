# Chapter 8, Step 9 - one policy, correct for every entity.
# {{identity.entity.name}} resolves per token at request time.

path "meridian/data/personal/{{identity.entity.name}}" {
  capabilities = ["create", "read", "update", "delete"]
}
