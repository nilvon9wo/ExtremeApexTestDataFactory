# Custom Value Expressions

XFTY ships the [plumbing, not a mini-expression-language](../use/value-expressions.md).
Anything with real logic is a small class you write. The bundled
`XFTY_*Expression` classes are just implementations of the same two interfaces — a boolean derived
from a birthdate, a code built by concatenating a parent's Id fragment, a status
that mirrors a child's stage: all of it is an ordinary class.

There are **three** interfaces, one per "how much of the graph does the value
need to see":

| Interface | The value depends on | Runs |
|---|---|---|
| `XFTY_ValueExpressionIntf` | nothing but itself | first value pass |
| `XFTY_ContextAwareExpressionIntf` | other fields on the same record (**siblings**), or a generated **ancestor** | second value pass, per record |
| `XFTY_DeferredExpressionIntf` | a generated **child / descendant** | during `XFTY_DeferredInserter.flush()` |

---

## A plain value expression — `XFTY_ValueExpressionIntf`

One no-argument method:

```apex
@IsTest
public class NextWeekday implements XFTY_ValueExpressionIntf {
    public Object get() {
        Date candidate = Date.today().addDays(1);
        while (isWeekend(candidate)) {
            candidate = candidate.addDays(1);
        }
        return candidate;
    }

    private static Boolean isWeekend(Date day) {
        Date startOfWeek = day.toStartOfWeek();   // Sunday
        return day == startOfWeek || day == startOfWeek.addDays(6);
    }
}
```

```apex
.put(Task.ActivityDate, new NextWeekday())
```

Stateful expressions (incrementing, unique) are fine and common — see
[../reference/salesforce-considerations.md](../reference/salesforce-considerations.md)
for why that means avoiding `@TestSetup`.

**Limitation:** `get()` sees nothing else. If the value has to look at another
field, it is a context-aware value, not this.

---

## Reading a sibling — `XFTY_ContextAwareExpressionIntf`

A **separate** interface (a context-aware value genuinely cannot produce anything
without a context, so it does not pretend to satisfy the no-argument contract):

```apex
@IsTest
public class IsAdultFlag implements XFTY_ContextAwareExpressionIntf {
    public Object get(XFTY_GenerationContext context) {
        Date birthdate = (Date) context.siblingValue(Contact.Birthdate);
        return birthdate != null && birthdate.addYears(18) <= Date.today();
    }
}
```

Read siblings with **`context.siblingValue(field)`**, not
`context.recordBeingBuilt.get(field)`: the guarded accessor throws a clear error
if `field` is another context-aware value that has not been generated yet, rather
than returning a misleading `null`.

**Limitations:**

- Context-aware values are generated **in `put` order**. `siblingValue(x)` only
  works if `x` was `put` before this field (or is a plain value / override — those
  are all done first). Reading a *later* context-aware sibling throws, naming both
  fields and the fix.
- Only fields **on this record** are siblings. A field on a parent is an
  ancestor read (below); a field on a child is a descendant read (below).

---

## Reading a generated ancestor — `XFTY_ContextAwareExpressionIntf`

The context carries the graph generated so far. `context.bundleSoFar.getList(relationshipField)`
is the parent for each primary, aligned 1:1 — pick this record's with
`context.rowIndex`:

```apex
@IsTest
public class AccountNamePlusRegion implements XFTY_ContextAwareExpressionIntf {
    public Object get(XFTY_GenerationContext context) {
        Account parentAccount = ancestorAccount(context);
        return (parentAccount == null)
                ? null
                : parentAccount.Name + ' - ' + parentAccount.ShippingCountry;
    }

    private static Account ancestorAccount(XFTY_GenerationContext context) {
        if (context.bundleSoFar == null || context.rowIndex < 0) {
            return null;
        }
        List<SObject> accounts = context.bundleSoFar.getList(Contact.AccountId);
        return (accounts == null || context.rowIndex >= accounts.size())
                ? null
                : (Account) accounts[context.rowIndex];
    }
}
```

`context.bundleSoFar.getValue(new List<SObjectField>{ Contact.AccountId, Account.ShippingCountry }, context.rowIndex)`
does the same walk in one call — use it instead of the hand-written
`ancestorAccount` helper when you only need a field, not the whole record.
`XFTY_CopyFromAncestorExpression` is that walk wrapped as a ready-made context-aware value
(multi-hop: each leading field is a `getBundle(...)` down, the last is the field
to read). Reach for it first; write your own only when the value is a
transformation, not a straight copy.

**Limitations:**

- The ancestor must actually have been **generated** — its relationship has to be
  covered by the call's [inclusivity](../use/relationships.md#inclusivity) (or
  forced with [`includeOptional(...)`](../use/per-call-relationships.md)). If it
  was not, `getList(field)` is `null`; return `null`, do not throw.
- **You see the ancestor before it is inserted.** Its non-Id fields are fully
  generated and safe to read in any mode. Its **`Id`** is only real under `NOW`
  (the parent is inserted before the child's value pass); it is a consistent mock
  under `MOCK`, and **`null` under `NEVER` and `DEFERRED`** — the value pass runs
  before `flush()`. If a child needs the parent's real Id under `DEFERRED`, put
  it in the **lookup field** (normal relationship generation — the depth-batched
  insert wires it); a context-aware value into any other field cannot get it.
  This is proven in `XFTY_Ex_Extend_CustomExpressionsTest`.

---

## Reading a generated child / descendant — `XFTY_DeferredExpressionIntf`

A child does not exist when its parent is built, so an up-flowing value cannot
run in either in-line pass. It gets its own interface and runs during
`XFTY_DeferredInserter.flush()`, over the whole forest:

```apex
@IsTest
public class HasAnyOpenChildCase implements XFTY_DeferredExpressionIntf {
    public Object get(XFTY_DeferredGraph graph, Integer recordIndex) {
        for (SObject child : graph.childrenOf(recordIndex, Case.AccountId)) {
            if (((Case) child).IsClosed == false) {
                return true;
            }
        }
        return false;
    }
}
```

```apex
.put(Account.Description, new HasAnyOpenChildCase())
```

`graph.childrenOf(recordIndex, childLookupField)` returns every generated record
that references this one through `childLookupField` — whether it is the child
that *requested* this parent, or a row from a `withChildren(...)` collection.
`XFTY_CopyFromDescendantExpression` is the straight-copy case of this.

**Limitations:**

- **`DEFERRED` (or `.depthBatched()`) only.** A Provider carrying one of these in
  any other insert mode **throws** — the forest never exists otherwise.
- The value is filled at `flush()`. Before that the field is `null`; a
  `DEFERRED` build that never calls `flush()` leaves it `null`.
- Only **direct** children (`childrenOf` follows one parent link). Grandchildren
  are not walked; read them from a child's own deferred value if you need them.

---

## Testing

A custom expression earns a test the same way a [Provider](providers.md) does —
generate with it, assert the value. The models:

- `XFTY_ValueExpressionTest` — plain expressions.
- `XFTY_ContextAwareExpressionTest` — sibling + ancestor reads.
- `XFTY_CopyFromDescendantExpressionTest` — up-flow reads under `DEFERRED`.
- `XFTY_Ex_Adv_MatchingValuesTest` — a worked custom expression end to end.

▶ Runnable: `XFTY_Ex_Extend_CustomExpressionsTest`
