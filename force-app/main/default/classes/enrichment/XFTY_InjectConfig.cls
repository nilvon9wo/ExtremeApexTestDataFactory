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
 * - `injectValue(XFTY_PathValue)` - a scalar on a record several hops up;
 * - `parentDepth(n)` / `childDepth(n)` - cap the climb (default: the SOQL
 *   limit);
 * - `breakSoqlLimits()` - lift the ceiling on the depths and the path lengths.
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
    public final List<XFTY_PathValue> ancestorValues = new List<XFTY_PathValue>();

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

    /** A scalar on a record several relationship hops up - see `XFTY_PathValue`. */
    public XFTY_InjectConfig injectValue(XFTY_PathValue ancestorValue) {
        this.ancestorValues.add(ancestorValue);
        return this;
    }

    public XFTY_InjectConfig parentDepth(Integer limit) {
        this.parentDepthLimit = limit;
        return this;
    }

    public XFTY_InjectConfig childDepth(Integer limit) {
        this.childDepthLimit = limit;
        return this;
    }

    /** Allow the depths and the `injectParent` / `injectChild` path lengths to exceed what one SOQL could return. */
    public XFTY_InjectConfig breakSoqlLimits() {
        this.soqlLimitsLifted = true;
        return this;
    }
}
