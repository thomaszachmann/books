# Chapter 6 - broad grant with an explicit exception.
# The exact path is more specific than the glob, and deny always wins.

path "meridian/data/app/*" {
  capabilities = ["read"]
}

path "meridian/data/app/production" {
  capabilities = ["deny"]
}
