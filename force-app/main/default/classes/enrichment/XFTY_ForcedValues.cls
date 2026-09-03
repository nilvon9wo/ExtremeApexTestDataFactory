/**
 * Applies the forced scalar values an `XFTY_InjectConfig` carries -
 * `injectValue(field, v)` on the target record, `injectValue(path, v)` on a
 * record several hops up - onto the `XFTY_SObjectInjector` for whichever position
 * `XFTY_BundleEnricher` is enriching. No recursion; just value placement.
 */
@IsTest
public class XFTY_ForcedValues {

    private final XFTY_InjectConfig config;

    public XFTY_ForcedValues(XFTY_InjectConfig config) {
        this.config = config;
    }

    /**
     * `pathFromEntry` is the upward-hop path from the entry target to this
     * position (null once the walk turned downward); `isRoot` is true only for
     * the entry target itself.
     */
    public void applyTo(XFTY_SObjectInjector injector, List<SObjectField> pathFromEntry, Boolean isRoot) {
        if (isRoot) {
            this.applyRecordValues(injector);
        }
        if (pathFromEntry != null) {
            this.applyAncestorValues(injector, pathFromEntry);
        }
    }

    private void applyRecordValues(XFTY_SObjectInjector injector) {
        for (SObjectField field : this.config.onRecordValues.keySet()) {
            injector.value(field, resolved(this.config.onRecordValues.get(field)));
        }
    }

    private void applyAncestorValues(XFTY_SObjectInjector injector, List<SObjectField> pathFromEntry) {
        String hereKey = XFTY_PathKey.of(pathFromEntry);
        for (XFTY_InjectConfig.AncestorValue ancestorValue : this.config.ancestorValues) {
            if (XFTY_PathKey.of(ancestorValue.relationshipPrefix()) == hereKey) {
                injector.value(ancestorValue.targetField(), resolved(ancestorValue.value));
            }
        }
    }

    private static Object resolved(Object value) {
        return (value instanceof XFTY_ValueExpressionIntf)
                ? ((XFTY_ValueExpressionIntf) value).get()
                : value;
    }
}
