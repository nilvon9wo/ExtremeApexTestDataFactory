# Custom Value Strategies

XFTY ships the [plumbing, not a mini-expression-language](../use/value-strategies.md).
Anything with real logic is a small class you write.

---

## A plain value strategy

Implement `XFTY_DummyDefaultValueIntf` — one no-argument method:

```apex
@IsTest
public class NextBusinessDay implements XFTY_DummyDefaultValueIntf {
    public Object get() {
        Date d = Date.today().addDays(1);
        while (d.toStartOfWeek() == d || d.addDays(1).toStartOfWeek() == d.addDays(1)) {
            d = d.addDays(1);
        }
        return d;
    }
}
```

```apex
.put(Task.ActivityDate, new NextBusinessDay())
```

Stateful strategies (incrementing, unique) are fine and common — see
[../reference/salesforce-considerations.md](../reference/salesforce-considerations.md)
for why that means avoiding `@TestSetup`.

---

## A context-aware strategy

When the value depends on other fields on the record, implement
`XFTY_ContextAwareValueIntf` instead — a **separate** interface, one method
taking the generation context:

```apex
@IsTest
public class IsAdultFlag implements XFTY_ContextAwareValueIntf {
    public Object get(XFTY_GenerationContext context) {
        Date birthdate = (Date) context.siblingValue(Contact.Birthdate);
        return birthdate != null && birthdate.addYears(18) <= Date.today();
    }
}
```

Read siblings with `context.siblingValue(field)`, not
`context.recordBeingBuilt.get(field)` — the guarded accessor throws a clear
error if `field` is another context-aware value that has not been generated yet,
rather than returning a misleading `null`. Full contract and the `put`-ordering
rule: [../use/context-aware-values.md](../use/context-aware-values.md).

---

## Testing

A custom strategy earns a test the same way a [Provider](providers.md) does —
generate with it, assert the value. XFTY's own
`XFTY_ContextAwareValueTest` and `XFTY_DefaultValueStrategyTest` are the models.
