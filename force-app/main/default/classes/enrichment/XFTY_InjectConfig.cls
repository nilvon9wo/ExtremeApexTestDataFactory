/**
 * What `bundle.inject(field, config)` should materialise. Start from a breadth -
 * `nothing()` (name everything you want), `allParents()`, `allChildren()`,
 * `everything()` - then layer refiners on:
 *
 * - `injectParent(path)` / `injectChild(path)` - add a path (and, in the
 *   enricher, every hop along it);
 * - `excludeParent(path)` / `excludeChild(path)` - prune a subtree from a
 *   breadth start;
 * - `injectValue(field, value)` - a scalar on the working record itself
 *   (formula / roll-up / system / read-only);
 * - `injectValue(path, value)` - a scalar on a record several hops up, where
 *   `path` is the relationship hops then the target field;
 * - `parentDepth(n)` - cap the ancestor climb (default: 5, the SOQL limit);
 * - `childDepth(n)` - reserved; only 1 is supported (a subquery cannot nest),
 *   `n > 1` throws;
 * - `breakSoqlLimits()` - lift the ceiling on `parentDepth` and the `injectParent`
 *   path lengths.
 *
 * A plain state carrier - the enricher reads the fields, nothing here acts.
 * `injectAll(field)` on the bundle is `inject(field, everything())`.
 */
@IsTest
public class XFTY_InjectConfig {

    public static final Integer SOQL_PARENT_HOPS = 5;
    public static final Integer SOQL_CHILD_DEPTH = 1;

    public final Boolean fromAllParents;
    public final Boolean fromAllChildren;

    public final List<List<SObjectField>> includedParentPaths = new List<List<SObjectField>>();
    public final List<List<SObjectField>> includedChildPaths = new List<List<SObjectField>>();
    public final List<List<SObjectField>> excludedParentPaths = new List<List<SObjectField>>();
    public final List<List<SObjectField>> excludedChildPaths = new List<List<SObjectField>>();
    public final Map<SObjectField, Object> onRecordValues = new Map<SObjectField, Object>();
    public final List<AncestorValue> ancestorValues = new List<AncestorValue>();

    public Integer parentDepthLimit = SOQL_PARENT_HOPS;
    public Integer childDepthLimit = SOQL_CHILD_DEPTH;
    public Boolean soqlLimitsLifted = false;

    private XFTY_InjectConfig(Boolean fromAllParents, Boolean fromAllChildren) {
        this.fromAllParents = fromAllParents;
        this.fromAllChildren = fromAllChildren;
    }

    /** Name every parent and child to inject; nothing is materialised by default. */
    public static XFTY_InjectConfig nothing() {
        return new XFTY_InjectConfig(false, false);
    }

    /** Every generated ancestor, to the SOQL parent-hop limit; children only if named. */
    public static XFTY_InjectConfig allParents() {
        return new XFTY_InjectConfig(true, false);
    }

    /** Every generated child collection; parents only if named. */
    public static XFTY_InjectConfig allChildren() {
        return new XFTY_InjectConfig(false, true);
    }

    /** Every generated ancestor and child collection. `bundle.injectAll(field)` uses this. */
    public static XFTY_InjectConfig everything() {
        return new XFTY_InjectConfig(true, true);
    }

    public XFTY_InjectConfig injectParent(List<SObjectField> path) {
        this.includedParentPaths.add(path);
        return this;
    }

    public XFTY_InjectConfig injectChild(List<SObjectField> path) {
        this.includedChildPaths.add(path);
        return this;
    }

    public XFTY_InjectConfig excludeParent(List<SObjectField> path) {
        this.excludedParentPaths.add(path);
        return this;
    }

    public XFTY_InjectConfig excludeChild(List<SObjectField> path) {
        this.excludedChildPaths.add(path);
        return this;
    }

    /** A scalar on the working record - the formula / roll-up / system / read-only case. */
    public XFTY_InjectConfig injectValue(SObjectField field, Object value) {
        this.onRecordValues.put(field, value);
        return this;
    }

    /** A scalar on a record several relationship hops up - `path` is the hops then the target field. */
    public XFTY_InjectConfig injectValue(List<SObjectField> pathToField, Object value) {
        this.ancestorValues.add(new AncestorValue(pathToField, value));
        return this;
    }

    public XFTY_InjectConfig parentDepth(Integer hops) {
        this.parentDepthLimit = hops;
        return this;
    }

    /** Reserved. Only `1` is honoured - a SOQL subquery cannot nest; `hops > 1` throws at `inject`. */
    public XFTY_InjectConfig childDepth(Integer hops) {
        this.childDepthLimit = hops;
        return this;
    }

    /** Allow the depths and the `injectParent` / `injectChild` path lengths to exceed what one SOQL could return. */
    public XFTY_InjectConfig breakSoqlLimits() {
        this.soqlLimitsLifted = true;
        return this;
    }

    /** A forced scalar on a record several relationship hops up. `path` is the hops then the target field. */
    public class AncestorValue {
        public final List<SObjectField> path;
        public final Object value;

        public AncestorValue(List<SObjectField> path, Object value) {
            this.path = path;
            this.value = value;
        }

        public List<SObjectField> relationshipPrefix() {
            List<SObjectField> prefix = new List<SObjectField>();
            for (Integer i = 0; i < this.path.size() - 1; i++) {
                prefix.add(this.path[i]);
            }
            return prefix;
        }

        public SObjectField targetField() {
            return this.path[this.path.size() - 1];
        }
    }
}
