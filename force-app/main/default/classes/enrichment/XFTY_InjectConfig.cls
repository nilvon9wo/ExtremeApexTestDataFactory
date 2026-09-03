/**
 * What `bundle.inject(field, config)` should materialise. Start from a breadth -
 * `nothing()` (name everything you want), `allParents()`, `allChildren()`,
 * `everything()` - then layer refiners on:
 *
 * - `injectParent(path)` - inject the ancestor at `path` (relationship hops from
 *   the target record) and every hop along the way;
 * - `injectChild(childField)` - inject that one child collection (one hop) on the
 *   target records;
 * - `excludeParent(path)` / `excludeChild(childField)` - prune from a breadth
 *   start;
 * - `injectValue(field, value)` - a scalar on the target record itself
 *   (formula / roll-up / system / read-only);
 * - `injectValue(path, value)` - a scalar on a record several hops up, where
 *   `path` is the relationship hops then the target field;
 * - `parentDepth(n)` - cap the ancestor climb (default 5, the SOQL limit);
 * - `childDepth(n)` - how many levels of nested child collections (default 1;
 *   `n > 1` needs `breakSoqlLimits()` - a nested subquery is not queryable);
 * - `breakSoqlLimits()` - lift the ceiling on `parentDepth`, `childDepth`, and
 *   the `injectParent` path length.
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
    public final List<List<SObjectField>> excludedParentPaths = new List<List<SObjectField>>();
    public final Set<SObjectField> includedChildFields = new Set<SObjectField>();
    public final Set<SObjectField> excludedChildFields = new Set<SObjectField>();
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

    /** Every generated ancestor, to `parentDepth`; children only if named. */
    public static XFTY_InjectConfig allParents() {
        return new XFTY_InjectConfig(true, false);
    }

    /** Every generated child collection, to `childDepth`; parents only if named. */
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

    public XFTY_InjectConfig excludeParent(List<SObjectField> path) {
        this.excludedParentPaths.add(path);
        return this;
    }

    /** Inject the child collection this lookup field defines (e.g. `Case.ContactId` -> the Contact's Cases). */
    public XFTY_InjectConfig injectChild(SObjectField childLookupField) {
        this.includedChildFields.add(childLookupField);
        return this;
    }

    public XFTY_InjectConfig excludeChild(SObjectField childLookupField) {
        this.excludedChildFields.add(childLookupField);
        return this;
    }

    /** A scalar on the target record - the formula / roll-up / system / read-only case. */
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

    /** How many levels of nested child collections. Default 1; `hops > 1` needs `breakSoqlLimits()`. */
    public XFTY_InjectConfig childDepth(Integer hops) {
        this.childDepthLimit = hops;
        return this;
    }

    /** Allow `parentDepth`, `childDepth` and the `injectParent` path length to exceed what one SOQL could return. */
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
