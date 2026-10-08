| Kriterium          | Legacy | Begründung                              |
|--------------------|--------|-----------------------------------------|
| Basisimage         | 0      | python:latest                           |
| Abhängigkeiten     | 1      | Versionen gepinnt, keine Hashes         |
| Fremdskripte       | 0      | curl | python, curl | bash              |
| Secrets            | 0      | ENV im Image, Passwort im Skript        |
| Laufzeit-User      | 0      | root                                    |
| Build-Host         | 0      | build01, langlebig, privileged          |
| Reproduzierbarkeit | 0      | nicht geprüft                           |
| Provenance         | 0      | keine                                   |
| Summe              | 1/16   | entspricht SLSA Build L0                |
