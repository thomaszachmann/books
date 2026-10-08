Rollout-Plan: <Regelname>  (Changelog-ID: POL-<nr>)

1. Ziel und Risiko: Welches Risiko senkt die Regel? Quelle (Audit, Vorfall)?
2. Betroffene: Anzahl Verstoesse laut Audit-Report am <Datum>, Teams: <Liste>
3. Golden Path: Template/Basis-Image/Doku-Link, das die Regel erfuellt
4. Zeitplan:
   - T-6 Wochen <Datum>: Ankuendigung, Audit-Modus
   - T-3 Wochen <Datum>: Warnung (emitWarning, CI --audit-warn)
   - T-1 Woche  <Datum>: Frist fuer Ausnahmeantraege
   - T          <Datum>: Enforce per MR <Link>, Change <Nr>
   - T+2 Wochen <Datum>: Review
5. Ausnahmen: per MR auf exceptions.yaml, max. 90 Tage
6. Rueckfallplan: Revert-MR auf Audit, wer darf ihn mergen?
7. Erfolgskriterium: Anteil konformer Deployments > 95 % nach T+2 Wochen
