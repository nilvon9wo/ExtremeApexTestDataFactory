/**
 * Applies the forced scalar values an `XFTY_InjectConfig` carries -
 * `injectValue(field, v)` on the target record, `injectValue(path, v)` on a
 * record several hops up, `injectChildValue(path, v)` on the records of a child
 * collection - onto the `XFTY_SObjectInjector` for whichever position
 * `XFTY_BundleEnricher` is enriching. No recursion; just value placement.
 *
 * Each `value` may be a literal (every record at the position gets it), a
 * `List<Object>` (one per record, in position order), or an
 * `XFTY_ValueExpressionIntf` (resolved fresh per record - so an incrementing
 * expression gives each child a distinct value).
 *
 * `assertEveryPathWasReached` is the safety net: a path that never matched a
 * visited position - a typo, an ancestor that was not generated, a child
 * collection the walk never descended into - is a loud error, not a silent
 * no-op.
 */
@IsTest
public class XFTY_ForcedValues {

    private final XFTY_InjectConfig config;
    private final Set<Integer> reachedAncestorValues = new Set<Integer>();
    private final Set<Integer> reachedChildValues = new Set<Integer>();

    public XFTY_ForcedValues(XFTY_InjectConfig config) {
        this.config = config;
    }

    /** The `injectValue(field, v)` scalars - the target record itself. */
    public void applyRecordValues(XFTY_SObjectInjector injector, Integer rowCount) {
        placeAll(injector, this.config.onRecordValues, rowCount);
    }

    /** The `injectValue(path, v)` scalars whose relationship prefix is this ancestor position. */
    public void applyAncestorValues(XFTY_SObjectInjector injector, List<SObjectField> pathFromEntry, Integer rowCount) {
        String hereKey = XFTY_PathKey.of(pathFromEntry);
        Map<SObjectField, Object> matched = new Map<SObjectField, Object>();
        for (Integer i = 0; i < this.config.ancestorValues.size(); i++) {
            XFTY_InjectConfig.AncestorValue ancestorValue = this.config.ancestorValues[i];
            if (XFTY_PathKey.of(ancestorValue.relationshipPrefix()) == hereKey) {
                matched.put(ancestorValue.targetField(), ancestorValue.value);
                this.reachedAncestorValues.add(i);
            }
        }
        placeAll(injector, matched, rowCount);
    }

    /** The `injectChildValue(path, v)` scalars whose relationship prefix is this child position. */
    public void applyChildValues(XFTY_SObjectInjector injector, List<SObjectField> childPathFromEntry, Integer rowCount) {
        String hereKey = XFTY_PathKey.of(childPathFromEntry);
        Map<SObjectField, Object> matched = new Map<SObjectField, Object>();
        for (Integer i = 0; i < this.config.childValues.size(); i++) {
            XFTY_InjectConfig.ChildValue childValue = this.config.childValues[i];
            if (XFTY_PathKey.of(childValue.relationshipPrefix()) == hereKey) {
                matched.put(childValue.targetField(), childValue.value);
                this.reachedChildValues.add(i);
            }
        }
        placeAll(injector, matched, rowCount);
    }

    /** Throw if any `injectValue(path)` / `injectChildValue` never matched a visited position. */
    public void assertEveryPathWasReached() {
        List<String> unreached = new List<String>();
        for (Integer i = 0; i < this.config.ancestorValues.size(); i++) {
            if (!this.reachedAncestorValues.contains(i)) {
                unreached.add('injectValue ' + XFTY_PathKey.of(this.config.ancestorValues[i].path));
            }
        }
        for (Integer i = 0; i < this.config.childValues.size(); i++) {
            if (!this.reachedChildValues.contains(i)) {
                unreached.add('injectChildValue ' + XFTY_PathKey.of(this.config.childValues[i].path));
            }
        }
        if (!unreached.isEmpty()) {
            throw new XFTY_DummySObjectFtyProviderException(
                    'inject: ' + unreached + ' named a record the graph never produced or the walk never reached '
                            + '(check the path, that the ancestor / child was generated, and parentDepth / childDepth).'
            );
        }
    }

    private static void placeAll(XFTY_SObjectInjector injector, Map<SObjectField, Object> valueByField, Integer rowCount) {
        for (SObjectField field : valueByField.keySet()) {
            Object value = valueByField.get(field);
            if (value instanceof List<Object>) {
                injector.valuePerRow(field, (List<Object>) value);
            } else if (value instanceof XFTY_ValueExpressionIntf) {
                injector.valuePerRow(field, resolvedPerRow((XFTY_ValueExpressionIntf) value, rowCount));
            } else {
                injector.value(field, value);
            }
        }
    }

    private static List<Object> resolvedPerRow(XFTY_ValueExpressionIntf expression, Integer rowCount) {
        List<Object> values = new List<Object>();
        for (Integer row = 0; row < rowCount; row++) {
            values.add(expression.get());
        }
        return values;
    }
}
